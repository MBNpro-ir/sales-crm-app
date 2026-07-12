import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

class OpportunitiesPage extends StatelessWidget {
  const OpportunitiesPage({super.key, required this.store});

  final CrmStore store;

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
      builder: (context) => _OpportunityEditor(store: store),
    );
    if (!context.mounted || saved != true) return;
    showCrmNotice(
      context,
      'فرصت فروش ثبت و در صف همگام‌سازی قرار گرفت.',
      type: CrmNoticeType.success,
    );
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
    final total = store.opportunities.fold<int>(
      0,
      (sum, opportunity) => sum + opportunity.amount,
    );
    return ListView(
      children: [
        CrmPageHeader(
          title: 'فرصت‌های فروش',
          subtitle:
              'فرصت‌ها را از تماس اولیه تا قرارداد در قیف فروش پیگیری کنید.',
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(context),
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
                value: store.openOpportunities.toString(),
                icon: Icons.track_changes_rounded,
                color: const Color(0xff8349d6),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'ارزش کل قیف',
                value: compactMoney(total),
                icon: Icons.account_tree_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'درآمد وزن‌دار',
                value: compactMoney(store.weightedPipeline),
                icon: Icons.auto_graph_rounded,
                color: const Color(0xff12966b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'قیف فروش',
          trailing: Text(
            'برای جابه‌جایی مرحله، فرصت را باز و ویرایش کنید.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: stages.map((stage) {
                final items = store.opportunities
                    .where((opportunity) => opportunity.stage == stage)
                    .toList();
                return _PipelineColumn(stage: stage, items: items);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'همه فرصت‌ها',
          child: store.opportunities.isEmpty
              ? const EmptyState(
                  icon: Icons.track_changes_outlined,
                  title: 'فرصتی ثبت نشده است',
                  message:
                      'با ثبت اولین فرصت، قیف فروش و نرخ تبدیل ساخته می‌شود.',
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('فرصت')),
                      DataColumn(label: Text('مشتری')),
                      DataColumn(label: Text('مرحله')),
                      DataColumn(label: Text('مبلغ')),
                      DataColumn(label: Text('احتمال')),
                      DataColumn(label: Text('تاریخ هدف')),
                    ],
                    rows: store.opportunities.map((opportunity) {
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 210,
                              child: Text(
                                opportunity.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(opportunity.customerName)),
                          DataCell(_StagePill(stage: opportunity.stage)),
                          DataCell(Text(compactMoney(opportunity.amount))),
                          DataCell(
                            Text(opportunity.probability.toString() + '%'),
                          ),
                          DataCell(
                            Text(
                              opportunity.expectedClose == null
                                  ? '—'
                                  : compactDate(opportunity.expectedClose!),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PipelineColumn extends StatelessWidget {
  const _PipelineColumn({required this.stage, required this.items});

  final String stage;
  final List<CrmOpportunity> items;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    return Container(
      width: 250,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stage,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              CircleAvatar(
                radius: 13,
                backgroundColor: color,
                child: Text(
                  items.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'موردی ندارد',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          for (final item in items)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.customerName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          compactMoney(item.amount),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        item.probability.toString() + '%',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        stage,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

Color _stageColor(String stage) {
  switch (stage) {
    case 'تماس اولیه':
      return const Color(0xff0b63ce);
    case 'نیازسنجی':
      return const Color(0xff26a7a4);
    case 'پیش‌فاکتور':
      return const Color(0xffe58a00);
    case 'مذاکره':
      return const Color(0xff8349d6);
    case 'برنده شده':
      return const Color(0xff12966b);
    case 'از دست رفته':
      return const Color(0xffd84b4b);
    default:
      return const Color(0xff52627a);
  }
}

class _OpportunityEditor extends StatefulWidget {
  const _OpportunityEditor({required this.store});

  final CrmStore store;

  @override
  State<_OpportunityEditor> createState() => _OpportunityEditorState();
}

class _OpportunityEditorState extends State<_OpportunityEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String? _customerId;
  String _stage = 'تماس اولیه';
  double _probability = 30;
  DateTime? _expectedClose;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(
        _expectedClose ?? DateTime.now().add(const Duration(days: 14)),
      ),
      firstDate: Jalali.fromDateTime(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
      lastDate: Jalali.fromDateTime(
        DateTime.now().add(const Duration(days: 730)),
      ),
    );
    if (date != null && mounted) {
      setState(() {
        _expectedClose = date.toDateTime();
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
    await widget.store.saveOpportunity(
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
    return AlertDialog(
      title: const Text('ثبت فرصت فروش'),
      content: SizedBox(
        width: 580,
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
                    decoration: const InputDecoration(labelText: 'مشتری *'),
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
                        value == null ? 'یک مشتری انتخاب کنید.' : null,
                    onChanged: (value) {
                      setState(() {
                        _customerId = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: AutoInputDirection(
                    controller: _title,
                    child: TextFormField(
                      controller: _title,
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
                SizedBox(
                  width: 278,
                  child: DropdownButtonFormField<String>(
                    initialValue: _stage,
                    decoration: const InputDecoration(labelText: 'مرحله فروش'),
                    items: const [
                      DropdownMenuItem(
                        value: 'تماس اولیه',
                        child: Text('تماس اولیه'),
                      ),
                      DropdownMenuItem(
                        value: 'نیازسنجی',
                        child: Text('نیازسنجی'),
                      ),
                      DropdownMenuItem(
                        value: 'پیش‌فاکتور',
                        child: Text('پیش‌فاکتور'),
                      ),
                      DropdownMenuItem(value: 'مذاکره', child: Text('مذاکره')),
                      DropdownMenuItem(
                        value: 'برنده شده',
                        child: Text('برنده شده'),
                      ),
                      DropdownMenuItem(
                        value: 'از دست رفته',
                        child: Text('از دست رفته'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _stage = value ?? _stage;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 278,
                  child: AutoInputDirection(
                    controller: _amount,
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مبلغ احتمالی (تومان)',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'مبلغ را وارد کنید.';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'احتمال موفقیت: ' +
                            _probability.round().toString() +
                            '%',
                      ),
                      Slider(
                        value: _probability,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: _probability.round().toString() + '%',
                        onChanged: (value) {
                          setState(() {
                            _probability = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _expectedClose == null
                          ? 'تعیین تاریخ هدف'
                          : 'تاریخ هدف: ' + compactDate(_expectedClose!),
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
          label: const Text('ذخیره فرصت'),
        ),
      ],
    );
  }
}
