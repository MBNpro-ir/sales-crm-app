import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

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
  int _sortColumn = 0;
  bool _sortAscending = false;

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
        'ابتدا یک مشتری ثبت کنید.',
        type: CrmNoticeType.warning,
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _DocumentEditor(
        store: widget.store,
        mode: widget.mode,
        quote: quote,
        order: order,
      ),
    );
    if (!mounted || saved != true) return;
    showCrmNotice(
      context,
      quote == null && order == null
          ? (_isQuote ? 'پیش‌فاکتور ثبت شد.' : 'سفارش ثبت شد.')
          : 'سند ویرایش شد.',
      type: CrmNoticeType.success,
    );
  }

  Future<void> _deleteQuote(CrmQuote quote) async {
    if (!await confirmDelete(context, label: quote.quoteNumber)) return;
    await widget.store.deleteQuote(quote);
    if (mounted) {
      showCrmNotice(
        context,
        'پیش‌فاکتور حذف و همگام‌سازی شد.',
        type: CrmNoticeType.warning,
      );
    }
  }

  Future<void> _deleteOrder(CrmOrder order) async {
    if (!await confirmDelete(context, label: order.orderNumber)) return;
    await widget.store.deleteOrder(order);
    if (mounted) {
      showCrmNotice(
        context,
        'سفارش حذف و همگام‌سازی شد.',
        type: CrmNoticeType.warning,
      );
    }
  }

  void _sort(int value) => setState(() {
    if (_sortColumn == value) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = value;
      _sortAscending = true;
    }
  });

  @override
  Widget build(BuildContext context) {
    final needle = _search.text.trim().toLowerCase();
    final total = _isQuote
        ? widget.store.quotes.fold<int>(
            0,
            (sum, item) => sum + item.totalAmount,
          )
        : widget.store.orders.fold<int>(
            0,
            (sum, item) => sum + item.totalAmount,
          );
    return ListView(
      children: [
        CrmPageHeader(
          title: _title,
          subtitle: _isQuote
              ? 'پیش‌فاکتورهای مشتریان را ثبت، ارسال و تا زمان تایید پیگیری کنید.'
              : 'سفارش‌های فروش و خرید را از ثبت تا تحویل کنترل کنید.',
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: Icon(
                _isQuote ? Icons.note_add_outlined : Icons.add_shopping_cart,
              ),
              label: Text(_isQuote ? 'پیش‌فاکتور جدید' : 'سفارش جدید'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 250,
              child: KpiCard(
                title: _isQuote ? 'در انتظار تایید' : 'کل سفارش‌ها',
                value:
                    (_isQuote
                            ? widget.store.pendingQuotes
                            : widget.store.orders.length)
                        .toString(),
                icon: _isQuote
                    ? Icons.pending_actions_outlined
                    : Icons.shopping_cart_outlined,
                color: _isQuote
                    ? const Color(0xff8349d6)
                    : const Color(0xffe58a00),
              ),
            ),
            SizedBox(
              width: 330,
              child: KpiCard(
                title: _isQuote ? 'ارزش پیش‌فاکتورها' : 'ارزش سفارش‌ها',
                value: compactMoney(total),
                icon: Icons.payments_outlined,
                color: const Color(0xff12966b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'جست‌وجوی $_title',
          child: AutoInputDirection(
            controller: _search,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: _isQuote
                    ? 'شماره، مشتری یا وضعیت'
                    : 'شماره، طرف حساب یا وضعیت',
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _isQuote ? _quoteSection(needle) : _orderSection(needle),
      ],
    );
  }

  Widget _quoteSection(String needle) {
    final rows = widget.store.quotes
        .where(
          (item) =>
              needle.isEmpty ||
              item.quoteNumber.toLowerCase().contains(needle) ||
              item.customerName.toLowerCase().contains(needle) ||
              item.status.contains(needle),
        )
        .toList();
    final values = <Comparable<Object?> Function(CrmQuote)>[
      (item) => item.quoteNumber,
      (item) => item.customerName,
      (item) => item.totalAmount,
      (item) => item.status,
      (item) => item.validUntil ?? DateTime(9999),
    ];
    rows.sort((left, right) {
      final result = values[_sortColumn](
        left,
      ).compareTo(values[_sortColumn](right));
      return _sortAscending ? result : -result;
    });
    return SectionCard(
      title: 'فهرست پیش‌فاکتورها',
      trailing: Text('${formatPersianInteger(rows.length)} مورد'),
      child: rows.isEmpty
          ? const EmptyState(
              icon: Icons.request_quote_outlined,
              title: 'پیش‌فاکتوری پیدا نشد',
              message: 'سند جدید بسازید یا عبارت جست‌وجو را تغییر دهید.',
            )
          : CrmTableScroll(
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                sortColumnIndex: _sortColumn,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('شماره'),
                    onSort: (_, _) => _sort(0),
                  ),
                  DataColumn(
                    label: const Text('مشتری'),
                    onSort: (_, _) => _sort(1),
                  ),
                  DataColumn(
                    label: const Text('مبلغ (ریال)'),
                    numeric: true,
                    onSort: (_, _) => _sort(2),
                  ),
                  DataColumn(
                    label: const Text('وضعیت'),
                    onSort: (_, _) => _sort(3),
                  ),
                  DataColumn(
                    label: const Text('اعتبار'),
                    onSort: (_, _) => _sort(4),
                  ),
                  const DataColumn(label: Text('یادداشت')),
                  const DataColumn(label: Text('عملیات')),
                ],
                rows: rows
                    .map(
                      (quote) => DataRow(
                        cells: [
                          DataCell(Text(quote.quoteNumber)),
                          DataCell(Text(quote.customerName)),
                          DataCell(Text(compactMoney(quote.totalAmount))),
                          DataCell(StatusPill(label: quote.status)),
                          DataCell(
                            Text(
                              quote.validUntil == null
                                  ? '—'
                                  : compactDate(quote.validUntil!),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                quote.notes,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            RecordActions(
                              onEdit: () => _openEditor(quote: quote),
                              onDelete: () => _deleteQuote(quote),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Widget _orderSection(String needle) {
    final rows = widget.store.orders
        .where(
          (item) =>
              needle.isEmpty ||
              item.orderNumber.toLowerCase().contains(needle) ||
              item.customerName.toLowerCase().contains(needle) ||
              item.status.contains(needle),
        )
        .toList();
    final values = <Comparable<Object?> Function(CrmOrder)>[
      (item) => item.orderNumber,
      (item) => item.customerName,
      (item) => item.direction,
      (item) => item.totalAmount,
      (item) => item.status,
      (item) => item.orderAt,
    ];
    rows.sort((left, right) {
      final result = values[_sortColumn](
        left,
      ).compareTo(values[_sortColumn](right));
      return _sortAscending ? result : -result;
    });
    return SectionCard(
      title: 'فهرست سفارش‌ها',
      trailing: Text('${formatPersianInteger(rows.length)} مورد'),
      child: rows.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'سفارشی پیدا نشد',
              message: 'سند جدید بسازید یا عبارت جست‌وجو را تغییر دهید.',
            )
          : CrmTableScroll(
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                sortColumnIndex: _sortColumn,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('شماره'),
                    onSort: (_, _) => _sort(0),
                  ),
                  DataColumn(
                    label: const Text('مشتری / تأمین‌کننده'),
                    onSort: (_, _) => _sort(1),
                  ),
                  DataColumn(
                    label: const Text('نوع'),
                    onSort: (_, _) => _sort(2),
                  ),
                  DataColumn(
                    label: const Text('مبلغ (ریال)'),
                    numeric: true,
                    onSort: (_, _) => _sort(3),
                  ),
                  DataColumn(
                    label: const Text('وضعیت'),
                    onSort: (_, _) => _sort(4),
                  ),
                  DataColumn(
                    label: const Text('تاریخ'),
                    onSort: (_, _) => _sort(5),
                  ),
                  const DataColumn(label: Text('عملیات')),
                ],
                rows: rows
                    .map(
                      (order) => DataRow(
                        cells: [
                          DataCell(Text(order.orderNumber)),
                          DataCell(Text(order.customerName)),
                          DataCell(
                            Text(
                              order.direction,
                              style: TextStyle(
                                color: order.direction == 'خرید'
                                    ? const Color(0xffe58a00)
                                    : const Color(0xff12966b),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          DataCell(Text(compactMoney(order.totalAmount))),
                          DataCell(StatusPill(label: order.status)),
                          DataCell(Text(compactDate(order.orderAt))),
                          DataCell(
                            RecordActions(
                              onEdit: () => _openEditor(order: order),
                              onDelete: () => _deleteOrder(order),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

class _DocumentEditor extends StatefulWidget {
  const _DocumentEditor({
    required this.store,
    required this.mode,
    this.quote,
    this.order,
  });

  final CrmStore store;
  final DocumentPageMode mode;
  final CrmQuote? quote;
  final CrmOrder? order;

  @override
  State<_DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<_DocumentEditor> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '۰');
  final _notes = TextEditingController();
  String? _customerId;
  String _status = 'پیش‌نویس';
  String _direction = 'فروش';
  DateTime? _validUntil = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  bool get _isQuote => widget.mode == DocumentPageMode.quote;
  bool get _editing => widget.quote != null || widget.order != null;

  @override
  void initState() {
    super.initState();
    final quote = widget.quote;
    final order = widget.order;
    if (quote != null) {
      _customerId = quote.customerId;
      _amount.text = formatPersianInteger(quote.totalAmount, grouping: true);
      _notes.text = quote.notes;
      _status = quote.status;
      _validUntil = quote.validUntil;
    }
    if (order != null) {
      _customerId = order.customerId;
      _amount.text = formatPersianInteger(order.totalAmount, grouping: true);
      _notes.text = order.notes;
      _status = order.status;
      _direction = order.direction;
    }
    if (!_editing) _status = _isQuote ? 'پیش‌نویس' : 'در انتظار تایید';
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showCrmJalaliDatePicker(
      context,
      initialDate: _validUntil ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null && mounted) {
      setState(() => _validUntil = date);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final customer = widget.store.customers.firstWhere(
      (item) => item.id == _customerId,
    );
    setState(() => _saving = true);
    final amount = parsePersianInt(_amount.text);
    if (_isQuote) {
      final quote = widget.quote;
      await widget.store.saveQuote(
        id: quote?.id,
        quoteNumber: quote?.quoteNumber,
        customer: customer,
        status: _status,
        totalAmount: amount,
        notes: _notes.text,
        validUntil: _validUntil,
      );
    } else {
      final order = widget.order;
      await widget.store.saveOrder(
        id: order?.id,
        orderNumber: order?.orderNumber,
        orderAt: order?.orderAt,
        customer: customer,
        direction: _direction,
        status: _status,
        totalAmount: amount,
        notes: _notes.text,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _isQuote
        ? const ['پیش‌نویس', 'ارسال شده', 'تایید شده', 'رد شده']
        : const ['در انتظار تایید', 'تایید شده', 'در حال تحویل', 'تکمیل شده'];
    return AlertDialog(
      title: Text(
        _editing
            ? 'ویرایش ${_isQuote ? 'پیش‌فاکتور' : 'سفارش'}'
            : 'ثبت ${_isQuote ? 'پیش‌فاکتور' : 'سفارش'}',
      ),
      content: CrmDialogContent(
        maxWidth: 680,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: ResponsiveFormGrid(
              children: [
                ResponsiveFormField.full(
                  child: DropdownButtonFormField<String>(
                    initialValue: _customerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _isQuote ? 'مشتری *' : 'طرف حساب *',
                    ),
                    items: widget.store.customers
                        .map(
                          (customer) => DropdownMenuItem(
                            value: customer.id,
                            child: Text(
                              customer.company.isEmpty
                                  ? customer.name
                                  : customer.company,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'طرف حساب را انتخاب کنید.' : null,
                    onChanged: (value) => setState(() => _customerId = value),
                  ),
                ),
                if (!_isQuote)
                  ResponsiveFormField(
                    child: DropdownButtonFormField<String>(
                      initialValue: _direction,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نوع سفارش'),
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
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'وضعیت'),
                    items: statuses
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                ),
                ResponsiveFormField(
                  child: AutoInputDirection(
                    controller: _amount,
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [persianRialFormatter],
                      decoration: const InputDecoration(
                        labelText: 'مبلغ کل (ریال) *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'مبلغ را وارد کنید.'
                          : null,
                    ),
                  ),
                ),
                if (_isQuote)
                  ResponsiveFormField.full(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _validUntil == null
                            ? 'بدون تاریخ اعتبار'
                            : 'اعتبار تا: ${compactDate(_validUntil!)}',
                      ),
                    ),
                  ),
                ResponsiveFormField.full(
                  child: AutoInputDirection(
                    controller: _notes,
                    child: TextFormField(
                      controller: _notes,
                      minLines: 3,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'یادداشت',
                        alignLabelWithHint: true,
                      ),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'در حال ذخیره' : 'ذخیره'),
        ),
      ],
    );
  }
}
