import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _search = TextEditingController();

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

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ایجاد گروه کالای جدید'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'نام گروه کالا'),
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
    await widget.store.addProductCategory(value);
  }

  Future<void> _printReport() => CrmReportService.printTable(
    context: context,
    title: 'گزارش کالا و موجودی بر اساس گروه',
    headers: const [
      'گروه',
      'کد',
      'نام محصول',
      'واحد',
      'قیمت پایه',
      'موجودی',
      'وضعیت',
    ],
    rows: widget.store.products
        .map(
          (item) => <Object?>[
            item.category,
            item.sku,
            item.name,
            item.unit,
            formatPersianInteger(item.unitPrice),
            formatPersianInteger(item.stock),
            item.isActive ? 'فعال' : 'غیرفعال',
          ],
        )
        .toList(),
    numericColumns: const {4, 5},
  );

  @override
  Widget build(BuildContext context) {
    final needle = _search.text.trim().toLowerCase();
    final products = widget.store.products.where((item) {
      return needle.isEmpty ||
          item.name.toLowerCase().contains(needle) ||
          item.sku.toLowerCase().contains(needle) ||
          item.category.toLowerCase().contains(needle);
    }).toList();
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
            OutlinedButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('گروه کالای جدید'),
            ),
            OutlinedButton.icon(
              onPressed: _printReport,
              icon: const Icon(Icons.print_outlined),
              label: const Text('گزارش گروه‌ها'),
            ),
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
        SectionCard(
          title: 'گروه‌بندی کالاها',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.store.productCategories.map((category) {
              final count = widget.store.products
                  .where((item) => item.category == category)
                  .length;
              return Chip(
                label: Text('$category: ${formatPersianInteger(count)} محصول'),
              );
            }).toList(),
          ),
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
                        'موجودی ${formatPersianInteger(product.stock)} ${product.unit}، حداقل ${formatPersianInteger(product.minStock)}',
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
              : CrmConfigurableDataTable<CrmProduct>(
                  tableId: 'products',
                  rows: products,
                  initialSortColumnId: 'name',
                  columns: [
                    CrmTableColumn(
                      id: 'name',
                      label: 'محصول',
                      value: (product) => product.name,
                    ),
                    CrmTableColumn(
                      id: 'sku',
                      label: 'کد',
                      value: (product) => product.sku,
                    ),
                    CrmTableColumn(
                      id: 'category',
                      label: 'دسته',
                      value: (product) => product.category,
                    ),
                    CrmTableColumn(
                      id: 'unit',
                      label: 'واحد',
                      value: (product) => product.unit,
                    ),
                    CrmTableColumn(
                      id: 'price',
                      label: 'قیمت پایه (ریال)',
                      value: (product) => compactMoney(product.unitPrice),
                      sortValue: (product) => product.unitPrice,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'stock',
                      label: 'موجودی',
                      value: (product) =>
                          '${formatPersianInteger(product.stock)} / حداقل ${formatPersianInteger(product.minStock)}',
                      sortValue: (product) => product.stock,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'status',
                      label: 'وضعیت',
                      value: (product) => product.needsRestock
                          ? 'موجودی کم'
                          : product.isActive
                          ? 'فعال'
                          : 'غیر فعال',
                      cell: (context, product) => StatusPill(
                        label: product.needsRestock
                            ? 'موجودی کم'
                            : product.isActive
                            ? 'فعال'
                            : 'غیر فعال',
                      ),
                    ),
                    CrmTableColumn(
                      id: 'actions',
                      label: 'عملیات',
                      value: (_) => '',
                      canHide: false,
                      filterable: false,
                      cell: (context, product) => RecordActions(
                        onEdit: () => _openEditor(product),
                        onDelete: () => _delete(product),
                      ),
                    ),
                  ],
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
  String _category = 'سایر';
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
    _category = product.category.isEmpty ? 'سایر' : product.category;
    _unit.text = product.unit;
    _price.text = formatPersianInteger(product.unitPrice, grouping: true);
    _stock.text = formatPersianInteger(product.stock);
    _minStock.text = formatPersianInteger(product.minStock);
    _description.text = product.description;
    _active = product.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
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
      category: _category,
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
                ResponsiveFormField(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'گروه کالا',
                      suffixIcon: IconButton(
                        tooltip: 'افزودن گروه',
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                    items: {...widget.store.productCategories, _category}
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _category = value ?? _category),
                  ),
                ),
                ResponsiveFormField(child: _textField(_unit, 'واحد')),
                ResponsiveFormField(
                  child: _numberField(
                    _price,
                    'قیمت پایه (ریال)',
                    required: true,
                    rial: true,
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

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('گروه کالای جدید'),
        content: TextField(controller: controller, autofocus: true),
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
    await widget.store.addProductCategory(value);
    setState(() => _category = value.trim());
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
    bool rial = false,
  }) {
    return AutoInputDirection(
      controller: controller,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: rial
            ? const [persianRialFormatter]
            : const [persianNumberFormatter],
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
