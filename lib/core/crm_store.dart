import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'local_database.dart';
import 'models.dart';

enum CrmAccent { ocean, emerald, violet, amber, rose }

enum CloseBehavior { ask, minimizeToTray, exit }

class CrmStore extends ChangeNotifier {
  CrmStore({LocalDatabase? database, ApiClient? api})
    : _database = database ?? LocalDatabase(),
      _api = api ?? ApiClient();

  final LocalDatabase _database;
  final ApiClient _api;
  final Uuid _uuid = const Uuid();
  SharedPreferences? _preferences;

  ThemeMode _themeMode = ThemeMode.system;
  CrmAccent _accent = CrmAccent.ocean;
  double _textScale = 1;
  bool _highContrast = false;
  bool _reduceMotion = false;
  bool _boldText = false;
  bool _largeTouchTargets = false;
  bool _sidebarCollapsed = false;
  bool _automaticUpdates = true;
  CloseBehavior _closeBehavior = CloseBehavior.ask;
  List<CrmCustomer> _customers = const [];
  List<CrmCall> _calls = const [];
  List<CrmProduct> _products = const [];
  List<CrmOpportunity> _opportunities = const [];
  List<CrmTask> _tasks = const [];
  List<CrmQuote> _quotes = const [];
  List<CrmOrder> _orders = const [];
  List<String> _activityTypes = const [
    'تولیدکننده',
    'مصرف‌کننده',
    'بازرگان',
    'واسطه',
    'ضایعات',
    'بازیافت',
    'خریدار',
    'فروشنده',
    'آخال',
    'صادرکننده',
    'واردکننده',
    'سایر',
  ];
  List<String> _customerStatuses = const ['فعال', 'مشتری بالقوه', 'غیرفعال'];
  List<String> _productCategories = const [
    'صنایع شیمیایی',
    'ضایعات',
    'مواد غذایی',
    'خدمات',
    'سایر',
  ];
  bool _busy = false;
  bool _syncing = false;
  bool _online = false;
  String _syncMessage = 'آماده برای همگام‌سازی';
  String? _accessToken;
  String? _organizationId;
  String _userName = 'کاربر آفلاین';
  String _organizationName = 'فضای کاری من';
  int _pendingOutboxCount = 0;
  Timer? _sessionGuard;
  bool _checkingSession = false;
  String? _sessionNotice;

  ThemeMode get themeMode => _themeMode;
  CrmAccent get accent => _accent;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  bool get boldText => _boldText;
  bool get largeTouchTargets => _largeTouchTargets;
  bool get sidebarCollapsed => _sidebarCollapsed;
  bool get automaticUpdates => _automaticUpdates;
  CloseBehavior get closeBehavior => _closeBehavior;
  List<CrmCustomer> get customers => List.unmodifiable(_customers);
  List<CrmCall> get calls => List.unmodifiable(_calls);
  List<CrmProduct> get products => List.unmodifiable(_products);
  List<CrmOpportunity> get opportunities => List.unmodifiable(_opportunities);
  List<CrmTask> get tasks => List.unmodifiable(_tasks);
  List<CrmQuote> get quotes => List.unmodifiable(_quotes);
  List<CrmOrder> get orders => List.unmodifiable(_orders);
  List<String> get activityTypes => List.unmodifiable(_activityTypes);
  List<String> get customerStatuses => List.unmodifiable(_customerStatuses);
  List<String> get productCategories => List.unmodifiable(_productCategories);
  bool get busy => _busy;
  bool get syncing => _syncing;
  bool get online => _online;
  bool get hasSession => _accessToken != null && _accessToken!.isNotEmpty;
  String get syncMessage => _syncMessage;
  String get userName => _userName;
  String get organizationName => _organizationName;
  String? get organizationId => _organizationId;
  String get apiBaseUrl => _api.baseUrl;
  int get pendingOutboxCount => _pendingOutboxCount;

