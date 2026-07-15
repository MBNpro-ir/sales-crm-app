import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';

class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  final _search = TextEditingController();
  String? _tradeFilter;
  String? _productFilter;
  String? _provinceFilter;
  String? _cityFilter;
  bool _showActive = true;
  bool _showRealized = false;

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

  Future<void> _toggleRealized(CrmOpportunity item, bool realized) async {
    final customer = widget.store.customers.firstWhere(
      (customer) => customer.id == item.customerId,
    );
    await widget.store.saveOpportunity(
      id: item.id,
      customer: customer,
      title: item.title,
      stage: realized ? 'برنده شده' : 'مذاکره',
      amount: item.amount,
      probability: realized ? 100 : item.probability.clamp(0, 95),
      notes: item.notes,
      expectedClose: item.expectedClose,
      tradeType: item.tradeType,
      productName: item.productName,
      province: item.province,
      city: item.city,
    );
  }

  List<CrmOpportunity> _filteredOpportunities() {
    final needle = _search.text.trim().toLowerCase();
    return widget.store.opportunities.where((item) {
      final realized = item.stage == 'برنده شده';
      final matchesVisibility =
          (_showActive && !realized) || (_showRealized && realized);
      return matchesVisibility &&
          (needle.isEmpty ||
              item.title.toLowerCase().contains(needle) ||
              item.customerName.toLowerCase().contains(needle) ||
              item.productName.toLowerCase().contains(needle) ||
              item.province.toLowerCase().contains(needle) ||
              item.city.toLowerCase().contains(needle) ||
              item.stage.contains(needle)) &&
          (_tradeFilter == null || item.tradeType == _tradeFilter) &&
          (_productFilter == null || item.productName == _productFilter) &&
          (_provinceFilter == null || item.province == _provinceFilter) &&
          (_cityFilter == null || item.city == _cityFilter);
    }).toList();
  }

  Future<void> _printReport() {
    final opportunities = _filteredOpportunities();
    return CrmReportService.printTable(
      context: context,
      title: 'گزارش فرصت‌های خرید و فروش',
      subtitle:
          'قابل تنظیم بر اساس بازه تاریخ، مشتری، کالا و خدمات، شهر، استان و سطح کل/معین/تفصیلی',
      headers: const [
        'ردیف',
        'مشتری',
        'عنوان',
        'نوع',
        'کالا / خدمت',
        'استان هدف',
        'شهر هدف',
        'مرحله',
        'مبلغ',
        'احتمال',
        'تاریخ هدف',
      ],
      rows: opportunities.asMap().entries.map((entry) {
        final item = entry.value;
        return <Object?>[
          entry.key + 1,
          item.customerName,
          item.title,
          item.tradeType,
          item.productName,
          item.province,
          item.city,
          item.stage,
          item.amount,
          item.probability,
          item.expectedClose == null ? '—' : compactDate(item.expectedClose!),
        ];
      }).toList(),
      rowDates: opportunities.map((item) => item.expectedClose).toList(),
      numericColumns: const {8, 9},
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredOpportunities();
    final products =
        widget.store.opportunities
            .map((item) => item.productName)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final provinces =
        widget.store.opportunities
            .map((item) => item.province)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final cities =
        widget.store.opportunities
            .where(
              (item) =>
                  _provinceFilter == null || item.province == _provinceFilter,
            )
            .map((item) => item.city)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
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
          title: 'فرصت‌های خرید و فروش',
          subtitle:
              'فرصت‌ها را از تماس اولیه تا قرارداد در قیف فروش پیگیری کنید.',
          actions: [
            OutlinedButton.icon(
              onPressed: _printReport,
              icon: const Icon(Icons.print_outlined),
              label: const Text('گزارش و چاپ'),
            ),
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
                onTap: () => setState(() => _showActive = true),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'اهداف تحقق‌یافته',
                value: widget.store.opportunities
                    .where((item) => item.stage == 'برنده شده')
                    .length
                    .toString(),
                icon: Icons.emoji_events_outlined,
                color: const Color(0xff12966b),
                onTap: () => setState(() => _showRealized = true),
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
          title: 'گزارش و نمودار تحلیلی قیف خرید و فروش',
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
          title: 'جست‌وجو و نمایش اهداف',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 320,
                child: AutoInputDirection(
                  controller: _search,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'مشتری، عنوان یا مرحله',
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String?>(
                  initialValue: _tradeFilter,
                  decoration: const InputDecoration(labelText: 'نوع فرصت'),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('همه')),
                    DropdownMenuItem<String?>(
                      value: 'خرید',
                      child: Text('خرید'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'فروش',
                      child: Text('فروش'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _tradeFilter = value),
                ),
              ),
              _filterDropdown(
                label: 'کالا / خدمت',
                value: _productFilter,
                values: products,
                onChanged: (value) => setState(() => _productFilter = value),
              ),
              _filterDropdown(
                label: 'استان هدف',
                value: _provinceFilter,
                values: provinces,
                onChanged: (value) => setState(() {
                  _provinceFilter = value;
                  if (value != null && !cities.contains(_cityFilter)) {
                    _cityFilter = null;
                  }
                }),
              ),
              _filterDropdown(
                label: 'شهر هدف',
                value: _cityFilter,
                values: cities,
                onChanged: (value) => setState(() => _cityFilter = value),
              ),
              FilterChip(
                selected: _showActive,
                label: const Text('فرصت‌های فعال'),
                onSelected: (value) => setState(() => _showActive = value),
              ),
              FilterChip(
                selected: _showRealized,
                label: const Text('اهداف تحقق‌یافته'),
                onSelected: (value) => setState(() => _showRealized = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: _showActive && _showRealized
              ? 'همه فرصت‌های ثبت‌شده'
              : _showRealized
              ? 'فرصت‌های تحقق‌یافته (لیست اهداف)'
              : 'فرصت‌های فعال',
          trailing: Text('${formatPersianInteger(rows.length)} مورد'),
          child: rows.isEmpty
              ? const EmptyState(
                  icon: Icons.track_changes_outlined,
                  title: 'فرصتی پیدا نشد',
                  message: 'فرصت جدیدی ثبت کنید یا جست‌وجو را تغییر دهید.',
                )
              : CrmConfigurableDataTable<CrmOpportunity>(
                  tableId: 'opportunities',
                  rows: rows,
                  initialSortColumnId: 'target_date',
                  columns: [
                    CrmTableColumn(
                      id: 'row',
                      label: 'ردیف',
                      value: (item) =>
                          formatPersianInteger(rows.indexOf(item) + 1),
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'customer',
                      label: 'مشتری',
                      value: (item) => item.customerName,
                    ),
                    CrmTableColumn(
                      id: 'title',
                      label: 'عنوان',
                      value: (item) => item.title,
                    ),
                    CrmTableColumn(
                      id: 'trade_type',
                      label: 'نوع',
                      value: (item) => item.tradeType,
                    ),
                    CrmTableColumn(
                      id: 'product',
                      label: 'کالا / خدمت',
                      value: (item) =>
                          item.productName.isEmpty ? '—' : item.productName,
                    ),
                    CrmTableColumn(
                      id: 'province',
                      label: 'استان هدف',
                      value: (item) =>
                          item.province.isEmpty ? '—' : item.province,
                    ),
                    CrmTableColumn(
                      id: 'city',
                      label: 'شهر هدف',
                      value: (item) => item.city.isEmpty ? '—' : item.city,
                    ),
                    CrmTableColumn(
                      id: 'stage',
                      label: 'مرحله',
                      value: (item) => item.stage,
                      cell: (context, item) => StatusPill(label: item.stage),
                    ),
                    CrmTableColumn(
                      id: 'amount',
                      label: 'مبلغ (ریال)',
                      value: (item) => compactMoney(item.amount),
                      sortValue: (item) => item.amount,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'probability',
                      label: 'احتمال',
                      value: (item) =>
                          '${formatPersianInteger(item.probability)}٪',
                      sortValue: (item) => item.probability,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'target_date',
                      label: 'تاریخ هدف',
                      value: (item) => item.expectedClose == null
                          ? '—'
                          : compactDate(item.expectedClose!),
                      sortValue: (item) => item.expectedClose,
                    ),
                    CrmTableColumn(
                      id: 'actions',
                      label: 'عملیات',
                      value: (_) => '',
                      filterable: false,
                      canHide: false,
                      cell: (context, item) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: item.stage == 'برنده شده',
                            onChanged: (value) =>
                                _toggleRealized(item, value ?? false),
                          ),
                          RecordActions(
                            onEdit: () => _openEditor(item),
                            onDelete: () => _delete(item),
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

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('همه')),
        ...values.map(
          (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
        ),
      ],
      onChanged: onChanged,
    ),
  );
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
  final _province = TextEditingController();
  final _city = TextEditingController();
  final _notes = TextEditingController();
  String? _customerId;
  String _stage = 'تماس اولیه';
  String _tradeType = 'فروش';
  String? _productName;
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
    _tradeType = item.tradeType;
    _productName = item.productName.isEmpty ? null : item.productName;
    _province.text = item.province;
    _city.text = item.city;
    _probability = item.probability.toDouble();
    _expectedClose = item.expectedClose;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _province.dispose();
    _city.dispose();
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
      tradeType: _tradeType,
      productName: _productName ?? '',
      province: _province.text,
      city: _city.text,
      expectedClose: _expectedClose,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final productNames = {
      ...widget.store.products
          .where((item) => item.isActive)
          .map((item) => item.name),
      if (_productName != null && _productName!.isNotEmpty) _productName!,
    };
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
        widget.opportunity == null
            ? 'ثبت فرصت خرید یا فروش'
            : 'ویرایش فرصت خرید یا فروش',
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
                    onChanged: (value) => setState(() {
                      _customerId = value;
                      CrmCustomer? customer;
                      for (final item in widget.store.customers) {
                        if (item.id == value) {
                          customer = item;
                          break;
                        }
                      }
                      if (customer != null) {
                        _province.text = customer.province;
                        _city.text = customer.city;
                      }
                    }),
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
                    initialValue: _tradeType,
                    decoration: const InputDecoration(labelText: 'نوع فرصت'),
                    items: const [
                      DropdownMenuItem(value: 'فروش', child: Text('فروش')),
                      DropdownMenuItem(value: 'خرید', child: Text('خرید')),
                    ],
                    onChanged: (value) =>
                        setState(() => _tradeType = value ?? _tradeType),
                  ),
                ),
                ResponsiveFormField.full(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _productName,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'کالا / خدمات مرتبط',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('بدون انتخاب'),
                      ),
                      ...productNames.map(
                        (name) => DropdownMenuItem<String?>(
                          value: name,
                          child: Text(name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _productName = value),
                  ),
                ),
                ResponsiveFormField(
                  child: AutoInputDirection(
                    controller: _province,
                    child: TextFormField(
                      controller: _province,
                      decoration: const InputDecoration(
                        labelText: 'استان هدف',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                  ),
                ),
                ResponsiveFormField(
                  child: AutoInputDirection(
                    controller: _city,
                    child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(
                        labelText: 'شهر هدف',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
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
                      inputFormatters: const [persianRialFormatter],
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
