import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  final _search = TextEditingController();
  int _sortColumn = 4;
  bool _sortAscending = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor([CrmOpportunity? opportunity]) async {
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
      builder: (context) =>
          _OpportunityEditor(store: widget.store, opportunity: opportunity),
    );
    if (!mounted || saved != true) return;
    showCrmNotice(
      context,
      opportunity == null ? 'فرصت فروش ثبت شد.' : 'فرصت فروش ویرایش شد.',
      type: CrmNoticeType.success,
    );
  }

  Future<void> _delete(CrmOpportunity opportunity) async {
    if (!await confirmDelete(context, label: opportunity.title)) return;
    await widget.store.deleteOpportunity(opportunity);
    if (mounted) {
      showCrmNotice(
        context,
        'فرصت به حذف‌شده‌ها منتقل شد.',
        type: CrmNoticeType.warning,
      );
    }
  }

  void _sort(int index) => setState(() {
    if (_sortColumn == index) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = index;
      _sortAscending = true;
    }
  });

  @override
  Widget build(BuildContext context) {
    final needle = _search.text.trim().toLowerCase();
    final rows = widget.store.opportunities
        .where(
          (item) =>
              needle.isEmpty ||
              item.title.toLowerCase().contains(needle) ||
              item.customerName.toLowerCase().contains(needle) ||
              item.stage.contains(needle),
        )
        .toList();
    final values = <Comparable<Object?> Function(CrmOpportunity)>[
      (item) => item.customerName,
      (item) => item.title,
      (item) => item.stage,
      (item) => item.amount,
      (item) => item.probability,
      (item) => item.expectedClose ?? DateTime(9999),
    ];
    rows.sort((left, right) {
      final result = values[_sortColumn](
        left,
      ).compareTo(values[_sortColumn](right));
      return _sortAscending ? result : -result;
    });
    final total = widget.store.opportunities.fold<int>(
      0,
      (sum, item) => sum + item.amount,
    );
    const stages = [
      'تماس اولیه',
      'نیازسنجی',
      'پیش‌فاکتور',
      'مذاکره',
      'برنده شده',
      'از دست رفته',
    ];
    return ListView(
      children: [
        CrmPageHeader(
          title: 'فرصت‌های فروش',
          subtitle:
              'فرصت‌ها را از تماس اولیه تا قرارداد در قیف فروش پیگیری کنید.',
          actions: [
            FilledButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.add_chart_rounded),
              label: const Text('فرصت جدید'),
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
                title: 'فرصت‌های باز',
                value: widget.store.openOpportunities.toString(),
                icon: Icons.track_changes_rounded,
                color: const Color(0xff8349d6),
              ),
            ),
            SizedBox(
              width: 280,
              child: KpiCard(
                title: 'ارزش کل قیف',
                value: compactMoney(total),
                icon: Icons.account_tree_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 280,
              child: KpiCard(
                title: 'درآمد وزن‌دار',
                value: compactMoney(widget.store.weightedPipeline),
                icon: Icons.auto_graph_rounded,
                color: const Color(0xff12966b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'نمای قیف فروش',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stages.map((stage) {
              final count = widget.store.opportunities
                  .where((item) => item.stage == stage)
                  .length;
              return Chip(
                avatar: CircleAvatar(child: Text(formatPersianInteger(count))),
                label: Text(stage),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'جست‌وجوی فرصت‌ها',
          child: AutoInputDirection(
            controller: _search,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'مشتری، عنوان یا مرحله فروش',
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'فرصت‌های ثبت‌شده',
          trailing: Text('${formatPersianInteger(rows.length)} مورد'),
          child: rows.isEmpty
              ? const EmptyState(
                  icon: Icons.track_changes_outlined,
                  title: 'فرصتی پیدا نشد',
                  message: 'فرصت جدیدی ثبت کنید یا جست‌وجو را تغییر دهید.',
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
                        label: const Text('مشتری'),
                        onSort: (_, _) => _sort(0),
                      ),
                      DataColumn(
                        label: const Text('عنوان'),
                        onSort: (_, _) => _sort(1),
                      ),
                      DataColumn(
                        label: const Text('مرحله'),
                        onSort: (_, _) => _sort(2),
                      ),
                      DataColumn(
                        label: const Text('مبلغ (ریال)'),
                        numeric: true,
                        onSort: (_, _) => _sort(3),
                      ),
                      DataColumn(
                        label: const Text('احتمال'),
                        numeric: true,
                        onSort: (_, _) => _sort(4),
                      ),
                      DataColumn(
                        label: const Text('تاریخ هدف'),
                        onSort: (_, _) => _sort(5),
                      ),
                      const DataColumn(label: Text('عملیات')),
                    ],
                    rows: rows
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(Text(item.customerName)),
                              DataCell(
                                SizedBox(
                                  width: 190,
                                  child: Text(
                                    item.title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(StatusPill(label: item.stage)),
                              DataCell(Text(compactMoney(item.amount))),
                              DataCell(
                                Text(
                                  '${formatPersianInteger(item.probability)}٪',
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.expectedClose == null
                                      ? '—'
                                      : compactDate(item.expectedClose!),
                                ),
                              ),
                              DataCell(
                                RecordActions(
                                  onEdit: () => _openEditor(item),
                                  onDelete: () => _delete(item),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _OpportunityEditor extends StatefulWidget {
  const _OpportunityEditor({required this.store, this.opportunity});

  final CrmStore store;
  final CrmOpportunity? opportunity;

  @override
  State<_OpportunityEditor> createState() => _OpportunityEditorState();
}

class _OpportunityEditorState extends State<_OpportunityEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController(text: '۰');
  final _notes = TextEditingController();
  String? _customerId;
  String _stage = 'تماس اولیه';
  double _probability = 20;
  DateTime? _expectedClose = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.opportunity;
    if (item == null) return;
    _customerId = item.customerId;
    _title.text = item.title;
    _amount.text = formatPersianInteger(item.amount, grouping: true);
    _notes.text = item.notes;
    _stage = item.stage;
    _probability = item.probability.toDouble();
    _expectedClose = item.expectedClose;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showCrmJalaliDatePicker(
      context,
      initialDate: _expectedClose ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null && mounted) {
      setState(() => _expectedClose = date);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final customer = widget.store.customers.firstWhere(
      (item) => item.id == _customerId,
    );
    setState(() => _saving = true);
    await widget.store.saveOpportunity(
      id: widget.opportunity?.id,
      customer: customer,
      title: _title.text,
      stage: _stage,
      amount: parsePersianInt(_amount.text),
      probability: _probability.round(),
      notes: _notes.text,
      expectedClose: _expectedClose,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    const stages = [
      'تماس اولیه',
      'نیازسنجی',
      'پیش‌فاکتور',
      'مذاکره',
      'برنده شده',
      'از دست رفته',
    ];
    return AlertDialog(
      title: Text(
        widget.opportunity == null ? 'ثبت فرصت فروش' : 'ویرایش فرصت فروش',
      ),
      content: CrmDialogContent(
        maxWidth: 700,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: ResponsiveFormGrid(
              children: [
                ResponsiveFormField.full(
                  child: DropdownButtonFormField<String>(
                    initialValue: _customerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'مشتری *'),
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
                        value == null ? 'یک مشتری انتخاب کنید.' : null,
                    onChanged: (value) => setState(() => _customerId = value),
                  ),
                ),
                ResponsiveFormField.full(
                  child: AutoInputDirection(
                    controller: _title,
                    child: TextFormField(
                      controller: _title,
                      inputFormatters: [textOnlyFormatter],
                      decoration: const InputDecoration(
                        labelText: 'عنوان فرصت *',
                        prefixIcon: Icon(Icons.track_changes_rounded),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'عنوان فرصت الزامی است.'
                          : null,
                    ),
                  ),
                ),
                ResponsiveFormField(
                  child: DropdownButtonFormField<String>(
                    initialValue: _stage,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'مرحله فروش'),
                    items: stages
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _stage = value ?? _stage),
                  ),
                ),
                ResponsiveFormField(
                  child: AutoInputDirection(
                    controller: _amount,
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [persianNumberFormatter],
                      decoration: const InputDecoration(
                        labelText: 'مبلغ احتمالی (ریال)',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'مبلغ را وارد کنید.'
                          : null,
                    ),
                  ),
                ),
                ResponsiveFormField.full(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'احتمال موفقیت: ${formatPersianInteger(_probability.round())}٪',
                      ),
                      Slider(
                        value: _probability,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${formatPersianInteger(_probability.round())}٪',
                        onChanged: (value) =>
                            setState(() => _probability = value),
                      ),
                    ],
                  ),
                ),
                ResponsiveFormField.full(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _expectedClose == null
                          ? 'تعیین تاریخ هدف'
                          : 'تاریخ هدف: ${compactDate(_expectedClose!)}',
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
                        labelText: 'یادداشت و اقدام بعدی',
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
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            widget.opportunity == null ? 'ثبت فرصت' : 'ذخیره تغییرات',
          ),
        ),
      ],
    );
  }
}
