import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../widgets/common.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CustomerEditorDialog(store: widget.store),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('مشتری در داده‌های محلی ثبت شد.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needle = _search.text.trim().toLowerCase();
    final rows = widget.store.customers.where((customer) {
      if (needle.isEmpty) return true;
      return customer.name.toLowerCase().contains(needle) ||
          customer.company.toLowerCase().contains(needle) ||
          customer.mobile.contains(needle) ||
          customer.city.toLowerCase().contains(needle);
    }).toList();
    return ListView(
      children: [
        CrmPageHeader(
          title: 'دفترچه مشتریان',
          subtitle:
              'اطلاعات مشتری، وضعیت ارتباط و اولویت فروش را یکجا نگه دارید.',
          actions: [
            FilledButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('مشتری جدید'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SectionCard(
          title: 'جست‌وجو و فیلتر',
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'نام، شرکت، موبایل یا شهر را وارد کنید',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          const SectionCard(
            title: 'مشتریان',
            child: EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'موردی پیدا نشد',
              message: 'عبارت جست‌وجو را تغییر دهید یا مشتری جدیدی اضافه کنید.',
            ),
          )
        else
          SectionCard(
            title: 'فهرست مشتریان',
            trailing: Text(
              rows.length.toString() + ' مشتری',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                columns: const [
                  DataColumn(label: Text('نام / شرکت')),
                  DataColumn(label: Text('موبایل')),
                  DataColumn(label: Text('شهر')),
                  DataColumn(label: Text('نوع فعالیت')),
                  DataColumn(label: Text('وضعیت')),
                  DataColumn(label: Text('اولویت')),
                ],
                rows: rows.map((customer) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 210,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.company.isEmpty
                                    ? customer.name
                                    : customer.company,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (customer.company.isNotEmpty)
                                Text(
                                  customer.name,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text(customer.mobile)),
                      DataCell(Text(customer.city)),
                      DataCell(Text(customer.activityType)),
                      DataCell(StatusPill(label: customer.status)),
                      DataCell(Text(customer.priority)),
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

class _CustomerEditorDialog extends StatefulWidget {
  const _CustomerEditorDialog({required this.store});

  final CrmStore store;

  @override
  State<_CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<_CustomerEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _mobile = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _secondaryMobile = TextEditingController();
  final _nationalId = TextEditingController();
  final _province = TextEditingController(text: 'تهران');
  final _city = TextEditingController(text: 'تهران');
  final _district = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _source = TextEditingController();
  final _interestedProducts = TextEditingController();
  final _monthlyVolume = TextEditingController();
  final _paymentTerms = TextEditingController();
  final _fax = TextEditingController();
  final _website = TextEditingController();
  final _notes = TextEditingController();
  String _activity = 'تولیدکننده';
  String _status = 'فعال';
  String _priority = 'متوسط';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _mobile.dispose();
    _phone.dispose();
    _email.dispose();
    _secondaryMobile.dispose();
    _nationalId.dispose();
    _province.dispose();
    _city.dispose();
    _district.dispose();
    _address.dispose();
    _postalCode.dispose();
    _source.dispose();
    _interestedProducts.dispose();
    _monthlyVolume.dispose();
    _paymentTerms.dispose();
    _fax.dispose();
    _website.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
    });
    await widget.store.saveCustomer(
      name: _name.text,
      company: _company.text,
      mobile: _mobile.text,
      phone: _phone.text,
      province: _province.text,
      city: _city.text,
      activityType: _activity,
      status: _status,
      priority: _priority,
      notes: _notes.text,
      details: {
        'email': _email.text.trim(),
        'secondary_mobile': _secondaryMobile.text.trim(),
        'national_id': _nationalId.text.trim(),
        'district': _district.text.trim(),
        'address': _address.text.trim(),
        'postal_code': _postalCode.text.trim(),
        'source': _source.text.trim(),
        'interested_products': _interestedProducts.text.trim(),
        'monthly_volume': _monthlyVolume.text.trim(),
        'payment_terms': _paymentTerms.text.trim(),
        'fax': _fax.text.trim(),
        'website': _website.text.trim(),
      },
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ثبت مشتری جدید'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _wideField(
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'نام مخاطب *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'نام مخاطب الزامی است.'
                        : null,
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _company,
                    decoration: const InputDecoration(
                      labelText: 'نام شرکت',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'شماره موبایل *',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'شماره موبایل الزامی است.'
                        : null,
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'تلفن ثابت',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'ایمیل',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _secondaryMobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'تلفن همراه دوم',
                      prefixIcon: Icon(Icons.phone_iphone_outlined),
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _nationalId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'کد ملی / شناسه ملی',
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _province,
                    decoration: const InputDecoration(labelText: 'استان'),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'شهر'),
                  ),
                ),
                _wideField(
                  DropdownButtonFormField<String>(
                    initialValue: _activity,
                    decoration: const InputDecoration(labelText: 'نوع فعالیت'),
                    items: const [
                      DropdownMenuItem(
                        value: 'تولیدکننده',
                        child: Text('تولیدکننده'),
                      ),
                      DropdownMenuItem(
                        value: 'بازرگان',
                        child: Text('بازرگان'),
                      ),
                      DropdownMenuItem(
                        value: 'بازیافت',
                        child: Text('بازیافت'),
                      ),
                      DropdownMenuItem(
                        value: 'فروشنده',
                        child: Text('فروشنده'),
                      ),
                      DropdownMenuItem(value: 'سایر', child: Text('سایر')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _activity = value ?? _activity;
                      });
                    },
                  ),
                ),
                _wideField(
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'وضعیت مشتری'),
                    items: const [
                      DropdownMenuItem(value: 'فعال', child: Text('فعال')),
                      DropdownMenuItem(
                        value: 'مشتری بالقوه',
                        child: Text('مشتری بالقوه'),
                      ),
                      DropdownMenuItem(
                        value: 'غیر فعال',
                        child: Text('غیر فعال'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _status = value ?? _status;
                      });
                    },
                  ),
                ),
                _wideField(
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'اولویت'),
                    items: const [
                      DropdownMenuItem(
                        value: 'خیلی بالا',
                        child: Text('خیلی بالا'),
                      ),
                      DropdownMenuItem(value: 'بالا', child: Text('بالا')),
                      DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),
                      DropdownMenuItem(value: 'پایین', child: Text('پایین')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _priority = value ?? _priority;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'اطلاعات کسب‌وکار و آدرس',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _source,
                    decoration: const InputDecoration(labelText: 'منبع آشنایی'),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _interestedProducts,
                    decoration: const InputDecoration(
                      labelText: 'کالاها / خدمات مورد علاقه',
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _monthlyVolume,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'حدود تناژ / حجم ماهانه',
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _paymentTerms,
                    decoration: const InputDecoration(
                      labelText: 'شرایط پرداخت',
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _district,
                    decoration: const InputDecoration(
                      labelText: 'منطقه / خیابان',
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _postalCode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'کد پستی'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _address,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'آدرس کامل',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _fax,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'فکس'),
                  ),
                ),
                _wideField(
                  TextFormField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'وب‌سایت'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
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
          label: const Text('ذخیره'),
        ),
      ],
    );
  }

  Widget _wideField(Widget child) {
    return SizedBox(width: 294, child: child);
  }
}