  int get activeCustomers =>
      _customers.where((customer) => customer.status == 'فعال').length;
  int get potentialCustomers =>
      _customers.where((customer) => customer.status == 'مشتری بالقوه').length;
  int get successfulCalls =>
      _calls.where((call) => call.status == 'موفق').length;
  int get followUpCalls =>
      _calls.where((call) => call.status == 'پیگیری').length;
  int get unsuccessfulCalls =>
      _calls.where((call) => call.status == 'ناموفق').length;
  int get totalRevenue => _calls
      .where((call) => call.tradeType != 'خرید')
      .fold(0, (sum, call) => sum + call.amount);
  int get totalPurchase => _calls
      .where((call) => call.tradeType == 'خرید')
      .fold(0, (sum, call) => sum + call.amount);
  int get openOpportunities => _opportunities
      .where(
        (opportunity) =>
            opportunity.stage != 'برنده شده' &&
            opportunity.stage != 'از دست رفته',
      )
      .length;
  int get weightedPipeline => _opportunities.fold(
    0,
    (sum, opportunity) => sum + opportunity.weightedAmount,
  );
  int get overdueTasks => _tasks.where((task) => task.isOverdue).length;
  int get openTasks => _tasks.where((task) => !task.isDone).length;
  int get pendingQuotes => _quotes
      .where(
        (quote) => !{
          'تایید شده',
          'تأیید شده',
          'رد شده',
          'فاکتور صادر شد',
        }.contains(quote.status),
      )
      .length;
  int get salesOrders =>
      _orders.where((order) => order.direction == 'فروش').length;
  int get purchaseOrders =>
      _orders.where((order) => order.direction == 'خرید').length;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final savedTheme = _preferences!.getString('theme_mode') ?? 'system';
    _themeMode = switch (savedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final savedAccent =
        _preferences!.getString('accent') ?? CrmAccent.ocean.name;
    final matchingAccents = CrmAccent.values
        .where((item) => item.name == savedAccent)
        .toList();
    _accent = matchingAccents.isEmpty ? CrmAccent.ocean : matchingAccents.first;
    _textScale = _preferences!.getDouble('text_scale') ?? 1;
    _highContrast = _preferences!.getBool('high_contrast') ?? false;
    _reduceMotion = _preferences!.getBool('reduce_motion') ?? false;
    _boldText = _preferences!.getBool('bold_text') ?? false;
    _largeTouchTargets = _preferences!.getBool('large_touch_targets') ?? false;
    _sidebarCollapsed = _preferences!.getBool('sidebar_collapsed') ?? false;
    _automaticUpdates = _preferences!.getBool('automatic_updates') ?? true;
    final savedCloseBehavior = _preferences!.getString('close_behavior');
    _closeBehavior = CloseBehavior.values.firstWhere(
      (item) => item.name == savedCloseBehavior,
      orElse: () => CloseBehavior.ask,
    );
    _accessToken = _preferences!.getString('access_token');
    _api.accessToken = _accessToken;
    _organizationId = _preferences!.getString('organization_id');
    _userName = _preferences!.getString('user_name') ?? _userName;
    _organizationName =
        _preferences!.getString('organization_name') ?? _organizationName;
    _activityTypes = _mergeOptions(
      _activityTypes,
      _preferences!.getStringList('activity_types') ?? const [],
    );
    _customerStatuses = _mergeOptions(
      _customerStatuses,
      _preferences!.getStringList('customer_statuses') ?? const [],
    );
    _productCategories = _mergeOptions(
      _productCategories,
      _preferences!.getStringList('product_categories') ?? const [],
    );
    await _database.initialize();
    await _database.removeLegacyDemoData();
    if (hasSession && _organizationId == null) {
      // Older alpha builds did not persist the organization id. Do not expose
      // their local cache until this session has reloaded its own workspace.
      await _database.clearWorkspace();
    }
    if (hasSession) {
      await refresh();
    } else {
      _clearInMemory();
    }
    _online = await _api.health();
    if (_online && hasSession) {
      await _validateSession();
      if (hasSession) await sync(silent: true);
    }
    if (hasSession) _startSessionGuard();
    notifyListeners();
  }

