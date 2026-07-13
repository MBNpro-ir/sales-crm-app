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
  bool _busy = false;
  bool _syncing = false;
  bool _online = false;
  String _syncMessage = 'آماده برای همگام‌سازی';
  String? _accessToken;
  String _userName = 'کاربر آفلاین';
  String _organizationName = 'فضای کاری من';
  int _pendingOutboxCount = 0;

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
  bool get busy => _busy;
  bool get syncing => _syncing;
  bool get online => _online;
  bool get hasSession => _accessToken != null && _accessToken!.isNotEmpty;
  String get syncMessage => _syncMessage;
  String get userName => _userName;
  String get organizationName => _organizationName;
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
  int get pendingQuotes =>
      _quotes.where((quote) => quote.status != 'تایید شده').length;
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
    _userName = _preferences!.getString('user_name') ?? _userName;
    _organizationName =
        _preferences!.getString('organization_name') ?? _organizationName;
    await _database.initialize();
    await _database.removeLegacyDemoData();
    await refresh();
    _online = await _api.health();
    if (_online && hasSession) {
      await sync(silent: true);
    }
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

  Future<String?> login(String identifier, String password) async {
    _busy = true;
    notifyListeners();
    try {
      final session = await _api.login(identifier.trim(), password);
      _accessToken = session.accessToken;
      _api.accessToken = session.accessToken;
      _userName = session.userName;
      _organizationName = session.organizationName;
      await _preferences?.setString('access_token', session.accessToken);
      await _preferences?.setString('user_name', session.userName);
      await _preferences?.setString(
        'organization_name',
        session.organizationName,
      );
      await sync(silent: true);
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
    _accessToken = null;
    _api.accessToken = null;
    await _preferences?.remove('access_token');
    notifyListeners();
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

  Future<void> completeTask(CrmTask task) async {
    final completed = CrmTask(
      id: task.id,
      customerId: task.customerId,
      customerName: task.customerName,
      title: task.title,
      taskType: task.taskType,
      priority: task.priority,
      status: 'انجام شد',
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
}
