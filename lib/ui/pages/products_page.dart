import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../widgets/common.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key, required this.store});

  final CrmStore store;

  Future<void> _openEditor(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ProductEditor(store: store),
    );
    if (saved == true && context.mounted) {
      showCrmNotice(context, 'محصول ثبت شد.', type: CrmNoticeType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = store.products.where((product) => product.needsRestock);
    final inventoryValue = store.products.fold(
      0,
      (sum, product) => sum + (product.stock * product.unitPrice),
    );
    return ListView(
      children: [
        CrmPageHeader(
          title: 'محصولات و موجودی',
          subtitle:
              'کالاها، قیمت پایه و حداقل موجودی را برای فروش و خرید نگه دارید.',
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(context),
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
                value: store.products
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
              width: 280,
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
              children: lowStock.map((product) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xffd84b4b),
                  ),
                  title: Text(product.name),
                  subtitle: Text(
                    'موجودی ' +
                        product.stock.toString() +
                        ' ' +
                        product.unit +
                        '، حداقل ' +
                        product.minStock.toString(),
                  ),
                  trailing: Text(
                    'نیازمند تامین',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
        ],
        SectionCard(
          title: 'فهرست کالا و خدمات',
          child: store.products.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'محصولی ثبت نشده است',
                  message:
                      'محصولات مورد استفاده در تماس، پیش‌فاکتور و سفارش را ثبت کنید.',
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('محصول')),
                      DataColumn(label: Text('کد')),
                      DataColumn(label: Text('دسته')),
                      DataColumn(label: Text('واحد')),
                      DataColumn(label: Text('قیمت پایه')),
                      DataColumn(label: Text('موجودی')),
                      DataColumn(label: Text('وضعیت')),
                    ],
                    rows: store.products.map((product) {
                      return DataRow(
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
                              product.stock.toString() +
                                  ' / حداقل ' +
                                  product.minStock.toString(),
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

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.store});

  final CrmStore store;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _category = TextEditingController(text: 'عمومی');
  final _unit = TextEditingController(text: 'عدد');
  final _price = TextEditingController(text: '0');
  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '0');
  final _description = TextEditingController();
  bool _saving = false;

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

  int _number(TextEditingController controller) {
    return parsePersianInt(controller.text);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
    });
    await widget.store.saveProduct(
      name: _name.text,
      sku: _sku.text,
      category: _category.text,
      unit: _unit.text,
      unitPrice: _number(_price),
      stock: _number(_stock),
      minStock: _number(_minStock),
      description: _description.text,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ثبت محصول یا خدمت'),
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
                  width: 280,
                  child: AutoInputDirection(
                    controller: _name,
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'نام محصول *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'نام محصول الزامی است.'
                          : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: AutoInputDirection(
                    controller: _sku,
                    child: TextFormField(
                      controller: _sku,
                      decoration: const InputDecoration(labelText: 'کد محصول'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: AutoInputDirection(
                    controller: _category,
                    child: TextFormField(
                      controller: _category,
                      decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: AutoInputDirection(
                    controller: _unit,
                    child: TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'واحد'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: AutoInputDirection(
                    controller: _price,
                    child: TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'قیمت پایه (تومان)',
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: AutoInputDirection(
                    controller: _stock,
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'موجودی فعلی',
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: AutoInputDirection(
                    controller: _minStock,
                    child: TextFormField(
                      controller: _minStock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'حداقل موجودی',
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
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
          child: Text(_saving ? 'در حال ذخیره' : 'ذخیره محصول'),
        ),
      ],
    );
  }
}
