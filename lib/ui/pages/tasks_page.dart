import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor([CrmTask? task]) async {
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
      builder: (context) => _TaskEditor(store: widget.store, task: task),
    );
    if (mounted && saved == true) {
      showCrmNotice(
        context,
        task == null ? 'وظیفه ثبت شد.' : 'وظیفه ویرایش شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _delete(CrmTask task) async {
    if (!await confirmDelete(context, label: task.title)) return;
    await widget.store.deleteTask(task);
    if (mounted) {
      showCrmNotice(
        context,
        'وظیفه به حذف‌شده‌ها منتقل شد.',
        type: CrmNoticeType.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final needle = _search.text.trim().toLowerCase();
    final tasks = widget.store.tasks
        .where(
          (task) =>
              needle.isEmpty ||
              task.title.toLowerCase().contains(needle) ||
              task.customerName.toLowerCase().contains(needle) ||
              task.status.contains(needle),
        )
        .toList();
    final active = tasks.where((task) => !task.isDone).toList()
      ..sort(
        (a, b) =>
            (a.dueAt ?? DateTime(3000)).compareTo(b.dueAt ?? DateTime(3000)),
      );
    final done = tasks.where((task) => task.isDone).toList();
    return ListView(
      children: [
        CrmPageHeader(
          title: 'پیگیری و وظایف',
          subtitle:
              'پیگیری‌های تماس، جلسه، پیش‌فاکتور و سفارش را زمان‌بندی کنید.',
          actions: [
            FilledButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('وظیفه جدید'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'وظایف باز',
                value: widget.store.openTasks.toString(),
                icon: Icons.assignment_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'سررسید گذشته',
                value: widget.store.overdueTasks.toString(),
                icon: Icons.warning_amber_rounded,
                color: const Color(0xffd84b4b),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'انجام‌شده',
                value: widget.store.tasks
                    .where((item) => item.isDone)
                    .length
                    .toString(),
                icon: Icons.task_alt_rounded,
                color: const Color(0xff12966b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'جست‌وجوی وظایف',
          child: AutoInputDirection(
            controller: _search,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'عنوان، مشتری یا وضعیت',
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'کارهای فعال',
          trailing: Text('${formatPersianInteger(active.length)} مورد'),
          child: active.isEmpty
              ? const EmptyState(
                  icon: Icons.task_alt_outlined,
                  title: 'کار بازی ندارید',
                  message: 'پیگیری تماس‌ها و جلسات را به وظیفه تبدیل کنید.',
                )
              : Column(
                  children: active
                      .map(
                        (task) => _TaskTile(
                          store: widget.store,
                          task: task,
                          onEdit: () => _openEditor(task),
                          onDelete: () => _delete(task),
                        ),
                      )
                      .toList(),
                ),
        ),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionCard(
            title: 'آخرین کارهای انجام‌شده',
            child: Column(
              children: done
                  .take(8)
                  .map(
                    (task) => _TaskTile(
                      store: widget.store,
                      task: task,
                      compact: true,
                      onEdit: () => _openEditor(task),
                      onDelete: () => _delete(task),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.store,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
  });

  final CrmStore store;
  final CrmTask task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = task.isOverdue
        ? const Color(0xffd84b4b)
        : task.priority == 'خیلی بالا' || task.priority == 'بالا'
        ? const Color(0xffe58a00)
        : const Color(0xff0b63ce);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isDone,
            onChanged: task.isDone ? null : (_) => store.completeTask(task),
          ),
          Container(
            width: 8,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${task.customerName} • ${task.taskType}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (task.dueAt != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    compactDate(task.dueAt!),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.status,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'عملیات وظیفه',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('ویرایش'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('حذف'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.store, this.task});

  final CrmStore store;
  final CrmTask? task;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  String? _customerId;
  String _taskType = 'پیگیری';
  String _priority = 'متوسط';
  String _status = 'باز';
  DateTime? _dueAt = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task == null) return;
    _customerId = task.customerId;
    _title.text = task.title;
    _notes.text = task.notes;
    _taskType = task.taskType;
    _priority = task.priority;
    _status = task.status;
    _dueAt = task.dueAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(_dueAt ?? DateTime.now()),
      firstDate: Jalali.fromDateTime(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
      lastDate: Jalali.fromDateTime(
        DateTime.now().add(const Duration(days: 730)),
      ),
    );
    if (date != null && mounted) setState(() => _dueAt = date.toDateTime());
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final customer = widget.store.customers.firstWhere(
      (item) => item.id == _customerId,
    );
    setState(() => _saving = true);
    await widget.store.saveTask(
      id: widget.task?.id,
      customer: customer,
      title: _title.text,
      taskType: _taskType,
      priority: _priority,
      status: _status,
      notes: _notes.text,
      dueAt: _dueAt,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.task == null ? 'ثبت وظیفه و پیگیری' : 'ویرایش وظیفه و پیگیری',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
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
                        value == null ? 'مشتری را انتخاب کنید.' : null,
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
                        labelText: 'عنوان وظیفه *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'عنوان الزامی است.'
                          : null,
                    ),
                  ),
                ),
                ResponsiveFormField(
                  child: _dropdown('نوع', _taskType, const [
                    'پیگیری',
                    'تماس',
                    'جلسه',
                    'ایمیل',
                    'داخلی',
                  ], (value) => _taskType = value),
                ),
                ResponsiveFormField(
                  child: _dropdown('اولویت', _priority, const [
                    'خیلی بالا',
                    'بالا',
                    'متوسط',
                    'پایین',
                  ], (value) => _priority = value),
                ),
                ResponsiveFormField(
                  child: _dropdown('وضعیت', _status, const [
                    'باز',
                    'در حال انجام',
                    'انجام شد',
                  ], (value) => _status = value),
                ),
                ResponsiveFormField(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _dueAt == null
                          ? 'بدون سررسید'
                          : 'سررسید: ${compactDate(_dueAt!)}',
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
          child: Text(
            _saving
                ? 'در حال ذخیره'
                : widget.task == null
                ? 'ثبت وظیفه'
                : 'ذخیره تغییرات',
          ),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (next) => setState(() => changed(next ?? value)),
    );
  }
}
