import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();
  int _sortColumn = 0;
  bool _sortAscending = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor([CrmCustomer? customer]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _CustomerEditorDialog(store: widget.store, customer: customer),
    );
    if (!mounted || saved != true) return;
    showCrmNotice(
      context,
      customer == null ? 'مشتری ثبت شد.' : 'اطلاعات مشتری ویرایش شد.',
      type: CrmNoticeType.success,
    );
  }

  Future<void> _delete(CrmCustomer customer) async {
    final label = customer.company.isEmpty ? customer.name : customer.company;
    if (!await confirmDelete(context, label: label)) return;
    await widget.store.deleteCustomer(customer);
    if (mounted) {
      showCrmNotice(
        context,
        'مشتری حذف و برای همگام‌سازی صف شد.',
        type: CrmNoticeType.warning,
      );
    }
  }

  void _sort(int column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
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
    final comparators = <Comparable<Object?> Function(CrmCustomer)>[
      (item) => item.company.isEmpty ? item.name : item.company,
      (item) => item.mobile,
      (item) => item.city,
      (item) => item.status,
      (item) => item.priority,
    ];
    rows.sort((left, right) {
      final result = comparators[_sortColumn](
        left,
      ).compareTo(comparators[_sortColumn](right));
      return _sortAscending ? result : -result;
    });
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
          child: AutoInputDirection(
            controller: _search,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'نام، شرکت، موبایل یا شهر را وارد کنید',
                prefixIcon: Icon(Icons.search_rounded),
              ),
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
            child: CrmTableScroll(
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                sortColumnIndex: _sortColumn,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('نام / شرکت'),
                    onSort: (_, _) => _sort(0),
                  ),
                  DataColumn(
                    label: const Text('موبایل'),
                    onSort: (_, _) => _sort(1),
                  ),
                  DataColumn(
                    label: const Text('شهر'),
                    onSort: (_, _) => _sort(2),
                  ),
                  const DataColumn(label: Text('نوع فعالیت')),
                  DataColumn(
                    label: const Text('وضعیت'),
                    onSort: (_, _) => _sort(3),
                  ),
                  DataColumn(
                    label: const Text('اولویت'),
                    onSort: (_, _) => _sort(4),
                  ),
                  const DataColumn(label: Text('عملیات')),
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
                      DataCell(
                        RecordActions(
                          onEdit: () => _openEditor(customer),
                          onDelete: () => _delete(customer),
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

class _CustomerEditorDialog extends StatefulWidget {
  const _CustomerEditorDialog({required this.store, this.customer});

  final CrmStore store;
  final CrmCustomer? customer;

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
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer == null) return;
    _name.text = customer.name;
    _company.text = customer.company;
    _mobile.text = customer.mobile;
    _phone.text = customer.phone;
    _province.text = customer.province;
    _city.text = customer.city;
    _activity = customer.activityType;
    _status = customer.status;
    _priority = customer.priority;
    _notes.text = customer.notes;
    final details = customer.details;
    _email.text = details['email'] ?? '';
    _secondaryMobile.text = details['secondary_mobile'] ?? '';
    _nationalId.text = details['national_id'] ?? '';
    _district.text = details['district'] ?? '';
    _address.text = details['address'] ?? '';
    _postalCode.text = details['postal_code'] ?? '';
    _source.text = details['source'] ?? '';
    _interestedProducts.text = details['interested_products'] ?? '';
    _monthlyVolume.text = details['monthly_volume'] ?? '';
    _paymentTerms.text = details['payment_terms'] ?? '';
    _fax.text = details['fax'] ?? '';
    _website.text = details['website'] ?? '';
  }

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
      id: widget.customer?.id,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'ثبت مشتری جدید' : 'ویرایش مشتری'),
      content: CrmDialogContent(
        maxWidth: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: ResponsiveFormGrid(
              children: [
                _input(
                  _name,
                  TextFormField(
                    controller: _name,
                    inputFormatters: [textOnlyFormatter],
                    decoration: const InputDecoration(
                      labelText: 'نام مخاطب *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'نام مخاطب الزامی است.'
                        : null,
                  ),
                ),
                _input(
                  _company,
                  TextFormField(
                    controller: _company,
                    inputFormatters: [textOnlyFormatter],
                    decoration: const InputDecoration(
                      labelText: 'نام شرکت',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                ),
                _input(
                  _mobile,
                  TextFormField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'شماره موبایل *',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'شماره موبایل الزامی است.'
                        : null,
                  ),
                ),
                _input(
                  _phone,
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'تلفن ثابت',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                _input(
                  _email,
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'ایمیل',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ),
                _input(
                  _secondaryMobile,
                  TextFormField(
                    controller: _secondaryMobile,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'تلفن همراه دوم',
                      prefixIcon: Icon(Icons.phone_iphone_outlined),
                    ),
                  ),
                ),
                _input(
                  _nationalId,
                  TextFormField(
                    controller: _nationalId,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'کد ملی / شناسه ملی',
                    ),
                  ),
                ),
                _input(
                  _province,
                  TextFormField(
                    controller: _province,
                    decoration: const InputDecoration(labelText: 'استان'),
                  ),
                ),
                _input(
                  _city,
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
                ResponsiveFormField.full(
                  child: Text(
                    'اطلاعات کسب‌وکار و آدرس',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _input(
                  _source,
                  TextFormField(
                    controller: _source,
                    decoration: const InputDecoration(labelText: 'منبع آشنایی'),
                  ),
                ),
                _input(
                  _interestedProducts,
                  TextFormField(
                    controller: _interestedProducts,
                    decoration: const InputDecoration(
                      labelText: 'کالاها / خدمات مورد علاقه',
                    ),
                  ),
                ),
                _input(
                  _monthlyVolume,
                  TextFormField(
                    controller: _monthlyVolume,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'حدود تناژ / حجم ماهانه',
                    ),
                  ),
                ),
                _input(
                  _paymentTerms,
                  TextFormField(
                    controller: _paymentTerms,
                    decoration: const InputDecoration(
                      labelText: 'شرایط پرداخت',
                    ),
                  ),
                ),
                _input(
                  _district,
                  TextFormField(
                    controller: _district,
                    decoration: const InputDecoration(
                      labelText: 'منطقه / خیابان',
                    ),
                  ),
                ),
                _input(
                  _postalCode,
                  TextFormField(
                    controller: _postalCode,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(labelText: 'کد پستی'),
                  ),
                ),
                ResponsiveFormField.full(
                  child: AutoInputDirection(
                    controller: _address,
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
                ),
                _input(
                  _fax,
                  TextFormField(
                    controller: _fax,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(labelText: 'فکس'),
                  ),
                ),
                _input(
                  _website,
                  TextFormField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'وب‌سایت'),
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

  Widget _wideField(Widget child) => child;

  Widget _input(TextEditingController controller, Widget child) {
    return _wideField(AutoInputDirection(controller: controller, child: child));
  }
}
