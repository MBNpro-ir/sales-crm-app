import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../widgets/common.dart';

class CallsPage extends StatelessWidget {
  const CallsPage({super.key, required this.store});

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
      builder: (context) => _CallEditorDialog(store: store),
    );
    if (!context.mounted || saved != true) return;
    showCrmNotice(
      context,
      'تماس ثبت و برای همگام‌سازی صف شد.',
      type: CrmNoticeType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final successful = store.successfulCalls;
    final failed = store.calls.where((call) => call.status == 'ناموفق').length;
    return ListView(
      children: [
        CrmPageHeader(
          title: 'مدیریت تماس‌ها',
          subtitle: 'تماس‌ها، نتیجه، مبلغ احتمالی و پیگیری بعدی را ثبت کنید.',
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add_call),
              label: const Text('ثبت تماس جدید'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'کل تماس‌ها',
                value: store.calls.length.toString(),
                icon: Icons.phone_in_talk_rounded,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'تماس موفق',
                value: successful.toString(),
                icon: Icons.phone_enabled_rounded,
                color: const Color(0xff12966b),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'نیازمند پیگیری',
                value: store.followUpCalls.toString(),
                icon: Icons.autorenew_rounded,
                color: const Color(0xffe58a00),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'تماس ناموفق',
                value: failed.toString(),
                icon: Icons.phone_missed_rounded,
                color: const Color(0xffd84b4b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'فهرست تماس‌ها',
          trailing: Text(
            'آخرین به‌روزرسانی محلی',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          padding: const EdgeInsets.all(12),
          child: store.calls.isEmpty
              ? const EmptyState(
                  icon: Icons.phone_outlined,
                  title: 'تماسی ثبت نشده است',
                  message: 'با ثبت اولین تماس، گزارش و پیگیری‌ها ساخته می‌شود.',
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('مشتری')),
                      DataColumn(label: Text('موضوع تماس')),
                      DataColumn(label: Text('نوع')),
                      DataColumn(label: Text('نتیجه')),
                      DataColumn(label: Text('خرید / فروش')),
                      DataColumn(label: Text('کالا')),
                      DataColumn(label: Text('تعداد / تناژ')),
                      DataColumn(label: Text('تاریخ')),
                      DataColumn(label: Text('مدت')),
                      DataColumn(label: Text('مبلغ احتمالی')),
                    ],
                    rows: store.calls.map((call) {
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 175,
                              child: Text(
                                call.customerName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                call.subject,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(call.type)),
                          DataCell(StatusPill(label: call.status)),
                          DataCell(
                            Text(call.tradeType.isEmpty ? '—' : call.tradeType),
                          ),
                          DataCell(
                            SizedBox(
                              width: 130,
                              child: Text(
                                call.productName.isEmpty
                                    ? '—'
                                    : call.productName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              call.quantity == 0
                                  ? '—'
                                  : call.quantity.toString(),
                            ),
                          ),
                          DataCell(Text(compactDate(call.callAt))),
                          DataCell(
                            Text(call.durationMinutes.toString() + ' دقیقه'),
                          ),
                          DataCell(Text(compactMoney(call.amount))),
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

class _CallEditorDialog extends StatefulWidget {
  const _CallEditorDialog({required this.store});

  final CrmStore store;

  @override
  State<_CallEditorDialog> createState() => _CallEditorDialogState();
}

class _CallEditorDialogState extends State<_CallEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _notes = TextEditingController();
  final _duration = TextEditingController(text: '5');
  final _amount = TextEditingController(text: '0');
  final _product = TextEditingController();
  final _quantity = TextEditingController(text: '0');
  final _unitPrice = TextEditingController(text: '0');
  String? _customerId;
  String _type = 'تلفنی';
  String _direction = 'خروجی';
  String _status = 'موفق';
  String _tradeType = 'فروش';
  bool _addFollowUp = true;
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _notes.dispose();
    _duration.dispose();
    _amount.dispose();
    _product.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final customer = widget.store.customers.firstWhere(
      (item) => item.id == _customerId,
    );
    setState(() {
      _saving = true;
    });
    await widget.store.saveCall(
      customer: customer,
      subject: _subject.text,
      type: _type,
      direction: _direction,
      status: _status,
      notes: _notes.text,
      durationMinutes: parsePersianInt(_duration.text),
      amount: parsePersianInt(_amount.text),
      tradeType: _tradeType,
      productName: _product.text,
      quantity: parsePersianInt(_quantity.text),
      unitPrice: parsePersianInt(_unitPrice.text),
      nextFollowUp: _addFollowUp
          ? DateTime.now().add(const Duration(days: 1))
          : null,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ثبت و پیگیری تماس'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'مشتری *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
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
                        value == null ? 'یک مشتری را انتخاب کنید.' : null,
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
                    controller: _subject,
                    child: TextFormField(
                      controller: _subject,
                      decoration: const InputDecoration(
                        labelText: 'موضوع تماس *',
                        prefixIcon: Icon(Icons.subject_rounded),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'موضوع تماس الزامی است.'
                          : null,
                    ),
                  ),
                ),
                _half(
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'نوع تماس'),
                    items: const [
                      DropdownMenuItem(value: 'تلفنی', child: Text('تلفنی')),
                      DropdownMenuItem(value: 'جلسه', child: Text('جلسه')),
                      DropdownMenuItem(
                        value: 'استعلام',
                        child: Text('استعلام'),
                      ),
                      DropdownMenuItem(value: 'پیام', child: Text('پیام')),
                      DropdownMenuItem(value: 'ایمیل', child: Text('ایمیل')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _type = value ?? _type;
                      });
                    },
                  ),
                ),
                _half(
                  DropdownButtonFormField<String>(
                    initialValue: _direction,
                    decoration: const InputDecoration(labelText: 'جهت تماس'),
                    items: const [
                      DropdownMenuItem(value: 'خروجی', child: Text('خروجی')),
                      DropdownMenuItem(value: 'ورودی', child: Text('ورودی')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _direction = value ?? _direction;
                      });
                    },
                  ),
                ),
                _half(
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'نتیجه تماس'),
                    items: const [
                      DropdownMenuItem(value: 'موفق', child: Text('موفق')),
                      DropdownMenuItem(value: 'پیگیری', child: Text('پیگیری')),
                      DropdownMenuItem(value: 'ناموفق', child: Text('ناموفق')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _status = value ?? _status;
                      });
                    },
                  ),
                ),
                _input(
                  _duration,
                  TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'مدت (دقیقه)'),
                  ),
                ),
                _input(
                  _amount,
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مبلغ احتمالی (تومان)',
                    ),
                  ),
                ),
                _half(
                  DropdownButtonFormField<String>(
                    initialValue: _tradeType,
                    decoration: const InputDecoration(labelText: 'نوع معامله'),
                    items: const [
                      DropdownMenuItem(value: 'فروش', child: Text('فروش')),
                      DropdownMenuItem(value: 'خرید', child: Text('خرید')),
                      DropdownMenuItem(
                        value: 'بدون معامله',
                        child: Text('بدون معامله'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _tradeType = value ?? _tradeType;
                      });
                    },
                  ),
                ),
                _input(
                  _product,
                  TextFormField(
                    controller: _product,
                    decoration: const InputDecoration(labelText: 'کالا / خدمت'),
                  ),
                ),
                _input(
                  _quantity,
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'تعداد یا تناژ',
                    ),
                  ),
                ),
                _input(
                  _unitPrice,
                  TextFormField(
                    controller: _unitPrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'فی (تومان)'),
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
                        labelText: 'شرح تماس و اقدام بعدی',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _addFollowUp,
                    title: const Text('ایجاد پیگیری برای فردا'),
                    subtitle: const Text(
                      'در نسخه بعد امکان تعیین تاریخ شمسی نیز فعال می‌شود.',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _addFollowUp = value;
                      });
                    },
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
          label: const Text('ثبت تماس'),
        ),
      ],
    );
  }

  Widget _half(Widget child) {
    return SizedBox(width: 270, child: child);
  }

  Widget _input(TextEditingController controller, Widget child) {
    return _half(AutoInputDirection(controller: controller, child: child));
  }
}