  Future<void> refresh() async {
    _customers = await _database.customers();
    _calls = await _database.calls();
    _products = await _database.products();
    _opportunities = await _database.opportunities();
    _tasks = await _database.tasks();
    _quotes = await _database.quotes();
    _orders = await _database.orders();
    _pendingOutboxCount = (await _database.pendingChanges()).length;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _preferences?.setString('theme_mode', mode.name);
    notifyListeners();
  }

  Future<void> setAccent(CrmAccent accent) async {
    _accent = accent;
    await _preferences?.setString('accent', accent.name);
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    _textScale = value.clamp(0.85, 1.45);
    await _preferences?.setDouble('text_scale', _textScale);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    await _preferences?.setBool('high_contrast', value);
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    _reduceMotion = value;
    await _preferences?.setBool('reduce_motion', value);
    notifyListeners();
  }

  Future<void> setBoldText(bool value) async {
    _boldText = value;
    await _preferences?.setBool('bold_text', value);
    notifyListeners();
  }

  Future<void> setLargeTouchTargets(bool value) async {
    _largeTouchTargets = value;
    await _preferences?.setBool('large_touch_targets', value);
    notifyListeners();
  }

  Future<void> setSidebarCollapsed(bool value) async {
    _sidebarCollapsed = value;
    await _preferences?.setBool('sidebar_collapsed', value);
    notifyListeners();
  }

  Future<void> setAutomaticUpdates(bool value) async {
    _automaticUpdates = value;
    await _preferences?.setBool('automatic_updates', value);
    notifyListeners();
  }

  Future<void> setCloseBehavior(CloseBehavior value) async {
    _closeBehavior = value;
    await _preferences?.setString('close_behavior', value.name);
    notifyListeners();
  }

  List<String> _mergeOptions(List<String> defaults, List<String> saved) {
    return {
      ...defaults,
      ...saved.map((item) => item.trim()),
    }.where((item) => item.isNotEmpty).toList();
  }

  Future<void> addActivityType(String value) async {
    final item = value.trim();
    if (item.isEmpty || _activityTypes.contains(item)) return;
    _activityTypes = [..._activityTypes, item];
    await _preferences?.setStringList('activity_types', _activityTypes);
    notifyListeners();
  }

  Future<void> addCustomerStatus(String value) async {
    final item = value.trim();
    if (item.isEmpty || _customerStatuses.contains(item)) return;
    _customerStatuses = [..._customerStatuses, item];
    await _preferences?.setStringList('customer_statuses', _customerStatuses);
    notifyListeners();
  }

  Future<void> addProductCategory(String value) async {
    final item = value.trim();
    if (item.isEmpty || _productCategories.contains(item)) return;
    _productCategories = [..._productCategories, item];
    await _preferences?.setStringList('product_categories', _productCategories);
    notifyListeners();
  }

