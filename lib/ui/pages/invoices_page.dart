import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';
import 'documents_page.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key, required this.store, required this.direction});

  final CrmStore store;
  final String direction;

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _search = TextEditingController();
  bool _issuedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_InvoiceEntry> get _entries {
    final needle = _search.text.trim().toLowerCase();
    final accepted = {'تایید شده', 'تأیید شده', 'فاکتور صادر شد'};
    final entries =
        <_InvoiceEntry>[
            ...widget.store.quotes
                .where(
                  (item) =>
                      item.direction == widget.direction &&
                      accepted.contains(item.status),
                )
                .map(_InvoiceEntry.quote),
            ...widget.store.orders
                .where(
                  (item) =>
                      item.direction == widget.direction &&
                      accepted.contains(item.status),
                )
                .map(_InvoiceEntry.order),
          ].where((entry) {
            return (!_issuedOnly || entry.status == 'فاکتور صادر شد') &&
                (needle.isEmpty ||
                    entry.number.toLowerCase().contains(needle) ||
                    entry.customer.toLowerCase().contains(needle) ||
                    entry.lines.any(
                      (line) =>
                          line.productCode.toLowerCase().contains(needle) ||
                          line.description.toLowerCase().contains(needle),
                    ));
          }).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<void> _newInvoice() async {
    if (widget.store.customers.isEmpty) {
      showCrmNotice(
        context,
        'ابتدا طرف حساب را ثبت کنید.',
        type: CrmNoticeType.warning,
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => DocumentEditorDialog(
        store: widget.store,
        mode: DocumentPageMode.order,
        initialDirection: widget.direction,
        initialStatus: 'فاکتور صادر شد',
      ),
    );
    if (mounted && saved == true) {
      showCrmNotice(
        context,
        'فاکتور ${widget.direction} صادر شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _edit(_InvoiceEntry entry) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => DocumentEditorDialog(
        store: widget.store,
        mode: entry.quote != null
            ? DocumentPageMode.quote
            : DocumentPageMode.order,
        quote: entry.quote,
        order: entry.order,
      ),
    );
  }

  Future<void> _issue(_InvoiceEntry entry) async {
    if (entry.quote case final quote?) {
      final customer = widget.store.customers.firstWhere(
        (item) => item.id == quote.customerId,
      );
      await widget.store.saveQuote(
        id: quote.id,
        quoteNumber: quote.quoteNumber,
        customer: customer,
        direction: quote.direction,
        status: 'فاکتور صادر شد',
        totalAmount: quote.totalAmount,
        notes: quote.notes,
        validUntil: quote.validUntil,
        lineItems: quote.lineItems,
      );
    } else if (entry.order case final order?) {
      final customer = widget.store.customers.firstWhere(
        (item) => item.id == order.customerId,
      );
      await widget.store.saveOrder(
        id: order.id,
        orderNumber: order.orderNumber,
        customer: customer,
        direction: order.direction,
        status: 'فاکتور صادر شد',
        totalAmount: order.totalAmount,
        notes: order.notes,
        orderAt: order.orderAt,
        lineItems: order.lineItems,
        sourceType: order.sourceType,
        sourceId: order.sourceId,
      );
    }
    if (mounted) {
      showCrmNotice(
        context,
        'فاکتور صادر و آماده چاپ شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _print(_InvoiceEntry entry) => CrmReportService.printDocument(
    context: context,
    title: 'فاکتور ${widget.direction}',
    number: entry.number,
    customer: entry.customer,
    direction: widget.direction,
    status: entry.status,
    lineItems: entry.lines,
    totalAmount: entry.totalAmount,
    notes: entry.notes,
  );

  Future<void> _printReport() => CrmReportService.printTable(
    context: context,
    title: 'گزارش فاکتورهای ${widget.direction}',
    headers: const ['منبع', 'شماره', 'طرف حساب', 'وضعیت', 'ردیف', 'مبلغ کل'],
    rows: _entries
        .map(
          (item) => <Object?>[
            item.sourceLabel,
            item.number,
            item.customer,
            item.status,
            item.lines.length,
            formatPersianInteger(item.totalAmount),
          ],
        )
        .toList(),
    rowDates: _entries.map((item) => item.updatedAt).toList(),
    numericColumns: const {4, 5},
  );

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final total = entries.fold<int>(0, (sum, item) => sum + item.totalAmount);
    return ListView(
      children: [
        CrmPageHeader(
          title: 'فاکتور ${widget.direction}',
          subtitle:
              'پیش‌فاکتورها و سفارش‌های تاییدشده اینجا آماده صدور فاکتور، چاپ و گزارش هستند.',
          actions: [
            OutlinedButton.icon(
              onPressed: _printReport,
              icon: const Icon(Icons.print_outlined),
              label: const Text('گزارش و چاپ'),
            ),
            FilledButton.icon(
              onPressed: _newInvoice,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('صدور مستقیم فاکتور'),
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
                title: 'آماده صدور',
                value: entries
                    .where((item) => item.status != 'فاکتور صادر شد')
                    .length
                    .toString(),
                icon: Icons.pending_actions_outlined,
                color: const Color(0xffe58a00),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'فاکتور صادرشده',
                value: entries
                    .where((item) => item.status == 'فاکتور صادر شد')
                    .length
                    .toString(),
                icon: Icons.verified_outlined,
                color: const Color(0xff12966b),
                onTap: () => setState(() => _issuedOnly = true),
              ),
            ),
            SizedBox(
              width: 300,
              child: KpiCard(
                title: 'مبلغ کل',
                value: compactMoney(total),
                icon: Icons.payments_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'جست‌وجو و وضعیت',
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
                    hintText: 'شماره، طرف حساب یا کالا',
                  ),
                ),
              ),
              FilterChip(
                selected: _issuedOnly,
                label: const Text('فقط صادرشده‌ها'),
                onSelected: (value) => setState(() => _issuedOnly = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'اسناد متصل و فاکتورها',
          trailing: Text('${formatPersianInteger(entries.length)} سند'),
          padding: const EdgeInsets.all(12),
          child: entries.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'سندی آماده فاکتور نیست',
                  message:
                      'یک پیش‌فاکتور یا سفارش را تایید کنید، یا فاکتور مستقیم بسازید.',
                )
              : CrmConfigurableDataTable<_InvoiceEntry>(
                  tableId: 'invoices_${widget.direction}',
                  rows: entries,
                  initialSortColumnId: 'updated',
                  initialSortAscending: false,
                  columns: [
                    CrmTableColumn(
                      id: 'source',
                      label: 'منبع',
                      value: (entry) => entry.sourceLabel,
                    ),
                    CrmTableColumn(
                      id: 'number',
                      label: 'شماره',
                      value: (entry) => entry.number,
                    ),
                    CrmTableColumn(
                      id: 'customer',
                      label: 'طرف حساب',
                      value: (entry) => entry.customer,
                    ),
                    CrmTableColumn(
                      id: 'status',
                      label: 'وضعیت',
                      value: (entry) => entry.status,
                      cell: (context, entry) => StatusPill(label: entry.status),
                    ),
                    CrmTableColumn(
                      id: 'lines',
                      label: 'ردیف کالا',
                      value: (entry) =>
                          formatPersianInteger(entry.lines.length),
                      sortValue: (entry) => entry.lines.length,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'total',
                      label: 'مبلغ کل',
                      value: (entry) => compactMoney(entry.totalAmount),
                      sortValue: (entry) => entry.totalAmount,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'updated',
                      label: 'آخرین تغییر',
                      value: (entry) => compactDate(entry.updatedAt),
                      sortValue: (entry) => entry.updatedAt,
                      initiallyVisible: false,
                    ),
                    CrmTableColumn(
                      id: 'actions',
                      label: 'عملیات',
                      value: (_) => '',
                      canHide: false,
                      filterable: false,
                      cell: (context, entry) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (entry.status != 'فاکتور صادر شد')
                            FilledButton.tonal(
                              onPressed: () => _issue(entry),
                              child: const Text('صدور'),
                            ),
                          IconButton(
                            onPressed: () => _print(entry),
                            tooltip: 'چاپ فاکتور',
                            icon: const Icon(Icons.print_outlined),
                          ),
                          IconButton(
                            onPressed: () => _edit(entry),
                            tooltip: 'ویرایش سند منبع',
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _InvoiceEntry {
  const _InvoiceEntry._({this.quote, this.order});

  factory _InvoiceEntry.quote(CrmQuote value) => _InvoiceEntry._(quote: value);
  factory _InvoiceEntry.order(CrmOrder value) => _InvoiceEntry._(order: value);

  final CrmQuote? quote;
  final CrmOrder? order;

  String get sourceLabel => quote != null ? 'پیش‌فاکتور' : 'سفارش / فاکتور';
  String get number => quote?.quoteNumber ?? order!.orderNumber;
  String get customer => quote?.customerName ?? order!.customerName;
  String get status => quote?.status ?? order!.status;
  int get totalAmount => quote?.totalAmount ?? order!.totalAmount;
  List<CrmDocumentLine> get lines => quote?.lineItems ?? order!.lineItems;
  String get notes => quote?.notes ?? order!.notes;
  DateTime get updatedAt => quote?.updatedAt ?? order!.updatedAt;
}
