import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key, required this.store});

  final CrmStore store;

  Future<void> _openEditor(BuildContext context) async {
    if (store.customers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ابتدا یک مشتری ثبت کنید.')));
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _TaskEditor(store: store),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('وظیفه ثبت شد.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = store.tasks.where((task) => !task.isDone).toList()
      ..sort((a, b) {
        final aDue = a.dueAt ?? DateTime(3000);
        final bDue = b.dueAt ?? DateTime(3000);
        return aDue.compareTo(bDue);
      });
    final done = store.tasks.where((task) => task.isDone).toList();
    return ListView(
      children: [
        CrmPageHeader(
          title: 'پیگیری و وظایف',
          subtitle:
              'پیگیری‌های تماس، جلسه، پیش‌فاکتور و سفارش را زمان‌بندی کنید.',
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(context),
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
                value: store.openTasks.toString(),
                icon: Icons.assignment_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'سررسید گذشته',
                value: store.overdueTasks.toString(),
                icon: Icons.warning_amber_rounded,
                color: const Color(0xffd84b4b),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'انجام‌شده',
                value: done.length.toString(),
                icon: Icons.task_alt_rounded,
                color: const Color(0xff12966b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'کارهای فعال',
          child: active.isEmpty
              ? const EmptyState(
                  icon: Icons.task_alt_outlined,
                  title: 'کار بازی ندارید',
                  message: 'پیگیری تماس‌ها و جلسات را به وظیفه تبدیل کنید.',
                )
              : Column(
                  children: active.map((task) {
                    return _TaskTile(store: store, task: task);
                  }).toList(),
                ),
        ),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionCard(
            title: 'آخرین کارهای انجام‌شده',
            child: Column(
              children: done.take(5).map((task) {
                return _TaskTile(store: store, task: task, compact: true);
              }).toList(),
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
    this.compact = false,
  });

  final CrmStore store;
  final CrmTask task;
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
            onChanged: task.isDone
                ? null
                : (_) async {
                    await store.completeTask(task);
                  },
          ),
          Container(
            width: 8,
            height: 42,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.customerName + ' • ' + task.taskType,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (task.dueAt != null)
            Column(
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
        ],
      ),
    );
  }
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.store});

  final CrmStore store;

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
  DateTime? _dueAt = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

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
    if (date != null && mounted) {
      setState(() {
        _dueAt = date.toDateTime();
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
    await widget.store.saveTask(
      customer: customer,
      title: _title.text,
      taskType: _taskType,
      priority: _priority,
      status: 'باز',
      notes: _notes.text,
      dueAt: _dueAt,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ثبت وظیفه و پیگیری'),
      content: SizedBox(
        width: 540,
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
                        value == null ? 'مشتری را انتخاب کنید.' : null,
                    onChanged: (value) {
                      setState(() {
                        _customerId = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'عنوان وظیفه *',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'عنوان الزامی است.'
                        : null,
                  ),
                ),
                SizedBox(
                  width: 258,
                  child: DropdownButtonFormField<String>(
                    initialValue: _taskType,
                    decoration: const InputDecoration(labelText: 'نوع'),
                    items: const [
                      DropdownMenuItem(value: 'پیگیری', child: Text('پیگیری')),
                      DropdownMenuItem(value: 'تماس', child: Text('تماس')),
                      DropdownMenuItem(value: 'جلسه', child: Text('جلسه')),
                      DropdownMenuItem(value: 'ایمیل', child: Text('ایمیل')),
                      DropdownMenuItem(value: 'داخلی', child: Text('داخلی')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _taskType = value ?? _taskType;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 258,
                  child: DropdownButtonFormField<String>(
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
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _dueAt == null
                          ? 'بدون سررسید'
                          : 'سررسید: ' + compactDate(_dueAt!),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
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
          child: Text(_saving ? 'در حال ذخیره' : 'ثبت وظیفه'),
        ),
      ],
    );
  }
}