  Future<String?> login(String identifier, String password) async {
    _busy = true;
    notifyListeners();
    try {
      final session = await _api.login(identifier.trim(), password);
      final changingWorkspace = _organizationId != session.organizationId;
      if (changingWorkspace) {
        await _database.clearWorkspace();
        _clearInMemory();
      }
      _accessToken = session.accessToken;
      _api.accessToken = session.accessToken;
      _userName = session.userName;
      _organizationId = session.organizationId;
      _organizationName = session.organizationName;
      await _preferences?.setString('access_token', session.accessToken);
      await _preferences?.setString('user_name', session.userName);
      await _preferences?.setString('organization_id', session.organizationId);
      await _preferences?.setString(
        'organization_name',
        session.organizationName,
      );
      await sync(silent: true);
      if (!hasSession) {
        return 'دسترسی این حساب در سرور غیرفعال شده است.';
      }
      _startSessionGuard();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'اتصال برقرار نشد. آدرس سرور و اینترنت را بررسی کنید.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _endSession(clearWorkspace: true);
  }

  Future<void> sync({bool silent = false}) async {
    if (!hasSession) {
      if (!silent) {
        _syncMessage = 'برای همگام‌سازی ابتدا وارد حساب شوید.';
        notifyListeners();
      }
      return;
    }
    _syncing = true;
    if (!silent) notifyListeners();
    try {
      final changes = await _database.pendingChanges();
      final response = await _api.synchronize(
        cursor: await _database.cursor(),
        changes: changes,
      );
      for (final change in response.remoteChanges) {
        await _database.applyRemoteChange(change);
      }
      await _database.markOutboxAccepted(response.acceptedOutboxIds);
      await _database.setCursor(response.cursor);
      _online = true;
      _syncMessage = 'همگام‌سازی با موفقیت انجام شد.';
      await refresh();
    } on ApiException catch (error) {
      _online = false;
      _syncMessage = error.message;
      if (error.isUnauthorized) {
        await _endSession(
          clearWorkspace: true,
          notice:
              'دسترسی این حساب تغییر کرده یا غیرفعال شده است؛ دوباره وارد شوید.',
        );
      }
    } catch (_) {
      _online = false;
      _syncMessage = 'سرور در دسترس نیست؛ تغییرات در صف محلی نگهداری شد.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> saveCustomer({
    required String name,
    required String company,
    required String mobile,
    required String phone,
    required String province,
    required String city,
    required String activityType,
    required String status,
    required String priority,
    required String notes,
    List<String> tags = const [],
    Map<String, String> details = const {},
    String? id,
  }) async {
    final customer = CrmCustomer(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      company: company.trim(),
      mobile: mobile.trim(),
      phone: phone.trim(),
      province: province.trim(),
      city: city.trim(),
      activityType: activityType,
      status: status,
      priority: priority,
      notes: notes.trim(),
      tags: tags,
      details: details,
      updatedAt: DateTime.now(),
    );
    await _database.saveCustomer(customer);
    await _afterLocalMutation();
  }

  String nextCustomerCode() {
    var maximum = 0;
    for (final customer in _customers) {
      final digits = customer.customerCode.replaceAll(RegExp(r'[^0-9]'), '');
      final value = int.tryParse(digits) ?? 0;
      if (value > maximum) maximum = value;
    }
    return 'M-${(maximum + 1).toString().padLeft(6, '0')}';
  }

  Future<int> importCustomerRows(List<Map<String, String>> rows) async {
    var imported = 0;
    var nextSequence = _customers.fold<int>(0, (maximum, customer) {
      final digits = customer.customerCode.replaceAll(RegExp(r'[^0-9]'), '');
      final value = int.tryParse(digits) ?? 0;
      return value > maximum ? value : maximum;
    });
    for (final row in rows) {
      final name = (row['name'] ?? '').trim();
      final company = (row['company'] ?? '').trim();
      final mobile = (row['mobile'] ?? '').trim();
      if (name.isEmpty && company.isEmpty && mobile.isEmpty) continue;
      final current = _customers.cast<CrmCustomer?>().firstWhere(
        (item) =>
            item != null &&
            ((mobile.isNotEmpty && item.mobile == mobile) ||
                ((row['customer_code'] ?? '').isNotEmpty &&
                    item.customerCode == row['customer_code'])),
        orElse: () => null,
      );
      final details = <String, String>{
        ...?current?.details,
        'customer_code': (row['customer_code'] ?? '').trim().isEmpty
            ? 'M-${(++nextSequence).toString().padLeft(6, '0')}'
            : (row['customer_code'] ?? '').trim(),
        'is_vip':
            (row['is_vip'] ?? '').trim() == 'بله' ||
                (row['is_vip'] ?? '').trim().toLowerCase() == 'true'
            ? 'true'
            : 'false',
        'email': (row['email'] ?? '').trim(),
        'address': (row['address'] ?? '').trim(),
      };
      await _database.saveCustomer(
        CrmCustomer(
          id: current?.id ?? _uuid.v4(),
          name: name.isEmpty ? company : name,
          company: company,
          mobile: mobile,
          phone: (row['phone'] ?? '').trim(),
          province: (row['province'] ?? '').trim(),
          city: (row['city'] ?? '').trim(),
          activityType: (row['activity_type'] ?? '').trim().isEmpty
              ? 'سایر'
              : (row['activity_type'] ?? '').trim(),
          status: (row['status'] ?? '').trim().isEmpty
              ? 'فعال'
              : (row['status'] ?? '').trim(),
          priority: (row['priority'] ?? '').trim().isEmpty
              ? 'متوسط'
              : (row['priority'] ?? '').trim(),
          notes: (row['notes'] ?? '').trim(),
          tags: (row['tags'] ?? '')
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
          details: details,
          updatedAt: DateTime.now(),
        ),
      );
      imported++;
    }
    if (imported > 0) await _afterLocalMutation();
    return imported;
  }

  Future<void> saveCall({
    required CrmCustomer customer,
    required String subject,
    required String type,
    required String direction,
    required String status,
    required String notes,
    required int durationMinutes,
    required int amount,
    DateTime? nextFollowUp,
    String tradeType = '',
    String productName = '',
    int quantity = 0,
    int unitPrice = 0,
    String? id,
    DateTime? callAt,
  }) async {
    final now = DateTime.now();
    final call = CrmCall(
      id: id ?? _uuid.v4(),
      customerId: customer.id,
      customerName: customer.company.isEmpty ? customer.name : customer.company,
      subject: subject.trim(),
      type: type,
      direction: direction,
      status: status,
      notes: notes.trim(),
      callAt: callAt ?? now,
      durationMinutes: durationMinutes,
      amount: amount,
      tradeType: tradeType,
      productName: productName.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      nextFollowUp: nextFollowUp,
      updatedAt: now,
    );
    await _database.saveCall(call);
    await _afterLocalMutation();
  }

  Future<void> saveProduct({
    required String name,
    required String sku,
    required String category,
    required String unit,
    required int unitPrice,
    required int stock,
    required int minStock,
    required String description,
    bool isActive = true,
    String? id,
  }) async {
    final product = CrmProduct(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      sku: sku.trim(),
      category: category.trim(),
      unit: unit.trim(),
      unitPrice: unitPrice,
      stock: stock,
      minStock: minStock,
      description: description.trim(),
      isActive: isActive,
      updatedAt: DateTime.now(),
    );
    await _database.saveProduct(product);
    await _afterLocalMutation();
  }

  Future<void> saveOpportunity({
    required CrmCustomer customer,
    required String title,
    required String stage,
    required int amount,
    required int probability,
    required String notes,
    String tradeType = 'فروش',
    DateTime? expectedClose,
    String? id,
  }) async {
    final opportunity = CrmOpportunity(
      id: id ?? _uuid.v4(),
      customerId: customer.id,
      customerName: customer.company.isEmpty ? customer.name : customer.company,
      title: title.trim(),
      stage: stage,
      amount: amount,
      probability: probability,
      notes: notes.trim(),
      ownerName: _userName,
      tradeType: tradeType,
      expectedClose: expectedClose,
      updatedAt: DateTime.now(),
    );
    await _database.saveOpportunity(opportunity);
    await _afterLocalMutation();
  }

  Future<void> saveTask({
    required CrmCustomer customer,
    required String title,
    required String taskType,
    required String priority,
    required String status,
    required String notes,
    DateTime? dueAt,
    String? id,
  }) async {
    final task = CrmTask(
      id: id ?? _uuid.v4(),
      customerId: customer.id,
      customerName: customer.company.isEmpty ? customer.name : customer.company,
      title: title.trim(),
      taskType: taskType,
      priority: priority,
      status: status,
      notes: notes.trim(),
      dueAt: dueAt,
      ownerName: _userName,
      updatedAt: DateTime.now(),
    );
    await _database.saveTask(task);
    await _afterLocalMutation();
  }

  Future<void> toggleTask(CrmTask task) async {
    final completed = CrmTask(
      id: task.id,
      customerId: task.customerId,
      customerName: task.customerName,
      title: task.title,
      taskType: task.taskType,
      priority: task.priority,
      status: task.isDone ? 'باز' : 'انجام شد',
      notes: task.notes,
      dueAt: task.dueAt,
      ownerName: task.ownerName,
      updatedAt: DateTime.now(),
    );
    await _database.saveTask(completed);
    await _afterLocalMutation();
  }

  Future<void> saveQuote({
    required CrmCustomer customer,
    required String status,
    required int totalAmount,
    required String notes,
    String direction = 'فروش',
    List<CrmDocumentLine> lineItems = const [],
    DateTime? validUntil,
    String? id,
    String? quoteNumber,
  }) async {
    final now = DateTime.now();
    final quote = CrmQuote(
      id: id ?? _uuid.v4(),
      customerId: customer.id,
      customerName: customer.company.isEmpty ? customer.name : customer.company,
      quoteNumber: quoteNumber ?? 'PF-' + now.millisecondsSinceEpoch.toString(),
      status: status,
      totalAmount: totalAmount,
      notes: notes.trim(),
      validUntil: validUntil,
      direction: direction,
      lineItems: lineItems,
      updatedAt: now,
    );
    await _database.saveQuote(quote);
    await _afterLocalMutation();
  }

  Future<void> saveOrder({
    required CrmCustomer customer,
    required String direction,
    required String status,
    required int totalAmount,
    required String notes,
    List<CrmDocumentLine> lineItems = const [],
    String sourceType = '',
    String sourceId = '',
    String? id,
    String? orderNumber,
    DateTime? orderAt,
  }) async {
    final now = DateTime.now();
    final order = CrmOrder(
      id: id ?? _uuid.v4(),
      customerId: customer.id,
      customerName: customer.company.isEmpty ? customer.name : customer.company,
      orderNumber: orderNumber ?? 'SO-' + now.millisecondsSinceEpoch.toString(),
      direction: direction,
      status: status,
      totalAmount: totalAmount,
      notes: notes.trim(),
      orderAt: orderAt ?? now,
      lineItems: lineItems,
      sourceType: sourceType,
      sourceId: sourceId,
      updatedAt: now,
    );
    await _database.saveOrder(order);
    await _afterLocalMutation();
  }

  Future<void> deleteCustomer(CrmCustomer item) async {
    await _database.saveCustomer(
      item.copyWith(deleted: true, updatedAt: DateTime.now()),
    );
    await _afterLocalMutation();
  }

  Future<void> deleteCall(CrmCall item) async {
    await _database.saveCall(
      CrmCall(
        id: item.id,
        customerId: item.customerId,
        customerName: item.customerName,
        subject: item.subject,
        type: item.type,
        direction: item.direction,
        status: item.status,
        notes: item.notes,
        callAt: item.callAt,
        durationMinutes: item.durationMinutes,
        amount: item.amount,
        nextFollowUp: item.nextFollowUp,
        tradeType: item.tradeType,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        updatedAt: DateTime.now(),
        deleted: true,
      ),
    );
    await _afterLocalMutation();
  }

  Future<void> deleteProduct(CrmProduct item) async {
    await _database.saveProduct(
      CrmProduct(
        id: item.id,
        name: item.name,
        sku: item.sku,
        category: item.category,
        unit: item.unit,
        unitPrice: item.unitPrice,
        stock: item.stock,
        minStock: item.minStock,
        description: item.description,
        isActive: item.isActive,
        updatedAt: DateTime.now(),
        deleted: true,
      ),
    );
    await _afterLocalMutation();
  }

  Future<void> deleteOpportunity(CrmOpportunity item) async {
    await _database.saveOpportunity(
      CrmOpportunity(
        id: item.id,
        customerId: item.customerId,
        customerName: item.customerName,
        title: item.title,
        stage: item.stage,
        amount: item.amount,
        probability: item.probability,
        notes: item.notes,
        ownerName: item.ownerName,
        tradeType: item.tradeType,
        expectedClose: item.expectedClose,
        updatedAt: DateTime.now(),
        deleted: true,
      ),
    );
    await _afterLocalMutation();
  }

  Future<void> deleteTask(CrmTask item) async {
    await _database.saveTask(
      CrmTask(
        id: item.id,
        customerId: item.customerId,
        customerName: item.customerName,
        title: item.title,
        taskType: item.taskType,
        priority: item.priority,
        status: item.status,
        notes: item.notes,
        dueAt: item.dueAt,
        ownerName: item.ownerName,
        updatedAt: DateTime.now(),
        deleted: true,
      ),
    );
    await _afterLocalMutation();
  }

  Future<void> deleteQuote(CrmQuote item) async {
    await _database.saveQuote(
      CrmQuote(
        id: item.id,
        customerId: item.customerId,
        customerName: item.customerName,
        quoteNumber: item.quoteNumber,
        status: item.status,
        totalAmount: item.totalAmount,
        notes: item.notes,
        validUntil: item.validUntil,
        direction: item.direction,
        lineItems: item.lineItems,
        updatedAt: DateTime.now(),
        deleted: true,
      ),
    );
    await _afterLocalMutation();
  }

  Future<void> deleteOrder(CrmOrder item) async {
    await _database.saveOrder(
      CrmOrder(
        id: item.id,
        customerId: item.customerId,
        customerName: item.customerName,
        orderNumber: item.orderNumber,
        direction: item.direction,
        status: item.status,
        totalAmount: item.totalAmount,
        notes: item.notes,
        orderAt: item.orderAt,
        lineItems: item.lineItems,
        sourceType: item.sourceType,
        sourceId: item.sourceId,
        updatedAt: DateTime.now(),
        deleted: true,
      ),
    );
    await _afterLocalMutation();
  }

  Future<void> _afterLocalMutation() async {
    await refresh();
    if (_online && hasSession) {
      await sync(silent: true);
    }
  }

  void _startSessionGuard() {
    _sessionGuard?.cancel();
    _sessionGuard = Timer.periodic(
      const Duration(seconds: 40),
      (_) => unawaited(_validateSession()),
    );
  }

  Future<void> _validateSession() async {
    if (!hasSession || _checkingSession) return;
    _checkingSession = true;
    try {
      final session = await _api.currentSession();
      if (_organizationId != null &&
          _organizationId != session.organizationId) {
        await _endSession(
          clearWorkspace: true,
          notice: 'فضای کاری این حساب تغییر کرده است؛ دوباره وارد شوید.',
        );
        return;
      }
      _organizationId = session.organizationId;
      _userName = session.userName;
      _organizationName = session.organizationName;
      await _preferences?.setString('organization_id', session.organizationId);
      await _preferences?.setString('user_name', session.userName);
      await _preferences?.setString(
        'organization_name',
        session.organizationName,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _endSession(
          clearWorkspace: true,
          notice:
              'دسترسی این حساب تغییر کرده یا غیرفعال شده است؛ دوباره وارد شوید.',
        );
      }
    } finally {
      _checkingSession = false;
    }
  }

  Future<void> _endSession({
    required bool clearWorkspace,
    String? notice,
  }) async {
    _sessionGuard?.cancel();
    _sessionGuard = null;
    _accessToken = null;
    _api.accessToken = null;
    _organizationId = null;
    _userName = 'کاربر آفلاین';
    _organizationName = 'فضای کاری من';
    _online = false;
    _syncing = false;
    _syncMessage = 'برای همگام‌سازی ابتدا وارد حساب شوید.';
    if (notice != null) _sessionNotice = notice;
    await _preferences?.remove('access_token');
    await _preferences?.remove('user_name');
    await _preferences?.remove('organization_id');
    await _preferences?.remove('organization_name');
    if (clearWorkspace) await _database.clearWorkspace();
    _clearInMemory();
    notifyListeners();
  }

  void _clearInMemory() {
    _customers = const [];
    _calls = const [];
    _products = const [];
    _opportunities = const [];
    _tasks = const [];
    _quotes = const [];
    _orders = const [];
    _pendingOutboxCount = 0;
  }

  String? takeSessionNotice() {
    final notice = _sessionNotice;
    _sessionNotice = null;
    return notice;
  }

  @override
  void dispose() {
    _sessionGuard?.cancel();
    super.dispose();
  }
}
