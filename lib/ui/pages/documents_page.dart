import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

enum DocumentPageMode { quote, order }

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key, required this.store, required this.mode});

  final CrmStore store;
  final DocumentPageMode mode;

  bool get _isQuote => mode == DocumentPageMode.quote;
  String get _title => _isQuote ? 'پیش‌فاکتورها' : 'سفارش‌ها';
  String get _subtitle => _isQuote
      ? 'پیش‌فاکتورهای مشتریان را ثبت، ارسال و تا زمان تایید پیگیری کنید.'
      : 'سفارش‌های فروش و خرید را از ثبت تا تحویل کنترل کنید.';

  Future<void> _openEditor(BuildContext context) async {
    if (store.customers.isEmpty) {
      showCrmNotice(
        context,
        'ابتدا یک مشتری ثبت کنید.',
        type: CrmNoticeType.warning,
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _DocumentEditor(store: store, mode: mode),
    );
    if (saved == true && context.mounted) {
      showCrmNotice(
        context,
        _isQuote ? 'پیش‌فاکتور ثبت شد.' : 'سفارش ثبت شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _isQuote ? store.quotes : store.orders;
    final total = _isQuote
        ? store.quotes.fold(0, (sum, item) => sum + item.totalAmount)
        : store.orders.fold(0, (sum, item) => sum + item.totalAmount);
    final count = _isQuote ? store.pendingQuotes : records.length;
    return ListView(
      children: [
        CrmPageHeader(
          title: _title,
          subtitle: _subtitle,
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(context),
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
                value: count.toString(),
                icon: _isQuote
                    ? Icons.pending_actions_outlined
                    : Icons.shopping_cart_outlined,
                color: _isQuote
                    ? const Color(0xff8349d6)
                    : const Color(0xffe58a00),
              ),
            ),
            SizedBox(
              width: 310,
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
          title: _isQuote ? 'فهرست پیش‌فاکتورها' : 'فهرست سفارش‌ها',
          child: records.isEmpty
              ? EmptyState(
                  icon: _isQuote
                      ? Icons.request_quote_outlined
                      : Icons.shopping_bag_outlined,
                  title: _isQuote
                      ? 'پیش‌فاکتوری ثبت نشده است'
                      : 'سفارشی ثبت نشده است',
                  message: 'برای شروع، یک سند جدید برای مشتری ایجاد کنید.',
                )
              : _isQuote
              ? _QuoteTable(quotes: store.quotes)
              : _OrderTable(orders: store.orders),
        ),
      ],
    );
  }
}

class _QuoteTable extends StatelessWidget {
  const _QuoteTable({required this.quotes});

  final List<CrmQuote> quotes;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        columns: const [
          DataColumn(label: Text('شماره')),
          DataColumn(label: Text('مشتری')),
          DataColumn(label: Text('مبلغ')),
          DataColumn(label: Text('وضعیت')),
          DataColumn(label: Text('اعتبار')),
          DataColumn(label: Text('یادداشت')),
        ],
        rows: quotes.map((quote) {
          return DataRow(
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
                  child: Text(quote.notes, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _OrderTable extends StatelessWidget {
  const _OrderTable({required this.orders});

  final List<CrmOrder> orders;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        columns: const [
          DataColumn(label: Text('شماره')),
          DataColumn(label: Text('مشتری / تامین‌کننده')),
          DataColumn(label: Text('نوع')),
          DataColumn(label: Text('مبلغ')),
          DataColumn(label: Text('وضعیت')),
          DataColumn(label: Text('تاریخ')),
        ],
        rows: orders.map((order) {
          return DataRow(
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
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DocumentEditor extends StatefulWidget {
  const _DocumentEditor({required this.store, required this.mode});

  final CrmStore store;
  final DocumentPageMode mode;

  @override
  State<_DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<_DocumentEditor> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String? _customerId;
  String _status = 'پیش‌نویس';
  String _direction = 'فروش';
  DateTime? _validUntil = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  bool get _isQuote => widget.mode == DocumentPageMode.quote;

  @override
  void initState() {
    super.initState();
    _status = _isQuote ? 'پیش‌نویس' : 'در انتظار تایید';
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(_validUntil ?? DateTime.now()),
      firstDate: Jalali.fromDateTime(DateTime.now()),
      lastDate: Jalali.fromDateTime(
        DateTime.now().add(const Duration(days: 730)),
      ),
    );
    if (date != null && mounted) {
      setState(() {
        _validUntil = date.toDateTime();
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final customer = widget.store.customers.firstWhere(
      (item) => item.id == _customerId,
    );
    setState(() {
      _saving = true;
    });
    final amount = parsePersianInt(_amount.text);
    if (_isQuote) {
      await widget.store.saveQuote(
        customer: customer,
        status: _status,
        totalAmount: amount,
        notes: _notes.text,
        validUntil: _validUntil,
      );
    } else {
      await widget.store.saveOrder(
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
    return AlertDialog(
      title: Text(_isQuote ? 'ثبت پیش‌فاکتور' : 'ثبت سفارش'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: _isQuote ? 'مشتری *' : 'طرف حساب *',
                    ),
                    items: widget.store.customers.map((customer) {
                      final label = customer.company.isEmpty
                          ? customer.name
                          : customer.company;
                      return DropdownMenuItem(
                        value: customer.id,
                        child: Text(label),
                      );
                    }).toList(),
                    validator: (value) =>
                        value == null ? 'طرف حساب را انتخاب کنید.' : null,
                    onChanged: (value) {
                      setState(() {
                        _customerId = value;
                      });
                    },
                  ),
                ),
                if (!_isQuote)
                  SizedBox(
                    width: 258,
                    child: DropdownButtonFormField<String>(
                      initialValue: _direction,
                      decoration: const InputDecoration(labelText: 'نوع سفارش'),
                      items: const [
                        DropdownMenuItem(value: 'فروش', child: Text('فروش')),
                        DropdownMenuItem(value: 'خرید', child: Text('خرید')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _direction = value ?? _direction;
                        });
                      },
                    ),
                  ),
                SizedBox(
                  width: _isQuote ? 258 : 258,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'وضعیت'),
                    items: _isQuote
                        ? const [
                            DropdownMenuItem(
                              value: 'پیش‌نویس',
                              child: Text('پیش‌نویس'),
                            ),
                            DropdownMenuItem(
                              value: 'ارسال شده',
                              child: Text('ارسال شده'),
                            ),
                            DropdownMenuItem(
                              value: 'تایید شده',
                              child: Text('تایید شده'),
                            ),
                            DropdownMenuItem(
                              value: 'رد شده',
                              child: Text('رد شده'),
                            ),
                          ]
                        : const [
                            DropdownMenuItem(
                              value: 'در انتظار تایید',
                              child: Text('در انتظار تایید'),
                            ),
                            DropdownMenuItem(
                              value: 'تایید شده',
                              child: Text('تایید شده'),
                            ),
                            DropdownMenuItem(
                              value: 'در حال تحویل',
                              child: Text('در حال تحویل'),
                            ),
                            DropdownMenuItem(
                              value: 'تکمیل شده',
                              child: Text('تکمیل شده'),
                            ),
                          ],
                    onChanged: (value) {
                      setState(() {
                        _status = value ?? _status;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 258,
                  child: AutoInputDirection(
                    controller: _amount,
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مبلغ کل (تومان) *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'مبلغ را وارد کنید.'
                          : null,
                    ),
                  ),
                ),
                if (_isQuote)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _validUntil == null
                            ? 'بدون تاریخ اعتبار'
                            : 'اعتبار تا: ' + compactDate(_validUntil!),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
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
