import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';
import '../widgets/entity_tools.dart';

enum DocumentPageMode { quote, order }

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.store, required this.mode});

  final CrmStore store;
  final DocumentPageMode mode;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _search = TextEditingController();
  String? _statusFilter;
  String? _directionFilter;

  bool get _isQuote => widget.mode == DocumentPageMode.quote;
  String get _title => _isQuote ? 'پیش‌فاکتورها' : 'سفارش‌ها';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor({CrmQuote? quote, CrmOrder? order}) async {
    if (widget.store.customers.isEmpty) {
      showCrmNotice(
        context,
        'ابتدا یک مشتری یا تأمین‌کننده ثبت کنید.',
        type: CrmNoticeType.warning,
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => DocumentEditorDialog(
        store: widget.store,
        mode: widget.mode,
        quote: quote,
        order: order,
      ),
    );
    if (mounted && saved == true) {
      showCrmNotice(
        context,
        quote == null && order == null ? 'سند جدید ثبت شد.' : 'سند ویرایش شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _deleteQuote(CrmQuote item) async {
    if (!await confirmDelete(context, label: item.quoteNumber)) return;
    await widget.store.deleteQuote(item);
  }

  Future<void> _deleteOrder(CrmOrder item) async {
    if (!await confirmDelete(context, label: item.orderNumber)) return;
    await widget.store.deleteOrder(item);
  }

  Future<void> _setQuoteStatus(CrmQuote item, String status) async {
    final customer = widget.store.customers.firstWhere(
      (value) => value.id == item.customerId,
    );
    await widget.store.saveQuote(
      id: item.id,
      quoteNumber: item.quoteNumber,
      customer: customer,
      direction: item.direction,
      status: status,
      totalAmount: item.totalAmount,
      notes: item.notes,
      validUntil: item.validUntil,
      lineItems: item.lineItems,
    );
  }

  Future<void> _setOrderStatus(CrmOrder item, String status) async {
    final customer = widget.store.customers.firstWhere(
      (value) => value.id == item.customerId,
    );
    await widget.store.saveOrder(
      id: item.id,
      orderNumber: item.orderNumber,
      customer: customer,
      direction: item.direction,
      status: status,
      totalAmount: item.totalAmount,
      notes: item.notes,
      orderAt: item.orderAt,
      lineItems: item.lineItems,
      sourceType: item.sourceType,
      sourceId: item.sourceId,
    );
  }

  Future<void> _printQuote(CrmQuote item) => CrmReportService.printDocument(
    context: context,
    title: 'پیش‌فاکتور ${item.direction}',
    number: item.quoteNumber,
    customer: item.customerName,
    direction: item.direction,
    status: item.status,
    lineItems: item.lineItems,
    totalAmount: item.totalAmount,
    notes: item.notes,
  );

  Future<void> _printOrder(CrmOrder item) => CrmReportService.printDocument(
    context: context,
    title: 'سفارش ${item.direction}',
    number: item.orderNumber,
    customer: item.customerName,
    direction: item.direction,
    status: item.status,
    lineItems: item.lineItems,
    totalAmount: item.totalAmount,
    notes: item.notes,
  );

  Future<void> _printReport() {
    final quotes = _filteredQuotes();
    final orders = _filteredOrders();
    final rows = _isQuote
        ? quotes
              .map(
                (item) => <Object?>[
                  item.quoteNumber,
                  item.customerName,
                  item.direction,
                  item.status,
                  item.lineItems.length,
                  formatPersianInteger(item.totalAmount),
                  item.validUntil == null ? '—' : compactDate(item.validUntil!),
                ],
              )
              .toList()
        : orders
              .map(
                (item) => <Object?>[
                  item.orderNumber,
                  item.customerName,
                  item.direction,
                  item.status,
                  item.lineItems.length,
                  formatPersianInteger(item.totalAmount),
                  compactDate(item.orderAt),
                ],
              )
              .toList();
    return CrmReportService.printTable(
      context: context,
      title: 'گزارش $_title',
      headers: const [
        'شماره',
        'طرف حساب',
        'نوع',
        'وضعیت',
        'ردیف',
        'مبلغ کل',
        'تاریخ',
      ],
      rows: rows,
      rowDates: _isQuote
          ? quotes.map((item) => item.validUntil ?? item.updatedAt).toList()
          : orders.map((item) => item.orderAt).toList(),
      numericColumns: const {4, 5},
    );
  }

  List<CrmQuote> _filteredQuotes() {
    final needle = _search.text.trim().toLowerCase();
    return widget.store.quotes.where((item) {
      return (needle.isEmpty ||
              item.quoteNumber.toLowerCase().contains(needle) ||
              item.customerName.toLowerCase().contains(needle) ||
              item.lineItems.any(
                (line) =>
                    line.description.toLowerCase().contains(needle) ||
                    line.productCode.toLowerCase().contains(needle),
              )) &&
          (_statusFilter == null || item.status == _statusFilter) &&
          (_directionFilter == null || item.direction == _directionFilter);
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<CrmOrder> _filteredOrders() {
    final needle = _search.text.trim().toLowerCase();
    return widget.store.orders.where((item) {
      return (needle.isEmpty ||
              item.orderNumber.toLowerCase().contains(needle) ||
              item.customerName.toLowerCase().contains(needle) ||
              item.lineItems.any(
                (line) =>
                    line.description.toLowerCase().contains(needle) ||
                    line.productCode.toLowerCase().contains(needle),
              )) &&
          (_statusFilter == null || item.status == _statusFilter) &&
          (_directionFilter == null || item.direction == _directionFilter);
    }).toList()..sort((a, b) => b.orderAt.compareTo(a.orderAt));
  }

  @override
  Widget build(BuildContext context) {
    final quotes = _isQuote ? _filteredQuotes() : const <CrmQuote>[];
    final orders = _isQuote ? const <CrmOrder>[] : _filteredOrders();
    final total = _isQuote
        ? quotes.fold<int>(0, (sum, item) => sum + item.totalAmount)
        : orders.fold<int>(0, (sum, item) => sum + item.totalAmount);
    final statuses = _isQuote
        ? const [
            'پیش‌نویس',
            'ارسال شده',
            'تایید شده',
            'رد شده',
            'فاکتور صادر شد',
          ]
        : const [
            'در انتظار تایید',
            'در انتظار تأیید',
            'تایید شده',
            'رد شده',
            'فاکتور صادر شد',
            'تکمیل شده',
          ];
    return ListView(
      children: [
        CrmPageHeader(
          title: _title,
          subtitle: _isQuote
              ? 'پیش‌فاکتور خرید یا فروش را با ردیف کالا، تخفیف و ارزش افزوده مدیریت کنید.'
              : 'سفارش‌های خرید و فروش را از انتظار تایید تا فاکتور و تکمیل پیگیری کنید.',
          actions: [
            OutlinedButton.icon(
              onPressed: _printReport,
              icon: const Icon(Icons.print_outlined),
              label: const Text('گزارش و چاپ'),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: Icon(
                _isQuote ? Icons.note_add_outlined : Icons.add_shopping_cart,
              ),
              label: Text(_isQuote ? 'پیش‌فاکتور جدید' : 'سفارش جدید'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CrmPageToolbar(
          onNew: () => _openEditor(),
          onReport: _printReport,
          onRefresh: widget.store.refresh,
          onSearch: () => setState(() {}),
          onAdvancedFilter: () => setState(() {}),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'کل اسناد',
                value:
                    (_isQuote
                            ? widget.store.quotes.length
                            : widget.store.orders.length)
                        .toString(),
                icon: _isQuote
                    ? Icons.request_quote_outlined
                    : Icons.shopping_cart_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 300,
              child: KpiCard(
                title: 'ارزش اسناد فیلترشده',
                value: compactMoney(total),
                icon: Icons.payments_outlined,
                color: const Color(0xff12966b),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'تایید شده',
                value:
                    (_isQuote
                            ? widget.store.quotes
                                  .where((item) => item.status == 'تایید شده')
                                  .length
                            : widget.store.orders
                                  .where((item) => item.status == 'تایید شده')
                                  .length)
                        .toString(),
                icon: Icons.verified_outlined,
                color: const Color(0xff8349d6),
                onTap: () => setState(() => _statusFilter = 'تایید شده'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'وضعیت گردش سند',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('همه'),
                selected: _statusFilter == null,
                onSelected: (_) => setState(() => _statusFilter = null),
              ),
              ...statuses.toSet().map(
                (status) => ChoiceChip(
                  label: Text(status),
                  selected: _statusFilter == status,
                  onSelected: (_) => setState(() => _statusFilter = status),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'جست‌وجو و فیلتر',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'شماره، طرف حساب، کد یا شرح کالا',
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String?>(
                  initialValue: _directionFilter,
                  decoration: const InputDecoration(labelText: 'نوع سند'),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('خرید و فروش'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'خرید',
                      child: Text('خرید'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'فروش',
                      child: Text('فروش'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _directionFilter = value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: _statusFilter == 'رد شده'
              ? '${_isQuote ? 'پیش‌فاکتورهای' : 'سفارش‌های'} رد شده'
              : _statusFilter == 'تکمیل شده'
              ? 'سفارش‌های انجام شده'
              : 'فهرست $_title',
          trailing: Text(
            '${formatPersianInteger(_isQuote ? quotes.length : orders.length)} سند',
          ),
          padding: const EdgeInsets.all(12),
          child: _isQuote ? _quoteTable(quotes) : _orderTable(orders),
        ),
      ],
    );
  }

  Widget _quoteTable(List<CrmQuote> items) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'پیش‌فاکتوری پیدا نشد',
        message: 'فیلتر را تغییر دهید یا پیش‌فاکتور جدید ثبت کنید.',
      );
    }
    return CrmConfigurableDataTable<CrmQuote>(
      tableId: 'quotes',
      rows: items,
      initialSortColumnId: 'number',
      initialSortAscending: false,
      columns: [
        CrmTableColumn(
          id: 'number',
          label: 'شماره',
          value: (item) => item.quoteNumber,
        ),
        CrmTableColumn(
          id: 'customer',
          label: 'مشتری',
          value: (item) => item.customerName,
        ),
        CrmTableColumn(
          id: 'direction',
          label: 'نوع',
          value: (item) => item.direction,
        ),
        CrmTableColumn(
          id: 'status',
          label: 'وضعیت',
          value: (item) => item.status,
          cell: (context, item) => StatusPill(label: item.status),
        ),
        CrmTableColumn(
          id: 'lines',
          label: 'ردیف کالا',
          value: (item) => formatPersianInteger(item.lineItems.length),
          sortValue: (item) => item.lineItems.length,
          numeric: true,
        ),
        CrmTableColumn(
          id: 'tax',
          label: 'ارزش افزوده',
          value: (item) => compactMoney(
            item.lineItems.fold<int>(0, (sum, line) => sum + line.taxAmount),
          ),
          sortValue: (item) =>
              item.lineItems.fold<int>(0, (sum, line) => sum + line.taxAmount),
          numeric: true,
        ),
        CrmTableColumn(
          id: 'total',
          label: 'مبلغ کل',
          value: (item) => compactMoney(item.totalAmount),
          sortValue: (item) => item.totalAmount,
          numeric: true,
        ),
        CrmTableColumn(
          id: 'actions',
          label: 'عملیات',
          value: (_) => '',
          canHide: false,
          filterable: false,
          cell: (context, item) => PopupMenuButton<String>(
            tooltip: 'عملیات پیش‌فاکتور',
            onSelected: (value) {
              if (value == 'view' || value == 'print') _printQuote(item);
              if (value == 'edit') _openEditor(quote: item);
              if (value == 'note') _openEditor(quote: item);
              if (value == 'approve') _setQuoteStatus(item, 'تایید شده');
              if (value == 'reject') _setQuoteStatus(item, 'رد شده');
              if (value == 'attachments') {
                showCrmAttachmentManager(
                  context,
                  store: widget.store,
                  entityType: 'quote',
                  entityId: item.id,
                  title: item.quoteNumber,
                );
              }
              if (value == 'history') {
                showCrmAuditLog(
                  context,
                  store: widget.store,
                  entityType: 'quote',
                  entityId: item.id,
                  title: item.quoteNumber,
                );
              }
              if (value == 'delete') _deleteQuote(item);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'view', child: Text('مشاهده')),
              PopupMenuItem(value: 'edit', child: Text('ویرایش')),
              PopupMenuItem(value: 'note', child: Text('یادداشت')),
              PopupMenuItem(value: 'print', child: Text('گزارش و چاپ')),
              PopupMenuItem(value: 'approve', child: Text('تایید پیش‌فاکتور')),
              PopupMenuItem(value: 'reject', child: Text('رد پیش‌فاکتور')),
              PopupMenuItem(
                value: 'attachments',
                child: Text('فایل‌های پیوست'),
              ),
              PopupMenuItem(value: 'history', child: Text('تاریخچه')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _orderTable(List<CrmOrder> items) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'سفارشی پیدا نشد',
        message: 'فیلتر را تغییر دهید یا سفارش جدید ثبت کنید.',
      );
    }
    return CrmConfigurableDataTable<CrmOrder>(
      tableId: 'orders',
      rows: items,
      initialSortColumnId: 'date',
      initialSortAscending: false,
      columns: [
        CrmTableColumn(
          id: 'number',
          label: 'شماره',
          value: (item) => item.orderNumber,
        ),
        CrmTableColumn(
          id: 'customer',
          label: 'طرف حساب',
          value: (item) => item.customerName,
        ),
        CrmTableColumn(
          id: 'direction',
          label: 'نوع',
          value: (item) => item.direction,
        ),
        CrmTableColumn(
          id: 'status',
          label: 'وضعیت',
          value: (item) => item.status,
          cell: (context, item) => StatusPill(label: item.status),
        ),
        CrmTableColumn(
          id: 'lines',
          label: 'ردیف کالا',
          value: (item) => formatPersianInteger(item.lineItems.length),
          sortValue: (item) => item.lineItems.length,
          numeric: true,
        ),
        CrmTableColumn(
          id: 'date',
          label: 'تاریخ',
          value: (item) => compactDate(item.orderAt),
          sortValue: (item) => item.orderAt,
        ),
        CrmTableColumn(
          id: 'total',
          label: 'مبلغ کل',
          value: (item) => compactMoney(item.totalAmount),
          sortValue: (item) => item.totalAmount,
          numeric: true,
        ),
        CrmTableColumn(
          id: 'actions',
          label: 'عملیات',
          value: (_) => '',
          canHide: false,
          filterable: false,
          cell: (context, item) => PopupMenuButton<String>(
            tooltip: 'عملیات سفارش',
            onSelected: (value) {
              if (value == 'view' || value == 'print') _printOrder(item);
              if (value == 'edit') _openEditor(order: item);
              if (value == 'note') _openEditor(order: item);
              if (value == 'approve') _setOrderStatus(item, 'تایید شده');
              if (value == 'complete') _setOrderStatus(item, 'تکمیل شده');
              if (value == 'invoice') _setOrderStatus(item, 'فاکتور صادر شد');
              if (value == 'reject') _setOrderStatus(item, 'رد شده');
              if (value == 'attachments') {
                showCrmAttachmentManager(
                  context,
                  store: widget.store,
                  entityType: 'order',
                  entityId: item.id,
                  title: item.orderNumber,
                );
              }
              if (value == 'history') {
                showCrmAuditLog(
                  context,
                  store: widget.store,
                  entityType: 'order',
                  entityId: item.id,
                  title: item.orderNumber,
                );
              }
              if (value == 'delete') _deleteOrder(item);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'view', child: Text('مشاهده')),
              PopupMenuItem(value: 'edit', child: Text('ویرایش')),
              PopupMenuItem(value: 'note', child: Text('یادداشت')),
              PopupMenuItem(value: 'print', child: Text('گزارش و چاپ')),
              PopupMenuItem(value: 'approve', child: Text('تایید سفارش')),
              PopupMenuItem(value: 'complete', child: Text('سفارش انجام شد')),
              PopupMenuItem(value: 'invoice', child: Text('صدور فاکتور')),
              PopupMenuItem(value: 'reject', child: Text('رد سفارش')),
              PopupMenuItem(
                value: 'attachments',
                child: Text('فایل‌های پیوست'),
              ),
              PopupMenuItem(value: 'history', child: Text('تاریخچه')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ),
      ],
    );
  }
}

class DocumentEditorDialog extends StatefulWidget {
  const DocumentEditorDialog({
    super.key,
    required this.store,
    required this.mode,
    this.quote,
    this.order,
    this.initialDirection,
    this.initialStatus,
    this.initialCustomerId,
  });

  final CrmStore store;
  final DocumentPageMode mode;
  final CrmQuote? quote;
  final CrmOrder? order;
  final String? initialDirection;
  final String? initialStatus;
  final String? initialCustomerId;

  @override
  State<DocumentEditorDialog> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _notes = TextEditingController();
  String? _customerId;
  String _direction = 'فروش';
  String _status = 'پیش‌نویس';
  DateTime _date = DateTime.now().add(const Duration(days: 14));
  List<CrmDocumentLine> _lines = [];
  bool _saving = false;

  bool get _isQuote => widget.mode == DocumentPageMode.quote;

  @override
  void initState() {
    super.initState();
    final quote = widget.quote;
    final order = widget.order;
    _direction = widget.initialDirection ?? 'فروش';
    _customerId = widget.initialCustomerId;
    _status =
        widget.initialStatus ?? (_isQuote ? 'پیش‌نویس' : 'در انتظار تایید');
    if (quote != null) {
      _customerId = quote.customerId;
      _number.text = quote.quoteNumber;
      _notes.text = quote.notes;
      _direction = quote.direction;
      _status = quote.status;
      _date = quote.validUntil ?? _date;
      _lines = [...quote.lineItems];
    } else if (order != null) {
      _customerId = order.customerId;
      _number.text = order.orderNumber;
      _notes.text = order.notes;
      _direction = order.direction;
      _status = order.status;
      _date = order.orderAt;
      _lines = [...order.lineItems];
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _gross => _lines.fold(0, (sum, item) => sum + item.grossAmount);
  int get _discount => _lines.fold(0, (sum, item) => sum + item.discountAmount);
  int get _tax => _lines.fold(0, (sum, item) => sum + item.taxAmount);
  int get _total => _lines.fold(0, (sum, item) => sum + item.totalAmount);

  Future<void> _editLine([int? index]) async {
    final line = await showDialog<CrmDocumentLine>(
      context: context,
      builder: (context) => _DocumentLineEditor(
        products: widget.store.products,
        line: index == null ? null : _lines[index],
      ),
    );
    if (line == null || !mounted) return;
    setState(() {
      if (index == null) {
        _lines.add(line);
      } else {
        _lines[index] = line;
      }
    });
  }

  Future<void> _pickDate() async {
    final value = await showCrmJalaliDatePicker(
      context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) {
      showCrmNotice(
        context,
        'حداقل یک ردیف کالا یا خدمات اضافه کنید.',
        type: CrmNoticeType.warning,
      );
      return;
    }
    final customer = widget.store.customers.firstWhere(
      (item) => item.id == _customerId,
    );
    setState(() => _saving = true);
    if (_isQuote) {
      await widget.store.saveQuote(
        id: widget.quote?.id,
        quoteNumber: _number.text.trim().isEmpty ? null : _number.text.trim(),
        customer: customer,
        direction: _direction,
        status: _status,
        totalAmount: _total,
        notes: _notes.text,
        validUntil: _date,
        lineItems: _lines,
      );
    } else {
      await widget.store.saveOrder(
        id: widget.order?.id,
        orderNumber: _number.text.trim().isEmpty ? null : _number.text.trim(),
        customer: customer,
        direction: _direction,
        status: _status,
        totalAmount: _total,
        notes: _notes.text,
        orderAt: _date,
        lineItems: _lines,
        sourceType: widget.order?.sourceType ?? '',
        sourceId: widget.order?.sourceId ?? '',
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _isQuote
        ? const ['پیش‌نویس', 'ارسال شده', 'تایید شده', 'رد شده']
        : const ['در انتظار تایید', 'تایید شده', 'رد شده', 'تکمیل شده'];
    return AlertDialog(
      title: Text(_isQuote ? 'ثبت / ویرایش پیش‌فاکتور' : 'ثبت / ویرایش سفارش'),
      content: CrmDialogContent(
        maxWidth: 980,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveFormGrid(
                  children: [
                    ResponsiveFormField(
                      child: DropdownButtonFormField<String>(
                        initialValue: _customerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'طرف حساب *',
                        ),
                        items: widget.store.customers
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.displayName),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'طرف حساب را انتخاب کنید.' : null,
                        onChanged: (value) =>
                            setState(() => _customerId = value),
                      ),
                    ),
                    ResponsiveFormField(
                      child: TextFormField(
                        controller: _number,
                        decoration: InputDecoration(
                          labelText: _isQuote
                              ? 'شماره پیش‌فاکتور (خودکار)'
                              : 'شماره سفارش (خودکار)',
                        ),
                      ),
                    ),
                    ResponsiveFormField(
                      child: DropdownButtonFormField<String>(
                        initialValue: _direction,
                        decoration: InputDecoration(
                          labelText: _isQuote ? 'نوع پیش‌فاکتور' : 'نوع سفارش',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'فروش', child: Text('فروش')),
                          DropdownMenuItem(value: 'خرید', child: Text('خرید')),
                        ],
                        onChanged: (value) =>
                            setState(() => _direction = value ?? _direction),
                      ),
                    ),
                    ResponsiveFormField(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'وضعیت'),
                        items: {...statuses, _status}
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _status = value ?? _status),
                      ),
                    ),
                    ResponsiveFormField.full(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          '${_isQuote ? 'اعتبار تا' : 'تاریخ سفارش'}: ${compactDate(_date)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'ردیف‌های کالا یا خدمات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: _editLine,
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن ردیف'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_lines.isEmpty)
                  const EmptyState(
                    icon: Icons.playlist_add_outlined,
                    title: 'ردیفی ثبت نشده است',
                    message:
                        'کد کالا، شرح، مقدار، واحد، قیمت، تخفیف و مالیات را اضافه کنید.',
                  )
                else
                  CrmConfigurableDataTable<CrmDocumentLine>(
                    tableId: _isQuote
                        ? 'quote_editor_lines'
                        : 'order_editor_lines',
                    rows: _lines,
                    columns: [
                      CrmTableColumn(
                        id: 'code',
                        label: 'کد',
                        value: (item) => item.productCode,
                      ),
                      CrmTableColumn(
                        id: 'description',
                        label: 'شرح',
                        value: (item) => item.description,
                      ),
                      CrmTableColumn(
                        id: 'quantity',
                        label: 'مقدار',
                        value: (item) => formatPersianInteger(item.quantity),
                        sortValue: (item) => item.quantity,
                        numeric: true,
                      ),
                      CrmTableColumn(
                        id: 'unit',
                        label: 'واحد',
                        value: (item) => item.unit,
                      ),
                      CrmTableColumn(
                        id: 'unit_price',
                        label: 'مبلغ واحد',
                        value: (item) => compactMoney(item.unitPrice),
                        sortValue: (item) => item.unitPrice,
                        numeric: true,
                      ),
                      CrmTableColumn(
                        id: 'discount',
                        label: 'تخفیف',
                        value: (item) =>
                            '${formatPersianInteger(item.discountPercent)}٪',
                        sortValue: (item) => item.discountPercent,
                        numeric: true,
                      ),
                      CrmTableColumn(
                        id: 'tax',
                        label: 'ارزش افزوده',
                        value: (item) => compactMoney(item.taxAmount),
                        sortValue: (item) => item.taxAmount,
                        numeric: true,
                      ),
                      CrmTableColumn(
                        id: 'total',
                        label: 'مبلغ کل',
                        value: (item) => compactMoney(item.totalAmount),
                        sortValue: (item) => item.totalAmount,
                        numeric: true,
                      ),
                      CrmTableColumn(
                        id: 'actions',
                        label: 'عملیات',
                        value: (_) => '',
                        canHide: false,
                        filterable: false,
                        cell: (context, item) => PopupMenuButton<String>(
                          tooltip: 'عملیات ردیف سند',
                          onSelected: (value) {
                            final index = _lines.indexOf(item);
                            if (index < 0) return;
                            if (value == 'edit') _editLine(index);
                            if (value == 'delete') {
                              setState(() => _lines.removeAt(index));
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                            PopupMenuItem(value: 'delete', child: Text('حذف')),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TotalChip(label: 'جمع ناخالص', value: _gross),
                    _TotalChip(label: 'جمع تخفیف', value: _discount),
                    _TotalChip(label: 'جمع ارزش افزوده', value: _tax),
                    _TotalChip(
                      label: 'جمع مبلغ کل',
                      value: _total,
                      emphasized: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'توضیحات سند'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'در حال ذخیره' : 'ذخیره سند'),
        ),
      ],
    );
  }
}

class _DocumentLineEditor extends StatefulWidget {
  const _DocumentLineEditor({required this.products, this.line});

  final List<CrmProduct> products;
  final CrmDocumentLine? line;

  @override
  State<_DocumentLineEditor> createState() => _DocumentLineEditorState();
}

class _DocumentLineEditorState extends State<_DocumentLineEditor> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '۱');
  final _unitPrice = TextEditingController(text: '۰');
  final _discount = TextEditingController(text: '۰');
  final _tax = TextEditingController(text: '۰');
  String _unit = 'عدد';

  @override
  void initState() {
    super.initState();
    final item = widget.line;
    if (item == null) return;
    _code.text = item.productCode;
    _description.text = item.description;
    _quantity.text = formatPersianInteger(item.quantity);
    _unit = item.unit;
    _unitPrice.text = formatPersianInteger(item.unitPrice, grouping: true);
    _discount.text = formatPersianInteger(item.discountPercent);
    _tax.text = formatPersianInteger(item.taxPercent);
  }

  @override
  void dispose() {
    _code.dispose();
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _discount.dispose();
    _tax.dispose();
    super.dispose();
  }

  void _selectProduct(String? id) {
    if (id == null) return;
    final product = widget.products.firstWhere((item) => item.id == id);
    setState(() {
      _code.text = product.sku;
      _description.text = product.name;
      _unit = product.unit.isEmpty ? 'عدد' : product.unit;
      _unitPrice.text = formatPersianInteger(product.unitPrice, grouping: true);
    });
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      CrmDocumentLine(
        productCode: _code.text.trim(),
        description: _description.text.trim(),
        quantity: parsePersianInt(_quantity.text),
        unit: _unit,
        unitPrice: parsePersianInt(_unitPrice.text),
        discountPercent: parsePersianInt(_discount.text).clamp(0, 100),
        taxPercent: parsePersianInt(_tax.text).clamp(0, 100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.line == null ? 'افزودن ردیف سند' : 'ویرایش ردیف سند'),
    content: CrmDialogContent(
      maxWidth: 720,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: ResponsiveFormGrid(
            children: [
              if (widget.products.isNotEmpty)
                ResponsiveFormField.full(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'انتخاب از کالا و موجودی',
                    ),
                    items: widget.products
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text('${item.sku} — ${item.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: _selectProduct,
                  ),
                ),
              ResponsiveFormField(
                child: TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'کد کالا'),
                ),
              ),
              ResponsiveFormField(
                child: TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'شرح کالا یا خدمات *',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'شرح الزامی است.'
                      : null,
                ),
              ),
              ResponsiveFormField(
                child: TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [persianNumberFormatter],
                  decoration: const InputDecoration(
                    labelText: 'تعداد یا مقدار *',
                  ),
                  validator: (value) => parsePersianInt(value ?? '') <= 0
                      ? 'مقدار باید بیشتر از صفر باشد.'
                      : null,
                ),
              ),
              ResponsiveFormField(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'واحد'),
                  items: const ['کیلوگرم', 'عدد', 'تن', 'بسته', 'متر', 'حمل']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _unit = value ?? _unit),
                ),
              ),
              ResponsiveFormField(
                child: TextFormField(
                  controller: _unitPrice,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [persianRialFormatter],
                  decoration: const InputDecoration(
                    labelText: 'مبلغ واحد (ریال)',
                  ),
                ),
              ),
              ResponsiveFormField(
                child: TextFormField(
                  controller: _discount,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [persianNumberFormatter],
                  decoration: const InputDecoration(labelText: 'تخفیف (درصد)'),
                ),
              ),
              ResponsiveFormField(
                child: TextFormField(
                  controller: _tax,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [persianNumberFormatter],
                  decoration: const InputDecoration(
                    labelText: 'ارزش افزوده (درصد)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('انصراف'),
      ),
      FilledButton(onPressed: _save, child: const Text('ذخیره ردیف')),
    ],
  );
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: emphasized
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$label: ${compactMoney(value)}',
      style: TextStyle(
        fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
      ),
    ),
  );
}
