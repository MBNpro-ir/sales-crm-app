import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _search = TextEditingController();
  int _sortColumn = 0;
  bool _sortAscending = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor([CrmProduct? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _ProductEditor(store: widget.store, product: product),
    );
    if (!mounted || saved != true) return;
    showCrmNotice(
      context,
      product == null ? 'محصول ثبت شد.' : 'محصول ویرایش شد.',
      type: CrmNoticeType.success,
    );
  }

  Future<void> _delete(CrmProduct product) async {
    if (!await confirmDelete(context, label: product.name)) return;
    await widget.store.deleteProduct(product);
    if (mounted) {
      showCrmNotice(
        context,
        'محصول حذف و همگام‌سازی شد.',
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
    final products = widget.store.products.where((item) {
      return needle.isEmpty ||
          item.name.toLowerCase().contains(needle) ||
          item.sku.toLowerCase().contains(needle) ||
          item.category.toLowerCase().contains(needle);
    }).toList();
    final values = <Comparable<Object?> Function(CrmProduct)>[
      (item) => item.name,
      (item) => item.sku,
      (item) => item.category,
      (item) => item.unitPrice,
      (item) => item.stock,
      (item) => item.isActive ? 1 : 0,
    ];
    products.sort((left, right) {
      final result = values[_sortColumn](
        left,
      ).compareTo(values[_sortColumn](right));
      return _sortAscending ? result : -result;
    });
    final lowStock = widget.store.products
        .where((product) => product.needsRestock)
        .toList();
    final inventoryValue = widget.store.products.fold<int>(
      0,
      (sum, product) => sum + product.stock * product.unitPrice,
    );
    return ListView(
      children: [
        CrmPageHeader(
          title: 'محصولات و موجودی',
          subtitle:
              'کالاها، قیمت پایه و حداقل موجودی را برای فروش و خرید نگه دارید.',
          actions: [
            FilledButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('محصول جدید'),
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
                title: 'محصولات فعال',
                value: widget.store.products
                    .where((product) => product.isActive)
                    .length
                    .toString(),
                icon: Icons.inventory_2_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'موجودی کم',
                value: lowStock.length.toString(),
                icon: Icons.inventory_outlined,
                color: const Color(0xffd84b4b),
              ),
            ),
            SizedBox(
              width: 320,
              child: KpiCard(
                title: 'ارزش تقریبی موجودی',
                value: compactMoney(inventoryValue),
                icon: Icons.warehouse_outlined,
                color: const Color(0xff12966b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (lowStock.isNotEmpty) ...[
          SectionCard(
            title: 'هشدار موجودی',
            child: Column(
              children: lowStock
                  .map(
                    (product) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xffd84b4b),
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        'موجودی ${formatPersianInteger(product.stock, grouping: true)} ${product.unit}، حداقل ${formatPersianInteger(product.minStock, grouping: true)}',
                      ),
                      trailing: Text(
                        'نیازمند تأمین',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
        ],
        SectionCard(
          title: 'جست‌وجوی کالا و خدمات',
          child: AutoInputDirection(
            controller: _search,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'نام، کد یا دسته‌بندی',
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'فهرست کالا و خدمات',
          trailing: Text('${formatPersianInteger(products.length)} مورد'),
          child: products.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'محصولی پیدا نشد',
                  message:
                      'محصول جدیدی ثبت کنید یا عبارت جست‌وجو را تغییر دهید.',
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
                        label: const Text('محصول'),
                        onSort: (_, _) => _sort(0),
                      ),
                      DataColumn(
                        label: const Text('کد'),
                        onSort: (_, _) => _sort(1),
                      ),
                      DataColumn(
                        label: const Text('دسته'),
                        onSort: (_, _) => _sort(2),
                      ),
                      const DataColumn(label: Text('واحد')),
                      DataColumn(
                        label: const Text('قیمت پایه (ریال)'),
                        numeric: true,
                        onSort: (_, _) => _sort(3),
                      ),
                      DataColumn(
                        label: const Text('موجودی'),
                        numeric: true,
                        onSort: (_, _) => _sort(4),
                      ),
                      DataColumn(
                        label: const Text('وضعیت'),
                        onSort: (_, _) => _sort(5),
                      ),
                      const DataColumn(label: Text('عملیات')),
                    ],
                    rows: products
                        .map(
                          (product) => DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 190,
                                  child: Text(
                                    product.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(product.sku)),
                              DataCell(Text(product.category)),
                              DataCell(Text(product.unit)),
                              DataCell(Text(compactMoney(product.unitPrice))),
                              DataCell(
                                Text(
                                  '${formatPersianInteger(product.stock, grouping: true)} / حداقل ${formatPersianInteger(product.minStock, grouping: true)}',
                                ),
                              ),
                              DataCell(
                                product.needsRestock
                                    ? const StatusPill(label: 'موجودی کم')
                                    : StatusPill(
                                        label: product.isActive
                                            ? 'فعال'
                                            : 'غیر فعال',
                                      ),
                              ),
                              DataCell(
                                RecordActions(
                                  onEdit: () => _openEditor(product),
                                  onDelete: () => _delete(product),
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

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.store, this.product});

  final CrmStore store;
  final CrmProduct? product;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _category = TextEditingController(text: 'عمومی');
  final _unit = TextEditingController(text: 'عدد');
  final _price = TextEditingController(text: '۰');
  final _stock = TextEditingController(text: '۰');
  final _minStock = TextEditingController(text: '۰');
  final _description = TextEditingController();
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) return;
    _name.text = product.name;
    _sku.text = product.sku;
    _category.text = product.category;
    _unit.text = product.unit;
    _price.text = formatPersianInteger(product.unitPrice, grouping: true);
    _stock.text = formatPersianInteger(product.stock, grouping: true);
    _minStock.text = formatPersianInteger(product.minStock, grouping: true);
    _description.text = product.description;
    _active = product.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _category.dispose();
    _unit.dispose();
    _price.dispose();
    _stock.dispose();
    _minStock.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.store.saveProduct(
      id: widget.product?.id,
      name: _name.text,
      sku: _sku.text,
      category: _category.text,
      unit: _unit.text,
      unitPrice: parsePersianInt(_price.text),
      stock: parsePersianInt(_stock.text),
      minStock: parsePersianInt(_minStock.text),
      description: _description.text,
      isActive: _active,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'ثبت محصول یا خدمت' : 'ویرایش محصول یا خدمت',
      ),
      content: CrmDialogContent(
        maxWidth: 700,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: ResponsiveFormGrid(
              children: [
                ResponsiveFormField(
                  child: _textField(_name, 'نام محصول *', required: true),
                ),
                ResponsiveFormField(child: _plainTextField(_sku, 'کد محصول')),
                ResponsiveFormField(child: _textField(_category, 'دسته‌بندی')),
                ResponsiveFormField(child: _textField(_unit, 'واحد')),
                ResponsiveFormField(
                  child: _numberField(
                    _price,
                    'قیمت پایه (ریال)',
                    required: true,
                  ),
                ),
                ResponsiveFormField(child: _numberField(_stock, 'موجودی فعلی')),
                ResponsiveFormField(
                  child: _numberField(_minStock, 'حداقل موجودی'),
                ),
                ResponsiveFormField.full(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                    title: const Text('محصول فعال است'),
                    secondary: const Icon(Icons.toggle_on_outlined),
                  ),
                ),
                ResponsiveFormField.full(
                  child: AutoInputDirection(
                    controller: _description,
                    child: TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'توضیحات',
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

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return AutoInputDirection(
      controller: controller,
      child: TextFormField(
        controller: controller,
        inputFormatters: [textOnlyFormatter],
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'این فیلد الزامی است.'
                  : null
            : null,
      ),
    );
  }

  Widget _plainTextField(TextEditingController controller, String label) {
    return AutoInputDirection(
      controller: controller,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return AutoInputDirection(
      controller: controller,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: const [persianNumberFormatter],
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'این فیلد الزامی است.'
                  : null
            : null,
      ),
    );
  }
}
