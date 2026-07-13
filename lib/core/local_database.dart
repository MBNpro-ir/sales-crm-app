import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models.dart';

class LocalDatabase {
  static const _recordTypes = {
    'product',
    'opportunity',
    'task',
    'quote',
    'order',
  };

  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final location = join(await getDatabasesPath(), 'sales_crm.sqlite');
    _database = await openDatabase(
      location,
      version: 4,
      onCreate: (database, version) async {
        await _createCoreTables(database);
        await _createRecordTable(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createRecordTable(database);
        }
        if (oldVersion < 3) {
          await database.execute(
            'ALTER TABLE customers ADD COLUMN details_json TEXT',
          );
        }
        if (oldVersion < 4) {
          await database.execute(
            "ALTER TABLE calls ADD COLUMN trade_type TEXT NOT NULL DEFAULT ''",
          );
          await database.execute(
            "ALTER TABLE calls ADD COLUMN product_name TEXT NOT NULL DEFAULT ''",
          );
          await database.execute(
            'ALTER TABLE calls ADD COLUMN quantity INTEGER NOT NULL DEFAULT 0',
          );
          await database.execute(
            'ALTER TABLE calls ADD COLUMN unit_price INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  Future<void> _createCoreTables(Database database) async {
    await database.execute('''
      CREATE TABLE customers(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        company TEXT,
        mobile TEXT,
        phone TEXT,
        province TEXT,
        city TEXT,
        activity_type TEXT,
        status TEXT,
        priority TEXT,
        notes TEXT,
        tags_json TEXT,
        details_json TEXT,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE calls(
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        customer_name TEXT,
        subject TEXT,
        type TEXT,
        direction TEXT,
        status TEXT,
        notes TEXT,
        call_at TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 0,
        amount INTEGER NOT NULL DEFAULT 0,
        trade_type TEXT NOT NULL DEFAULT '',
        product_name TEXT NOT NULL DEFAULT '',
        quantity INTEGER NOT NULL DEFAULT 0,
        unit_price INTEGER NOT NULL DEFAULT 0,
        next_follow_up TEXT,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE outbox(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE metadata(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createRecordTable(Database database) {
    return database.execute('''
      CREATE TABLE IF NOT EXISTS crm_records(
        entity_type TEXT NOT NULL,
        id TEXT NOT NULL,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(entity_type, id)
      )
    ''');
  }

  Future<Database> get _db async {
    await initialize();
    return _database!;
  }

  /// Removes records created by the pre-alpha sample-data seed exactly once.
  /// Real user records are never touched because the cleanup only targets the
  /// explicit historical demo and integration-test identifiers.
  Future<void> removeLegacyDemoData() async {
    final database = await _db;
    const marker = 'alpha_demo_cleanup_v1';
    final applied = await database.query(
      'metadata',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [marker],
      limit: 1,
    );
    if (applied.isNotEmpty) return;
    await database.transaction((transaction) async {
      const clause = "id LIKE 'demo-%' OR id LIKE 'integration-%'";
      await transaction.delete('customers', where: clause);
      await transaction.delete('calls', where: clause);
      await transaction.delete('crm_records', where: clause);
      await transaction.delete(
        'outbox',
        where: "entity_id LIKE 'demo-%' OR entity_id LIKE 'integration-%'",
      );
      await transaction.insert('metadata', {
        'key': marker,
        'value': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Removes the local workspace when the signed-in company changes or a user
  /// signs out. Keeping one SQLite file is fine only when its contents never
  /// cross an organization boundary.
  Future<void> clearWorkspace() async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.delete('customers');
      await transaction.delete('calls');
      await transaction.delete('crm_records');
      await transaction.delete('outbox');
      await transaction.delete('metadata');
    });
  }

  Future<List<CrmCustomer>> customers() async {
    final database = await _db;
    final rows = await database.query(
      'customers',
      where: 'is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(CrmCustomer.fromDatabase).toList();
  }

  Future<List<CrmCall>> calls() async {
    final database = await _db;
    final rows = await database.query(
      'calls',
      where: 'is_deleted = 0',
      orderBy: 'call_at DESC',
    );
    return rows.map(CrmCall.fromDatabase).toList();
  }

  Future<List<CrmProduct>> products() {
    return _records('product', CrmProduct.fromJson);
  }

  Future<List<CrmOpportunity>> opportunities() {
    return _records('opportunity', CrmOpportunity.fromJson);
  }

  Future<List<CrmTask>> tasks() {
    return _records('task', CrmTask.fromJson);
  }

  Future<List<CrmQuote>> quotes() {
    return _records('quote', CrmQuote.fromJson);
  }

  Future<List<CrmOrder>> orders() {
    return _records('order', CrmOrder.fromJson);
  }

  Future<List<T>> _records<T>(
    String entityType,
    T Function(Map<String, dynamic>) decoder,
  ) async {
    final database = await _db;
    final rows = await database.query(
      'crm_records',
      where: 'entity_type = ? AND is_deleted = 0',
      whereArgs: [entityType],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) {
      return decoder(
        Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map),
      );
    }).toList();
  }

  Future<void> saveCustomer(CrmCustomer customer) {
    return _saveCustomer(customer, queue: true);
  }

  Future<void> _saveCustomer(
    CrmCustomer customer, {
    required bool queue,
  }) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.insert(
        'customers',
        customer.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (queue) {
        await _queue(
          transaction,
          entityType: 'customer',
          entityId: customer.id,
          operation: customer.deleted ? 'delete' : 'upsert',
          payload: customer.toJson(),
          updatedAt: customer.updatedAt,
        );
      }
    });
  }

  Future<void> saveCall(CrmCall call) {
    return _saveCall(call, queue: true);
  }

  Future<void> _saveCall(CrmCall call, {required bool queue}) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.insert(
        'calls',
        call.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (queue) {
        await _queue(
          transaction,
          entityType: 'call',
          entityId: call.id,
          operation: call.deleted ? 'delete' : 'upsert',
          payload: call.toJson(),
          updatedAt: call.updatedAt,
        );
      }
    });
  }

  Future<void> saveProduct(CrmProduct product) {
    return _saveRecord(
      entityType: 'product',
      id: product.id,
      payload: product.toJson(),
      updatedAt: product.updatedAt,
      deleted: product.deleted,
      queue: true,
    );
  }

  Future<void> saveOpportunity(CrmOpportunity opportunity) {
    return _saveRecord(
      entityType: 'opportunity',
      id: opportunity.id,
      payload: opportunity.toJson(),
      updatedAt: opportunity.updatedAt,
      deleted: opportunity.deleted,
      queue: true,
    );
  }

  Future<void> saveTask(CrmTask task) {
    return _saveRecord(
      entityType: 'task',
      id: task.id,
      payload: task.toJson(),
      updatedAt: task.updatedAt,
      deleted: task.deleted,
      queue: true,
    );
  }

  Future<void> saveQuote(CrmQuote quote) {
    return _saveRecord(
      entityType: 'quote',
      id: quote.id,
      payload: quote.toJson(),
      updatedAt: quote.updatedAt,
      deleted: quote.deleted,
      queue: true,
    );
  }

  Future<void> saveOrder(CrmOrder order) {
    return _saveRecord(
      entityType: 'order',
      id: order.id,
      payload: order.toJson(),
      updatedAt: order.updatedAt,
      deleted: order.deleted,
      queue: true,
    );
  }

  Future<void> _saveRecord({
    required String entityType,
    required String id,
    required Map<String, dynamic> payload,
    required DateTime updatedAt,
    required bool deleted,
    required bool queue,
  }) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.insert('crm_records', {
        'entity_type': entityType,
        'id': id,
        'payload': jsonEncode(payload),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': deleted ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (queue) {
        await _queue(
          transaction,
          entityType: entityType,
          entityId: id,
          operation: deleted ? 'delete' : 'upsert',
          payload: payload,
          updatedAt: updatedAt,
        );
      }
    });
  }

  Future<void> _queue(
    Transaction transaction, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    required DateTime updatedAt,
  }) {
    return transaction.insert('outbox', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });
  }

  Future<List<SyncChange>> pendingChanges() async {
    final database = await _db;
    final rows = await database.query('outbox', orderBy: 'id ASC');
    return rows.map((row) {
      return SyncChange(
        queueId: row['id'] as int,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] as String,
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String) as Map,
        ),
        updatedAt: _parseDate(row['updated_at']),
      );
    }).toList();
  }

  Future<int> cursor() async {
    final database = await _db;
    final rows = await database.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: const ['sync_cursor'],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value'] as String) ?? 0;
  }

  Future<void> setCursor(int cursor) async {
    final database = await _db;
    await database.insert('metadata', {
      'key': 'sync_cursor',
      'value': cursor.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markOutboxAccepted(List<int> ids) async {
    if (ids.isEmpty) return;
    final database = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await database.delete(
      'outbox',
      where: 'id IN (' + placeholders + ')',
      whereArgs: ids,
    );
  }

  Future<void> applyRemoteChange(SyncChange change) async {
    if (change.entityType == 'customer') {
      await _saveCustomer(CrmCustomer.fromJson(change.payload), queue: false);
      return;
    }
    if (change.entityType == 'call') {
      await _saveCall(CrmCall.fromJson(change.payload), queue: false);
      return;
    }
    if (_recordTypes.contains(change.entityType)) {
      final payload = Map<String, dynamic>.from(change.payload);
      if (change.operation == 'delete') {
        payload['deleted'] = true;
      }
      await _saveRecord(
        entityType: change.entityType,
        id: change.entityId,
        payload: payload,
        updatedAt: change.updatedAt,
        deleted: payload['deleted'] == true,
        queue: false,
      );
    }
  }

  DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
