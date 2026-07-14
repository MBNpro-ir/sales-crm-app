import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();
  final _codeFilter = TextEditingController();
  final _nameFilter = TextEditingController();
  final _mobileFilter = TextEditingController();
  final _cityFilter = TextEditingController();
  int _sortColumn = 0;
  bool _sortAscending = true;
  String? _activityFilter;
  String? _statusFilter;
  String? _priorityFilter;
  String? _provinceFilter;
  String _groupBy = 'نوع فعالیت';
  bool _vipOnly = false;

  @override
  void dispose() {
    _search.dispose();
    _codeFilter.dispose();
    _nameFilter.dispose();
    _mobileFilter.dispose();
    _cityFilter.dispose();
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

  List<CrmCustomer> _filteredCustomers() {
    final needle = _search.text.trim().toLowerCase();
    return widget.store.customers.where((customer) {
      final matchesSearch =
          needle.isEmpty ||
          customer.name.toLowerCase().contains(needle) ||
          customer.company.toLowerCase().contains(needle) ||
          customer.mobile.contains(needle) ||
          customer.city.toLowerCase().contains(needle);
      return matchesSearch &&
          (_codeFilter.text.trim().isEmpty ||
              customer.customerCode.contains(_codeFilter.text.trim())) &&
          (_nameFilter.text.trim().isEmpty ||
              customer.displayName.toLowerCase().contains(
                _nameFilter.text.trim().toLowerCase(),
              )) &&
          (_mobileFilter.text.trim().isEmpty ||
              customer.mobile.contains(_mobileFilter.text.trim())) &&
          (_cityFilter.text.trim().isEmpty ||
              customer.city.toLowerCase().contains(
                _cityFilter.text.trim().toLowerCase(),
              )) &&
          (_activityFilter == null ||
              customer.activityType == _activityFilter) &&
          (_statusFilter == null || customer.status == _statusFilter) &&
          (_priorityFilter == null || customer.priority == _priorityFilter) &&
          (_provinceFilter == null || customer.province == _provinceFilter) &&
          (!_vipOnly || customer.isVip);
    }).toList();
  }

  List<List<Object?>> _rowsForExport(List<CrmCustomer> customers) => customers
      .map(
        (item) => <Object?>[
          item.customerCode,
          item.name,
          item.company,
          item.mobile,
          item.phone,
          item.province,
          item.city,
          item.activityType,
          item.status,
          item.priority,
          item.isVip ? 'بله' : 'خیر',
          item.details['email'] ?? '',
          item.details['address'] ?? '',
          item.tags.join(', '),
          item.notes,
        ],
      )
      .toList();

  static const _exportHeaders = [
    'کد مشتری',
    'نام مخاطب',
    'نام شرکت',
    'موبایل',
    'تلفن',
    'استان',
    'شهر',
    'نوع فعالیت',
    'وضعیت',
    'اولویت',
    'VIP',
    'ایمیل',
    'آدرس',
    'برچسب‌ها',
    'یادداشت',
  ];

  Future<void> _exportExcel() async {
    final rows = _filteredCustomers();
    final path = await CrmReportService.exportExcel(
      suggestedName: 'customers.xlsx',
      sheetName: 'مشتریان',
      headers: _exportHeaders,
      rows: _rowsForExport(rows),
    );
    if (mounted && path != null) {
      showCrmNotice(
        context,
        'خروجی اکسل مشتریان ذخیره شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _importExcel() async {
    final table = await CrmReportService.pickExcelRows();
    if (table == null || table.isEmpty) return;
    const aliases = <String, String>{
      'کد مشتری': 'customer_code',
      'نام مخاطب': 'name',
      'نام': 'name',
      'نام شرکت': 'company',
      'شرکت': 'company',
      'موبایل': 'mobile',
      'تلفن': 'phone',
      'استان': 'province',
      'شهر': 'city',
      'نوع فعالیت': 'activity_type',
      'وضعیت': 'status',
      'اولویت': 'priority',
      'VIP': 'is_vip',
      'وی آی پی': 'is_vip',
      'ایمیل': 'email',
      'آدرس': 'address',
      'برچسب‌ها': 'tags',
      'یادداشت': 'notes',
    };
    final headers = table.first.map((item) => aliases[item] ?? '').toList();
    final records = <Map<String, String>>[];
    for (final row in table.skip(1)) {
      final record = <String, String>{};
      for (var index = 0; index < headers.length; index++) {
        if (headers[index].isNotEmpty && index < row.length) {
          record[headers[index]] = row[index];
        }
      }
      records.add(record);
    }
    final count = await widget.store.importCustomerRows(records);
    if (mounted) {
      showCrmNotice(
        context,
        '${formatPersianInteger(count)} مشتری از اکسل ثبت یا به‌روزرسانی شد.',
        type: count == 0 ? CrmNoticeType.warning : CrmNoticeType.success,
      );
    }
  }

  Future<void> _printPhonebook() => CrmReportService.printTable(
    title: 'دفترچه تلفن مشتریان',
    headers: const [
      'کد',
      'نام / شرکت',
      'موبایل',
      'تلفن',
      'استان',
      'شهر',
      'فعالیت',
    ],
    rows: _filteredCustomers()
        .map(
          (item) => <Object?>[
            item.customerCode,
            item.displayName,
            item.mobile,
            item.phone,
            item.province,
            item.city,
            item.activityType,
          ],
        )
        .toList(),
  );

  Future<void> _copyPhonebook() async {
    await CrmReportService.copyTable(
      headers: const ['نام / شرکت', 'موبایل', 'تلفن'],
      rows: _filteredCustomers()
          .map((item) => <Object?>[item.displayName, item.mobile, item.phone])
          .toList(),
    );
    if (mounted) showCrmNotice(context, 'دفترچه تلفن در کلیپ‌بورد کپی شد.');
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredCustomers();
    final comparators = <Comparable<Object?> Function(CrmCustomer)>[
      (item) => item.customerCode,
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
            OutlinedButton.icon(
              onPressed: _importExcel,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('ورودی اکسل'),
            ),
            PopupMenuButton<String>(
              tooltip: 'خروجی و چاپ',
              onSelected: (value) {
                if (value == 'excel') _exportExcel();
                if (value == 'print') _printPhonebook();
                if (value == 'copy') _copyPhonebook();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'excel', child: Text('خروجی Excel')),
                PopupMenuItem(value: 'print', child: Text('چاپ دفترچه تلفن')),
                PopupMenuItem(value: 'copy', child: Text('کپی دفترچه تلفن')),
              ],
              child: IgnorePointer(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('خروجی'),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('مشتری جدید'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SectionCard(
          title: 'فیلتر هر ستون و دسته‌بندی',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _filterText(_search, 'جست‌وجوی سراسری', Icons.search_rounded),
              _filterText(_codeFilter, 'کد مشتری', Icons.numbers_rounded),
              _filterText(_nameFilter, 'نام / شرکت', Icons.person_outline),
              _filterText(_mobileFilter, 'موبایل', Icons.phone_android),
              _filterText(_cityFilter, 'شهر', Icons.location_city_outlined),
              _filterDropdown(
                'نوع فعالیت',
                _activityFilter,
                widget.store.activityTypes,
                (value) => setState(() => _activityFilter = value),
              ),
              _filterDropdown(
                'وضعیت',
                _statusFilter,
                widget.store.customerStatuses,
                (value) => setState(() => _statusFilter = value),
              ),
              _filterDropdown(
                'اولویت',
                _priorityFilter,
                const ['خیلی بالا', 'بالا', 'متوسط', 'پایین'],
                (value) => setState(() => _priorityFilter = value),
              ),
              _filterDropdown(
                'استان',
                _provinceFilter,
                widget.store.customers
                    .map((item) => item.province)
                    .where((item) => item.isNotEmpty)
                    .toSet()
                    .toList(),
                (value) => setState(() => _provinceFilter = value),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _groupBy,
                  decoration: const InputDecoration(
                    labelText: 'دسته‌بندی بر اساس',
                  ),
                  items: const ['نوع فعالیت', 'اولویت', 'استان', 'وضعیت']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _groupBy = value ?? _groupBy),
                ),
              ),
              FilterChip(
                selected: _vipOnly,
                label: const Text('فقط مشتریان VIP'),
                avatar: const Icon(Icons.workspace_premium_outlined),
                onSelected: (value) => setState(() => _vipOnly = value),
              ),
            ],
          ),
        ),
        if (rows.any((item) => item.isVip)) ...[
          const SizedBox(height: 18),
          SectionCard(
            title: 'مشتریان VIP',
            trailing: Text(
              '${formatPersianInteger(rows.where((item) => item.isVip).length)} مشتری',
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rows
                  .where((item) => item.isVip)
                  .map(
                    (item) => ActionChip(
                      avatar: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 18,
                      ),
                      label: Text(item.displayName),
                      onPressed: () => _openEditor(item),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _groupSummary(rows),
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
                    label: const Text('کد مشتری'),
                    onSort: (_, _) => _sort(0),
                  ),
                  DataColumn(
                    label: const Text('نام / شرکت'),
                    onSort: (_, _) => _sort(1),
                  ),
                  DataColumn(
                    label: const Text('موبایل'),
                    onSort: (_, _) => _sort(2),
                  ),
                  DataColumn(
                    label: const Text('شهر'),
                    onSort: (_, _) => _sort(3),
                  ),
                  const DataColumn(label: Text('نوع فعالیت')),
                  DataColumn(
                    label: const Text('وضعیت'),
                    onSort: (_, _) => _sort(4),
                  ),
                  DataColumn(
                    label: const Text('اولویت'),
                    onSort: (_, _) => _sort(5),
                  ),
                  const DataColumn(label: Text('VIP')),
                  const DataColumn(label: Text('عملیات')),
                ],
                rows: rows.map((customer) {
                  return DataRow(
                    cells: [
                      DataCell(Text(customer.customerCode)),
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
                        Icon(
                          customer.isVip
                              ? Icons.workspace_premium_rounded
                              : Icons.remove,
                          color: customer.isVip
                              ? const Color(0xffe58a00)
                              : null,
                        ),
                      ),
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

  Widget _filterText(
    TextEditingController controller,
    String label,
    IconData icon,
  ) => SizedBox(
    width: 190,
    child: TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );

  Widget _filterDropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('همه')),
        ...values.toSet().map(
          (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
        ),
      ],
      onChanged: changed,
    ),
  );

  Widget _groupSummary(List<CrmCustomer> rows) {
    final groups = <String, int>{};
    for (final item in rows) {
      final rawKey = switch (_groupBy) {
        'اولویت' => item.priority,
        'استان' => item.province,
        'وضعیت' => item.status,
        _ => item.activityType,
      };
      final key = rawKey.isEmpty ? 'نامشخص' : rawKey;
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return SectionCard(
      title: 'خلاصه دسته‌بندی بر اساس $_groupBy',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: groups.entries
            .map(
              (entry) => Chip(
                label: Text(
                  '${entry.key}: ${formatPersianInteger(entry.value)}',
                ),
              ),
            )
            .toList(),
      ),
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
  final _customerCode = TextEditingController();
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
  final _tags = TextEditingController();
  String _activity = 'تولیدکننده';
  String _status = 'فعال';
  String _priority = 'متوسط';
  bool _isVip = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer == null) {
      _customerCode.text = widget.store.nextCustomerCode();
      return;
    }
    _customerCode.text = customer.customerCode.isEmpty
        ? widget.store.nextCustomerCode()
        : customer.customerCode;
    _name.text = customer.name;
    _company.text = customer.company;
    _mobile.text = formatPersianDigitsOnly(customer.mobile);
    _phone.text = formatPersianDigitsOnly(customer.phone);
    _province.text = customer.province;
    _city.text = customer.city;
    _activity = customer.activityType;
    _status = customer.status;
    _priority = customer.priority;
    _notes.text = customer.notes;
    _tags.text = customer.tags.join('، ');
    _isVip = customer.isVip;
    final details = customer.details;
    _email.text = details['email'] ?? '';
    _secondaryMobile.text = formatPersianDigitsOnly(
      details['secondary_mobile'] ?? '',
    );
    _nationalId.text = formatPersianDigitsOnly(details['national_id'] ?? '');
    _district.text = details['district'] ?? '';
    _address.text = details['address'] ?? '';
    _postalCode.text = formatPersianDigitsOnly(details['postal_code'] ?? '');
    _source.text = details['source'] ?? '';
    _interestedProducts.text = details['interested_products'] ?? '';
    _monthlyVolume.text = formatPersianDigitsOnly(
      details['monthly_volume'] ?? '',
    );
    _paymentTerms.text = details['payment_terms'] ?? '';
    _fax.text = formatPersianDigitsOnly(details['fax'] ?? '');
    _website.text = details['website'] ?? '';
  }

  @override
  void dispose() {
    _customerCode.dispose();
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
    _tags.dispose();
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
      mobile: formatPersianDigitsOnly(_mobile.text),
      phone: formatPersianDigitsOnly(_phone.text),
      province: _province.text,
      city: _city.text,
      activityType: _activity,
      status: _status,
      priority: _priority,
      notes: _notes.text,
      tags: _tags.text
          .split(RegExp(r'[,،]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      details: {
        ...?widget.customer?.details,
        'customer_code': _customerCode.text.trim(),
        'is_vip': _isVip ? 'true' : 'false',
        'email': _email.text.trim(),
        'secondary_mobile': formatPersianDigitsOnly(_secondaryMobile.text),
        'national_id': formatPersianDigitsOnly(_nationalId.text),
        'district': _district.text.trim(),
        'address': _address.text.trim(),
        'postal_code': formatPersianDigitsOnly(_postalCode.text),
        'source': _source.text.trim(),
        'interested_products': _interestedProducts.text.trim(),
        'monthly_volume': formatPersianDigitsOnly(_monthlyVolume.text),
        'payment_terms': _paymentTerms.text.trim(),
        'fax': formatPersianDigitsOnly(_fax.text),
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
                  _customerCode,
                  TextFormField(
                    controller: _customerCode,
                    decoration: const InputDecoration(
                      labelText: 'کد مشتری *',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      if (code.isEmpty) return 'کد مشتری الزامی است.';
                      final duplicate = widget.store.customers.any(
                        (item) =>
                            item.id != widget.customer?.id &&
                            item.customerCode.toLowerCase() ==
                                code.toLowerCase(),
                      );
                      return duplicate
                          ? 'این کد مشتری قبلاً ثبت شده است.'
                          : null;
                    },
                  ),
                ),
                ResponsiveFormField(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isVip,
                    title: const Text('مشتری VIP'),
                    subtitle: const Text(
                      'نمایش در فهرست ویژه و پیگیری‌های اولویت‌دار',
                    ),
                    onChanged: (value) => setState(() => _isVip = value),
                  ),
                ),
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
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'نوع فعالیت',
                      suffixIcon: IconButton(
                        tooltip: 'افزودن نوع فعالیت',
                        onPressed: () => _addOption(activity: true),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                    items: {...widget.store.activityTypes, _activity}
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
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
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'وضعیت مشتری',
                      suffixIcon: IconButton(
                        tooltip: 'افزودن وضعیت مشتری',
                        onPressed: () => _addOption(activity: false),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                    items: {...widget.store.customerStatuses, _status}
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
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
                  child: AutoInputDirection(
                    controller: _tags,
                    child: TextFormField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: 'برچسب‌ها / دسته‌های مشتری',
                        hintText: 'مثلاً عمده‌فروش، تهران، پیگیری ویژه',
                      ),
                    ),
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

  Future<void> _addOption({required bool activity}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activity ? 'نوع فعالیت جدید' : 'وضعیت مشتری جدید'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'عنوان'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    if (activity) {
      await widget.store.addActivityType(value);
      setState(() => _activity = value.trim());
    } else {
      await widget.store.addCustomerStatus(value);
      setState(() => _status = value.trim());
    }
  }

  Widget _input(TextEditingController controller, Widget child) {
    return _wideField(AutoInputDirection(controller: controller, child: child));
  }
}
