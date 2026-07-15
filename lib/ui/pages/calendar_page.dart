import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  Jalali _visibleMonth = Jalali.now();

  List<_CalendarEvent> get _events => <_CalendarEvent>[
    ...widget.store.tasks
        .where((task) => task.dueAt != null)
        .map(
          (task) => _CalendarEvent(
            date: task.dueAt!,
            title: task.title,
            subtitle: '${task.customerName} • ${task.taskType}',
            color: task.isDone
                ? const Color(0xff12966b)
                : task.isOverdue
                ? const Color(0xffd84b4b)
                : const Color(0xff0b63ce),
            icon: Icons.task_alt_rounded,
            task: task,
          ),
        ),
    ...widget.store.calls
        .where((call) => call.nextFollowUp != null)
        .map(
          (call) => _CalendarEvent(
            date: call.nextFollowUp!,
            title: 'پیگیری تماس: ${call.subject}',
            subtitle: call.customerName,
            color: const Color(0xffe58a00),
            icon: Icons.phone_in_talk_rounded,
          ),
        ),
  ]..sort((a, b) => a.date.compareTo(b.date));

  Future<void> _openEditor({CrmTask? task, DateTime? initialDate}) async {
    if (widget.store.customers.isEmpty) {
      showCrmNotice(
        context,
        'برای ثبت رویداد ابتدا یک مشتری ثبت کنید.',
        type: CrmNoticeType.warning,
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CalendarEventEditor(
        store: widget.store,
        task: task,
        initialDate: initialDate,
      ),
    );
    if (mounted && saved == true) {
      showCrmNotice(
        context,
        task == null ? 'رویداد تقویم ثبت شد.' : 'رویداد تقویم ویرایش شد.',
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
        'رویداد از تقویم حذف شد.',
        type: CrmNoticeType.warning,
      );
    }
  }

  Future<void> _showEvent(_CalendarEvent event) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.subtitle),
              const SizedBox(height: 8),
              Text('تاریخ: ${formatJalaliDateWithWeekday(event.date)}'),
              if (event.task != null && event.task!.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(event.task!.notes),
              ],
            ],
          ),
        ),
        actions: [
          if (event.task != null) ...[
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _delete(event.task!);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('حذف'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pop();
                _openEditor(task: event.task);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('ویرایش'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReport() => CrmReportService.printTable(
    context: context,
    title: 'گزارش تقویم خرید و فروش',
    headers: const ['تاریخ', 'عنوان', 'مشتری / شرح', 'نوع'],
    rows: _events
        .map(
          (event) => <Object?>[
            compactDate(event.date),
            event.title,
            event.subtitle,
            event.task?.taskType ?? 'پیگیری تماس',
          ],
        )
        .toList(),
    rowDates: _events.map((event) => event.date).toList(),
  );

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final upcoming = _events
        .where(
          (event) => !event.date.isBefore(
            DateTime(today.year, today.month, today.day),
          ),
        )
        .take(12)
        .toList();
    return ListView(
      children: [
        CrmPageHeader(
          title: 'تقویم خرید و فروش',
          subtitle:
              'اهداف، جلسه‌ها، پیگیری‌ها و برنامه‌های پیش‌رو را در تقویم شمسی مدیریت کنید.',
          actions: [
            OutlinedButton.icon(
              onPressed: _printReport,
              icon: const Icon(Icons.print_outlined),
              label: const Text('گزارش و چاپ'),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(initialDate: DateTime.now()),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('رویداد جدید'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _MonthCalendar(
          month: _visibleMonth,
          events: _events,
          onPrevious: () => setState(() {
            _visibleMonth = _visibleMonth.addMonths(-1);
          }),
          onNext: () => setState(() {
            _visibleMonth = _visibleMonth.addMonths(1);
          }),
          onToday: () => setState(() => _visibleMonth = Jalali.now()),
          onDayTap: (date, events) {
            if (events.isEmpty) {
              _openEditor(initialDate: date);
            } else if (events.length == 1) {
              _showEvent(events.first);
            } else {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('برنامه‌های ${compactDate(date)}'),
                  content: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: events
                          .map(
                            (event) => ListTile(
                              leading: Icon(event.icon, color: event.color),
                              title: Text(event.title),
                              subtitle: Text(event.subtitle),
                              onTap: () {
                                Navigator.of(context).pop();
                                _showEvent(event);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  actions: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openEditor(initialDate: date);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن رویداد'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'برنامه پیش‌رو',
          child: upcoming.isEmpty
              ? const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'برنامه‌ای ثبت نشده است',
                  message: 'روی یک روز تقویم کلیک کنید و رویداد بسازید.',
                )
              : Column(
                  children: upcoming
                      .map(
                        (event) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: event.color.withValues(
                              alpha: 0.12,
                            ),
                            child: Icon(event.icon, color: event.color),
                          ),
                          title: Text(event.title),
                          subtitle: Text(event.subtitle),
                          trailing: Text(compactDate(event.date)),
                          onTap: () => _showEvent(event),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.events,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onDayTap,
  });

  final Jalali month;
  final List<_CalendarEvent> events;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final void Function(DateTime date, List<_CalendarEvent> events) onDayTap;

  static const _monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  @override
  Widget build(BuildContext context) {
    final first = Jalali(month.year, month.month, 1);
    final offset = first.weekDay - 1;
    final totalCells = ((offset + first.monthLength + 6) ~/ 7) * 7;
    final today = Jalali.now();
    return SectionCard(
      title: 'نمای ماهانه شمسی',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_right),
          ),
          Text(
            '${_monthNames[month.month - 1]} ${toPersianDigits(month.year)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_left)),
          TextButton(onPressed: onToday, child: const Text('امروز')),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']
                .map(
                  (day) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(day, textAlign: TextAlign.center),
                    ),
                  ),
                )
                .toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final day = index - offset + 1;
              if (day < 1 || day > first.monthLength) return const SizedBox();
              final jalali = Jalali(month.year, month.month, day);
              final date = jalali.toDateTime();
              final dayEvents = events.where((event) {
                final eventDate = event.date.toLocal();
                return eventDate.year == date.year &&
                    eventDate.month == date.month &&
                    eventDate.day == date.day;
              }).toList();
              final isToday =
                  jalali.year == today.year &&
                  jalali.month == today.month &&
                  jalali.day == today.day;
              return Card(
                margin: const EdgeInsets.all(3),
                color: isToday
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onDayTap(date, dayEvents),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toPersianDigits(day),
                          style: TextStyle(
                            fontWeight: isToday
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (dayEvents.isNotEmpty)
                          Wrap(
                            spacing: 3,
                            runSpacing: 3,
                            children: dayEvents
                                .take(4)
                                .map(
                                  (event) => Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: event.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarEventEditor extends StatefulWidget {
  const _CalendarEventEditor({
    required this.store,
    this.task,
    this.initialDate,
  });

  final CrmStore store;
  final CrmTask? task;
  final DateTime? initialDate;

  @override
  State<_CalendarEventEditor> createState() => _CalendarEventEditorState();
}

class _CalendarEventEditorState extends State<_CalendarEventEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  String? _customerId;
  String _type = 'هدف فروش';
  String _priority = 'متوسط';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _date = task?.dueAt ?? widget.initialDate ?? DateTime.now();
    if (task == null) return;
    _customerId = task.customerId;
    _title.text = task.title;
    _notes.text = task.notes;
    _type = task.taskType;
    _priority = task.priority;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showCrmJalaliDatePicker(
      context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (value != null && mounted) setState(() => _date = value);
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
      taskType: _type,
      priority: _priority,
      status: widget.task?.status ?? 'باز',
      notes: _notes.text,
      dueAt: _date,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.task == null ? 'ثبت برنامه تقویم' : 'ویرایش برنامه تقویم',
    ),
    content: CrmDialogContent(
      maxWidth: 620,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: ResponsiveFormGrid(
            children: [
              ResponsiveFormField.full(
                child: DropdownButtonFormField<String>(
                  initialValue: _customerId,
                  decoration: const InputDecoration(labelText: 'مشتری *'),
                  items: widget.store.customers
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.displayName),
                        ),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'مشتری را انتخاب کنید.' : null,
                  onChanged: (value) => setState(() => _customerId = value),
                ),
              ),
              ResponsiveFormField.full(
                child: TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'عنوان برنامه *',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'عنوان برنامه الزامی است.'
                      : null,
                ),
              ),
              ResponsiveFormField(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'نوع برنامه'),
                  items:
                      const [
                            'هدف خرید',
                            'هدف فروش',
                            'جلسه',
                            'پیگیری',
                            'یادآوری',
                          ]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _type = value ?? _type),
                ),
              ),
              ResponsiveFormField(
                child: DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'اولویت'),
                  items: const ['خیلی بالا', 'بالا', 'متوسط', 'پایین']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _priority = value ?? _priority),
                ),
              ),
              ResponsiveFormField.full(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text('تاریخ: ${compactDate(_date)}'),
                ),
              ),
              ResponsiveFormField.full(
                child: TextFormField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'توضیحات'),
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

class _CalendarEvent {
  const _CalendarEvent({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.task,
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final CrmTask? task;
}
