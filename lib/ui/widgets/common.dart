import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/persian_format.dart';

export '../../core/persian_format.dart';

enum CrmNoticeType { info, success, warning, error }

/// Shows an in-app notification with a semantic color and a soft entrance.
void showCrmNotice(
  BuildContext context,
  String message, {
  CrmNoticeType type = CrmNoticeType.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        duration: const Duration(seconds: 5),
        content: _CrmNotice(message: message, type: type),
      ),
    );
}

class _CrmNotice extends StatelessWidget {
  const _CrmNotice({required this.message, required this.type});

  final String message;
  final CrmNoticeType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon, title) = switch (type) {
      CrmNoticeType.success => (
        const Color(0xff14966b),
        Icons.check_circle_rounded,
        'انجام شد',
      ),
      CrmNoticeType.warning => (
        const Color(0xffd98500),
        Icons.warning_amber_rounded,
        'توجه',
      ),
      CrmNoticeType.error => (scheme.error, Icons.error_rounded, 'خطا'),
      CrmNoticeType.info => (scheme.primary, Icons.info_rounded, 'اطلاع'),
    };
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 230);
    return Semantics(
      liveRegion: true,
      label: '$title: $message',
      child: TweenAnimationBuilder<double>(
        duration: duration,
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.24)!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'بستن اعلان',
                  onPressed: () =>
                      ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Makes the text direction of a field follow the first meaningful character.
/// Persian/Arabic begins on the right while Latin text, phone numbers and
/// Persian/Arabic digits begin on the left.
TextDirection inputTextDirection(String value) {
  for (final rune in value.runes) {
    if (String.fromCharCode(rune).trim().isEmpty) continue;
    final isDigit =
        (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x0660 && rune <= 0x0669) ||
        (rune >= 0x06f0 && rune <= 0x06f9);
    final isLatin =
        (rune >= 0x41 && rune <= 0x5a) ||
        (rune >= 0x61 && rune <= 0x7a) ||
        const <int>{0x2b, 0x2d, 0x40, 0x2e, 0x2f, 0x5f}.contains(rune);
    if (isDigit || isLatin) return TextDirection.ltr;
    final isRtl =
        (rune >= 0x0590 && rune <= 0x08ff) ||
        (rune >= 0xfb50 && rune <= 0xfdff) ||
        (rune >= 0xfe70 && rune <= 0xfeff);
    if (isRtl) return TextDirection.rtl;
  }
  return TextDirection.rtl;
}

class AutoInputDirection extends StatelessWidget {
  const AutoInputDirection({
    super.key,
    required this.controller,
    required this.child,
  });

  final TextEditingController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      child: child,
      builder: (context, value, child) => Directionality(
        textDirection: inputTextDirection(value.text),
        child: child!,
      ),
    );
  }
}

/// Normalizes Persian/Arabic/Latin digits and rejects non-numeric characters.
/// Thousands grouping is opt-in and must only be enabled for monetary fields;
/// telephone numbers, identifiers and quantities must stay contiguous.
class PersianNumberFormatter extends TextInputFormatter {
  const PersianNumberFormatter({
    this.allowNegative = false,
    this.grouping = false,
  });

  final bool allowNegative;
  final bool grouping;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var normalized = toEnglishDigits(
      newValue.text,
    ).replaceAll(RegExp(r'[^0-9-]'), '');
    if (!allowNegative) normalized = normalized.replaceAll('-', '');
    if (allowNegative && normalized.indexOf('-') > 0) {
      normalized = normalized.replaceAll('-', '');
    }
    if (normalized == '-' || normalized.isEmpty) {
      return TextEditingValue(
        text: normalized == '-' && allowNegative ? '−' : '',
        selection: TextSelection.collapsed(offset: normalized.isEmpty ? 0 : 1),
      );
    }
    final value = grouping
        ? formatPersianInteger(int.tryParse(normalized) ?? 0, grouping: true)
        : formatPersianDigitsOnly(normalized, allowNegative: allowNegative);
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

/// Restricts a field that represents a human-readable title/name to letters,
/// whitespace and the usual Persian punctuation. Identifiers, URLs and phone
/// fields deliberately use their own input type and are not passed here.
final textOnlyFormatter = FilteringTextInputFormatter.allow(
  RegExp(r"[a-zA-Z\u0600-\u06FF\s\-_.،()\u200c]"),
);

const persianNumberFormatter = PersianNumberFormatter();
const persianRialFormatter = PersianNumberFormatter(grouping: true);

class ResponsiveFormField extends StatelessWidget {
  const ResponsiveFormField({
    super.key,
    required this.child,
    this.full = false,
  });

  final Widget child;
  final bool full;

  const ResponsiveFormField.full({super.key, required this.child})
    : full = true;

  @override
  Widget build(BuildContext context) => child;
}

/// A predictable two-column dialog form that becomes one column when space is
/// tight. It eliminates fixed-width Wrap overflows and keeps form controls
/// aligned in RTL dialogs.
class ResponsiveFormGrid extends StatelessWidget {
  const ResponsiveFormGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.breakpoint = 500,
  });

  /// Normal widgets occupy one responsive column. Wrap a child in
  /// [ResponsiveFormField.full] when it must span the whole dialog.
  /// Keeping this list typed as [Widget] makes the grid safe to adopt in
  /// existing dialogs without reintroducing fixed-width wrappers.
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= breakpoint;
        final width = twoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((item) {
            final formField = item is ResponsiveFormField ? item : null;
            return SizedBox(
              width: formField?.full == true ? constraints.maxWidth : width,
              child: formField?.child ?? item,
            );
          }).toList(),
        );
      },
    );
  }
}

/// Gives desktop dialogs a real, responsive width. `ConstrainedBox(maxWidth:)`
/// alone keeps AlertDialog's intrinsic width (often about 280px), which was the
/// reason several data-entry popups collapsed into a single narrow column.
class CrmDialogContent extends StatelessWidget {
  const CrmDialogContent({super.key, required this.child, this.maxWidth = 680});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // AlertDialog keeps its own insets.  Do not force a width wider than the
    // actual viewport on a temporarily narrow desktop window.
    final available = math.max(0.0, MediaQuery.sizeOf(context).width - 48);
    return SizedBox(width: math.min(maxWidth, available), child: child);
  }
}

/// A Jalali-only calendar. The package picker previously used a Jalali grid
/// with Gregorian Material labels, so users could still see months such as
/// June. This widget owns both the month label and the day grid.
Future<DateTime?> showCrmJalaliDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'انتخاب تاریخ شمسی',
}) {
  final now = DateTime.now();
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _CrmJalaliDatePickerDialog(
      title: title,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(now.year - 15),
      lastDate: lastDate ?? DateTime(now.year + 15),
    ),
  );
}

class _CrmJalaliDatePickerDialog extends StatefulWidget {
  const _CrmJalaliDatePickerDialog({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_CrmJalaliDatePickerDialog> createState() =>
      _CrmJalaliDatePickerDialogState();
}

class _CrmJalaliDatePickerDialogState
    extends State<_CrmJalaliDatePickerDialog> {
  static const _months = <String>[
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
  static const _weekdays = <String>['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  late final Jalali _first;
  late final Jalali _last;
  late Jalali _selected;
  late Jalali _displayed;

  @override
  void initState() {
    super.initState();
    _first = Jalali.fromDateTime(_dateOnly(widget.firstDate));
    _last = Jalali.fromDateTime(_dateOnly(widget.lastDate));
    final candidate = Jalali.fromDateTime(_dateOnly(widget.initialDate));
    _selected = _clamp(candidate);
    _displayed = Jalali(_selected.year, _selected.month);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Jalali _clamp(Jalali value) {
    if (value.compareTo(_first) < 0) return _first;
    if (value.compareTo(_last) > 0) return _last;
    return value;
  }

  bool _canShow(Jalali month) {
    final firstOfMonth = Jalali(month.year, month.month);
    final lastOfMonth = Jalali(month.year, month.month, month.monthLength);
    return firstOfMonth.compareTo(_last) <= 0 &&
        lastOfMonth.compareTo(_first) >= 0;
  }

  void _moveMonth(int direction) {
    var year = _displayed.year;
    var month = _displayed.month + direction;
    if (month == 0) {
      month = 12;
      year--;
    } else if (month == 13) {
      month = 1;
      year++;
    }
    final next = Jalali(year, month);
    if (_canShow(next)) setState(() => _displayed = next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstCell = _displayed.weekDay - 1;
    final dayCount = _displayed.monthLength;
    final previous = _monthAt(-1);
    final next = _monthAt(1);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(0, MediaQuery.sizeOf(context).height - 48),
        ),
        child: SingleChildScrollView(
          child: CrmDialogContent(
            maxWidth: 460,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'بستن',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      formatJalaliDate(_selected.toDateTime()),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'ماه بعد',
                        onPressed: _canShow(next) ? () => _moveMonth(1) : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '${_months[_displayed.month - 1]} ${toPersianDigits(_displayed.year)}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'ماه قبل',
                        onPressed: _canShow(previous)
                            ? () => _moveMonth(-1)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.18,
                    children: [
                      for (final day in _weekdays)
                        Center(
                          child: Text(
                            day,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      for (var index = 0; index < 42; index++)
                        if (index < firstCell || index >= firstCell + dayCount)
                          const SizedBox()
                        else
                          _dayButton(
                            Jalali(
                              _displayed.year,
                              _displayed.month,
                              index - firstCell + 1,
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('انصراف'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_selected.toDateTime()),
                        child: const Text('تأیید'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Jalali _monthAt(int delta) {
    var year = _displayed.year;
    var month = _displayed.month + delta;
    if (month == 0) {
      month = 12;
      year--;
    } else if (month == 13) {
      month = 1;
      year++;
    }
    return Jalali(year, month);
  }

  Widget _dayButton(Jalali date) {
    final enabled = date.compareTo(_first) >= 0 && date.compareTo(_last) <= 0;
    final selected =
        date.year == _selected.year &&
        date.month == _selected.month &&
        date.day == _selected.day;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => setState(() => _selected = date) : null,
          child: Center(
            child: Text(
              toPersianDigits(date.day),
              style: TextStyle(
                color: !enabled
                    ? Theme.of(context).disabledColor
                    : selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Provides a visible horizontal scrollbar for wide data tables. The scroll
/// controller is kept in state so the thumb remains available on Windows.
class CrmTableScroll extends StatefulWidget {
  const CrmTableScroll({super.key, required this.child});

  final Widget child;

  @override
  State<CrmTableScroll> createState() => _CrmTableScrollState();
}

class _CrmTableScrollState extends State<CrmTableScroll> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        child: widget.child,
      ),
    );
  }
}

class CrmTableColumn<T> {
  const CrmTableColumn({
    required this.id,
    required this.label,
    required this.value,
    this.cell,
    this.sortValue,
    this.numeric = false,
    this.canHide = true,
    this.filterable = true,
    this.initiallyVisible = true,
    this.initialWidth = 150,
    this.minWidth = 80,
    this.maxWidth = 360,
  });

  final String id;
  final String label;
  final String Function(T item) value;
  final Widget Function(BuildContext context, T item)? cell;
  final Object? Function(T item)? sortValue;
  final bool numeric;
  final bool canHide;
  final bool filterable;
  final bool initiallyVisible;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
}

class _CrmSortSpec {
  const _CrmSortSpec(this.columnId, this.ascending);

  final String columnId;
  final bool ascending;

  Map<String, dynamic> toJson() => {'column': columnId, 'ascending': ascending};
}

/// A reusable Windows-friendly table whose column order and visibility are
/// persisted per table. Filtering and sorting are performed on the same source
/// values used to render each cell, keeping every CRM list consistent.
class CrmConfigurableDataTable<T> extends StatefulWidget {
  const CrmConfigurableDataTable({
    super.key,
    required this.tableId,
    required this.columns,
    required this.rows,
    this.initialSortColumnId,
    this.initialSortAscending = true,
    this.showToolbar = true,
    this.showRowNumbers = true,
    this.enableSelection = true,
    this.rowKey,
    this.rowColor,
  });

  final String tableId;
  final List<CrmTableColumn<T>> columns;
  final List<T> rows;
  final String? initialSortColumnId;
  final bool initialSortAscending;
  final bool showToolbar;
  final bool showRowNumbers;
  final bool enableSelection;
  final Object Function(T item)? rowKey;
  final Color? Function(T item)? rowColor;

  @override
  State<CrmConfigurableDataTable<T>> createState() =>
      _CrmConfigurableDataTableState<T>();
}

class _CrmConfigurableDataTableState<T>
    extends State<CrmConfigurableDataTable<T>> {
  late List<String> _order;
  late Set<String> _visible;
  final Map<String, TextEditingController> _filters = {};
  final TextEditingController _globalSearch = TextEditingController();
  final Set<Object> _selected = {};
  final Map<String, double> _widths = {};
  final Set<String> _frozen = {};
  List<_CrmSortSpec> _sorts = const [];
  String _preferenceScope = 'offline';
  int _page = 0;
  int _pageSize = 25;
  String? _sortColumnId;
  late bool _sortAscending;

  String get _preferenceKey =>
      'crm_table_layout_${_preferenceScope}_${widget.tableId}';
  String get _filterPresetKey =>
      'crm_table_filters_${_preferenceScope}_${widget.tableId}';

  @override
  void initState() {
    super.initState();
    _order = widget.columns.map((column) => column.id).toList();
    _visible = widget.columns
        .where((column) => column.initiallyVisible || !column.canHide)
        .map((column) => column.id)
        .toSet();
    _sortColumnId = widget.initialSortColumnId;
    _sortAscending = widget.initialSortAscending;
    if (_sortColumnId != null) {
      _sorts = [_CrmSortSpec(_sortColumnId!, _sortAscending)];
    }
    for (final column in widget.columns) {
      _widths[column.id] = column.initialWidth;
    }
    _syncFilterControllers();
    _loadLayout();
  }

  @override
  void didUpdateWidget(covariant CrmConfigurableDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.columns.map((column) => column.id).toSet();
    _order = [
      ..._order.where(ids.contains),
      ...widget.columns
          .map((column) => column.id)
          .where((id) => !_order.contains(id)),
    ];
    _visible.removeWhere((id) => !ids.contains(id));
    for (final column in widget.columns.where((column) => !column.canHide)) {
      _visible.add(column.id);
    }
    for (final column in widget.columns) {
      _widths.putIfAbsent(column.id, () => column.initialWidth);
    }
    _widths.removeWhere((id, _) => !ids.contains(id));
    _frozen.removeWhere((id) => !ids.contains(id));
    final rowKeys = widget.rows.map(_keyFor).toSet();
    _selected.removeWhere((key) => !rowKeys.contains(key));
    _syncFilterControllers();
  }

  @override
  void dispose() {
    _globalSearch.dispose();
    for (final controller in _filters.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncFilterControllers() {
    final ids = widget.columns.map((column) => column.id).toSet();
    for (final id in ids) {
      _filters.putIfAbsent(id, TextEditingController.new);
    }
    final removed = _filters.keys.where((id) => !ids.contains(id)).toList();
    for (final id in removed) {
      _filters.remove(id)?.dispose();
    }
  }

  Future<void> _loadLayout() async {
    final preferences = await SharedPreferences.getInstance();
    _preferenceScope =
        preferences.getString('crm_active_user_scope') ?? 'offline';
    final raw = preferences.getString(_preferenceKey);
    if (raw == null || !mounted) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final ids = widget.columns.map((column) => column.id).toSet();
      final savedOrder = (decoded['order'] as List? ?? const [])
          .map((item) => item.toString())
          .where(ids.contains)
          .toList();
      final savedVisible = (decoded['visible'] as List? ?? const [])
          .map((item) => item.toString())
          .where(ids.contains)
          .toSet();
      final savedWidths = (decoded['widths'] as Map? ?? const {}).map(
        (key, value) =>
            MapEntry(key.toString(), double.tryParse(value.toString()) ?? 150),
      );
      final savedFrozen = (decoded['frozen'] as List? ?? const [])
          .map((item) => item.toString())
          .where(ids.contains)
          .toSet();
      final savedSorts = (decoded['sorts'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => _CrmSortSpec(
              item['column']?.toString() ?? '',
              item['ascending'] != false,
            ),
          )
          .where((item) => ids.contains(item.columnId))
          .toList();
      final savedFilters = (decoded['filters'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      setState(() {
        _order = [
          ...savedOrder,
          ...widget.columns
              .map((column) => column.id)
              .where((id) => !savedOrder.contains(id)),
        ];
        _visible = savedVisible.isEmpty ? _visible : savedVisible;
        for (final column in widget.columns.where(
          (column) => !column.canHide,
        )) {
          _visible.add(column.id);
        }
        for (final column in widget.columns) {
          final width = savedWidths[column.id];
          if (width != null) {
            _widths[column.id] = width
                .clamp(column.minWidth, column.maxWidth)
                .toDouble();
          }
        }
        _frozen
          ..clear()
          ..addAll(savedFrozen);
        if (savedSorts.isNotEmpty) {
          _sorts = savedSorts;
          _sortColumnId = savedSorts.first.columnId;
          _sortAscending = savedSorts.first.ascending;
        }
        _pageSize = int.tryParse(decoded['page_size']?.toString() ?? '') ?? 25;
        for (final entry in savedFilters.entries) {
          _filters[entry.key]?.text = entry.value;
        }
        _globalSearch.text = decoded['search']?.toString() ?? '';
      });
    } catch (_) {
      // Ignore an old or partially written layout and keep safe defaults.
    }
  }

  Future<void> _saveLayout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _preferenceKey,
      jsonEncode({
        'order': _order,
        'visible': _visible.toList(),
        'widths': _widths,
        'frozen': _frozen.toList(),
        'sorts': _sorts.map((item) => item.toJson()).toList(),
        'page_size': _pageSize,
        'search': _globalSearch.text,
        'filters': {
          for (final entry in _filters.entries) entry.key: entry.value.text,
        },
      }),
    );
  }

  CrmTableColumn<T> _column(String id) =>
      widget.columns.firstWhere((column) => column.id == id);

  List<T> _filteredRows() {
    final needle = _globalSearch.text.trim().toLowerCase();
    final rows = widget.rows.where((item) {
      if (needle.isNotEmpty &&
          !widget.columns.any(
            (column) => column.value(item).toLowerCase().contains(needle),
          )) {
        return false;
      }
      for (final column in widget.columns) {
        if (!column.filterable) continue;
        final filter = _filters[column.id]?.text.trim().toLowerCase() ?? '';
        if (filter.isNotEmpty &&
            !column.value(item).toLowerCase().contains(filter)) {
          return false;
        }
      }
      return true;
    }).toList();
    if (_sorts.isNotEmpty) {
      rows.sort((left, right) {
        for (final spec in _sorts) {
          final column = _column(spec.columnId);
          final result = _compare(
            column.sortValue?.call(left) ?? column.value(left),
            column.sortValue?.call(right) ?? column.value(right),
          );
          if (result != 0) return spec.ascending ? result : -result;
        }
        return 0;
      });
    }
    return rows;
  }

  Future<void> _configure() async {
    var order = [..._order];
    var visible = {..._visible};
    var frozen = {..._frozen};
    final widths = {..._widths};
    final previousFilters = {
      for (final entry in _filters.entries) entry.key: entry.value.text,
    };
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تنظیم ستون‌ها و فیلتر هر ستون'),
          content: SizedBox(
            width: 640,
            height: 520,
            child: ReorderableListView.builder(
              itemCount: order.length,
              onReorderItem: (oldIndex, newIndex) {
                setDialogState(() {
                  final id = order.removeAt(oldIndex);
                  order.insert(newIndex, id);
                });
              },
              itemBuilder: (context, index) {
                final id = order[index];
                final column = _column(id);
                return ListTile(
                  key: ValueKey(id),
                  leading: const Icon(Icons.drag_indicator_rounded),
                  title: Text(column.label),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (column.filterable)
                        TextField(
                          controller: _filters[id],
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'فیلتر این ستون',
                          ),
                        ),
                      Row(
                        children: [
                          const Text('عرض'),
                          Expanded(
                            child: Slider(
                              value: widths[id] ?? column.initialWidth,
                              min: column.minWidth,
                              max: column.maxWidth,
                              divisions:
                                  ((column.maxWidth - column.minWidth) / 10)
                                      .round(),
                              label: formatPersianInteger(
                                (widths[id] ?? column.initialWidth).round(),
                              ),
                              onChanged: (value) =>
                                  setDialogState(() => widths[id] = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: frozen.contains(id)
                            ? 'لغو ثابت‌سازی ستون'
                            : 'ثابت‌سازی ستون',
                        onPressed: () => setDialogState(() {
                          if (frozen.contains(id)) {
                            frozen.remove(id);
                          } else {
                            frozen.add(id);
                            visible.add(id);
                          }
                        }),
                        icon: Icon(
                          frozen.contains(id)
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                        ),
                      ),
                      Switch(
                        value: visible.contains(id),
                        onChanged: !column.canHide
                            ? null
                            : (value) => setDialogState(() {
                                if (value) {
                                  visible.add(id);
                                } else if (visible.length > 1) {
                                  visible.remove(id);
                                  frozen.remove(id);
                                }
                              }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (final controller in _filters.values) {
                  controller.clear();
                }
                setDialogState(() {
                  order = widget.columns.map((column) => column.id).toList();
                  visible = widget.columns
                      .where(
                        (column) => column.initiallyVisible || !column.canHide,
                      )
                      .map((column) => column.id)
                      .toSet();
                  frozen = {};
                  widths
                    ..clear()
                    ..addEntries(
                      widget.columns.map(
                        (column) => MapEntry(column.id, column.initialWidth),
                      ),
                    );
                });
              },
              child: const Text('بازنشانی'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('اعمال'),
            ),
          ],
        ),
      ),
    );
    if (applied == true) {
      setState(() {
        _order = order;
        _visible = visible;
        _frozen
          ..clear()
          ..addAll(frozen);
        _widths
          ..clear()
          ..addAll(widths);
      });
      await _saveLayout();
    } else {
      for (final entry in previousFilters.entries) {
        _filters[entry.key]?.text = entry.value;
      }
    }
  }

  Object _keyFor(T item) => widget.rowKey?.call(item) ?? identityHashCode(item);

  Future<void> _configureSorts() async {
    final selected = <String, bool>{
      for (final item in _sorts) item.columnId: item.ascending,
    };
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('مرتب‌سازی چندمرحله‌ای'),
          content: SizedBox(
            width: 520,
            height: 470,
            child: ListView(
              children: _order.map((id) {
                final column = _column(id);
                final enabled = selected.containsKey(id);
                return CheckboxListTile(
                  key: ValueKey(id),
                  value: enabled,
                  title: Text(column.label),
                  subtitle: enabled
                      ? Text(selected[id]! ? 'صعودی' : 'نزولی')
                      : null,
                  secondary: enabled
                      ? IconButton(
                          tooltip: selected[id]! ? 'نزولی شود' : 'صعودی شود',
                          onPressed: () => setDialogState(
                            () => selected[id] = !selected[id]!,
                          ),
                          icon: Icon(
                            selected[id]!
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                          ),
                        )
                      : const Icon(Icons.drag_indicator_rounded),
                  onChanged: (value) => setDialogState(() {
                    value == true ? selected[id] = true : selected.remove(id);
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDialogState(selected.clear),
              child: const Text('پاک‌کردن'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('اعمال'),
            ),
          ],
        ),
      ),
    );
    if (applied != true) return;
    setState(() {
      _sorts = _order
          .where(selected.containsKey)
          .map((id) => _CrmSortSpec(id, selected[id]!))
          .toList();
      _sortColumnId = _sorts.firstOrNull?.columnId;
      _sortAscending = _sorts.firstOrNull?.ascending ?? true;
      _page = 0;
    });
    await _saveLayout();
  }

  Future<void> _saveFilterPreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ذخیره فیلتر پرکاربرد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'نام فیلتر'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_filterPresetKey);
    final presets = existing == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(existing) as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
    presets.removeWhere((item) => item['name'] == name.trim());
    presets.add({
      'name': name.trim(),
      'search': _globalSearch.text,
      'filters': {
        for (final entry in _filters.entries) entry.key: entry.value.text,
      },
    });
    await preferences.setString(_filterPresetKey, jsonEncode(presets));
    if (mounted) {
      showCrmNotice(
        context,
        'فیلتر «${name.trim()}» ذخیره شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _openFilterPresets() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_filterPresetKey);
    final presets = raw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فیلترهای ذخیره‌شده'),
        content: SizedBox(
          width: 520,
          height: 380,
          child: presets.isEmpty
              ? const Center(child: Text('هنوز فیلتری ذخیره نشده است.'))
              : ListView.builder(
                  itemCount: presets.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.filter_alt_outlined),
                    title: Text(presets[index]['name']?.toString() ?? ''),
                    onTap: () => Navigator.pop(context, presets[index]),
                    trailing: IconButton(
                      tooltip: 'حذف قالب فیلتر',
                      onPressed: () async {
                        presets.removeAt(index);
                        await preferences.setString(
                          _filterPresetKey,
                          jsonEncode(presets),
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    final filters = (selected['filters'] as Map? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
    setState(() {
      _globalSearch.text = selected['search']?.toString() ?? '';
      for (final entry in _filters.entries) {
        entry.value.text = filters[entry.key] ?? '';
      }
      _page = 0;
    });
  }

  Future<void> _resetLayout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_preferenceKey);
    setState(() {
      _order = widget.columns.map((column) => column.id).toList();
      _visible = widget.columns
          .where((column) => column.initiallyVisible || !column.canHide)
          .map((column) => column.id)
          .toSet();
      _widths
        ..clear()
        ..addEntries(
          widget.columns.map(
            (column) => MapEntry(column.id, column.initialWidth),
          ),
        );
      _frozen.clear();
      _sorts = widget.initialSortColumnId == null
          ? const []
          : [
              _CrmSortSpec(
                widget.initialSortColumnId!,
                widget.initialSortAscending,
              ),
            ];
      _sortColumnId = widget.initialSortColumnId;
      _sortAscending = widget.initialSortAscending;
      _pageSize = 25;
      _page = 0;
      _selected.clear();
      _globalSearch.clear();
      for (final controller in _filters.values) {
        controller.clear();
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _globalSearch.clear();
      for (final controller in _filters.values) {
        controller.clear();
      }
      _page = 0;
    });
  }

  Future<void> _copyRows(List<T> rows, List<CrmTableColumn<T>> columns) {
    final selectedRows = rows
        .where((item) => _selected.contains(_keyFor(item)))
        .toList();
    final source = selectedRows.isEmpty ? rows : selectedRows;
    final text = <String>[
      columns.map((column) => column.label).join('\t'),
      ...source.map(
        (item) => columns.map((column) => column.value(item)).join('\t'),
      ),
    ].join('\n');
    return Clipboard.setData(ClipboardData(text: text));
  }

  Widget _buildTable(
    List<CrmTableColumn<T>> columns,
    List<T> rows, {
    required int rowOffset,
    required bool includeRowNumbers,
    required bool includeSelection,
  }) {
    final primarySort = _sorts.firstOrNull;
    final localSortIndex = primarySort == null
        ? -1
        : columns.indexWhere((column) => column.id == primarySort.columnId);
    final hasRowNumbers =
        includeRowNumbers &&
        widget.showRowNumbers &&
        !widget.columns.any((column) => column.id == 'row');
    final sortIndex = localSortIndex < 0
        ? null
        : localSortIndex + (hasRowNumbers ? 1 : 0);
    final scheme = Theme.of(context).colorScheme;
    return DataTable(
      showCheckboxColumn: includeSelection && widget.enableSelection,
      horizontalMargin: 12,
      columnSpacing: 12,
      dataRowMinHeight: 56,
      dataRowMaxHeight: 56,
      headingRowHeight: 56,
      headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerHighest),
      sortColumnIndex: sortIndex,
      sortAscending: primarySort?.ascending ?? true,
      columns: [
        if (hasRowNumbers)
          const DataColumn(
            label: SizedBox(width: 42, child: Text('ردیف')),
            numeric: true,
          ),
        ...columns.map((column) {
          final width = _widths[column.id] ?? column.initialWidth;
          return DataColumn(
            label: SizedBox(
              width: width,
              child: Row(
                children: [
                  if (_frozen.contains(column.id)) ...[
                    const Icon(Icons.push_pin_rounded, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(column.label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            numeric: column.numeric,
            onSort: column.sortValue == null && !column.filterable
                ? null
                : (_, ascending) {
                    setState(() {
                      _sorts = [_CrmSortSpec(column.id, ascending)];
                      _sortColumnId = column.id;
                      _sortAscending = ascending;
                      _page = 0;
                    });
                    unawaited(_saveLayout());
                  },
          );
        }),
      ],
      rows: rows.asMap().entries.map((entry) {
        final item = entry.value;
        final key = _keyFor(item);
        final selected = _selected.contains(key);
        final color = widget.rowColor?.call(item) ?? _defaultRowColor(item);
        return DataRow(
          selected: selected,
          color: color == null ? null : WidgetStatePropertyAll(color),
          onSelectChanged: includeSelection && widget.enableSelection
              ? (value) => setState(
                  () => value == true
                      ? _selected.add(key)
                      : _selected.remove(key),
                )
              : null,
          cells: [
            if (hasRowNumbers)
              DataCell(
                SizedBox(
                  width: 42,
                  child: Text(
                    formatPersianInteger(rowOffset + entry.key + 1),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ...columns.map((column) {
              final width = _widths[column.id] ?? column.initialWidth;
              return DataCell(
                SizedBox(
                  width: width,
                  child: ClipRect(
                    child: Align(
                      alignment: column.numeric
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child:
                          column.cell?.call(context, item) ??
                          Text(
                            column.value(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Color? _defaultRowColor(T item) {
    final statusColumn = widget.columns
        .where(
          (column) =>
              column.id == 'status' ||
              column.id == 'stage' ||
              column.id == 'priority',
        )
        .firstOrNull;
    final status = statusColumn?.value(item).toLowerCase() ?? '';
    final scheme = Theme.of(context).colorScheme;
    if (status.contains('ناموفق') ||
        status.contains('از دست') ||
        status.contains('منقضی')) {
      return scheme.errorContainer.withValues(alpha: 0.22);
    }
    if (status.contains('موفق') ||
        status.contains('برنده') ||
        status.contains('تکمیل')) {
      return Colors.green.withValues(alpha: 0.08);
    }
    if (status.contains('بالا') || status.contains('پیگیری')) {
      return scheme.tertiaryContainer.withValues(alpha: 0.18);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final columns = _order.where(_visible.contains).map(_column).toList();
    final rows = _filteredRows();
    final pageCount = math.max(1, (rows.length / _pageSize).ceil());
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _pageSize;
    final pageRows = rows.skip(start).take(_pageSize).toList();
    final frozenColumns = columns
        .where((column) => _frozen.contains(column.id))
        .toList();
    final scrollingColumns = columns
        .where((column) => !_frozen.contains(column.id))
        .toList();
    final hasFilters =
        _globalSearch.text.isNotEmpty ||
        _filters.values.any((controller) => controller.text.isNotEmpty);
    final allSelected =
        rows.isNotEmpty &&
        rows.every((item) => _selected.contains(_keyFor(item)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showToolbar) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _globalSearch,
                  onChanged: (_) => setState(() => _page = 0),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'جستجو داخل جدول',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _configure,
                icon: const Icon(Icons.view_column_outlined),
                label: const Text('ستون‌ها و چیدمان'),
              ),
              OutlinedButton.icon(
                onPressed: _configureSorts,
                icon: const Icon(Icons.sort_rounded),
                label: Text(
                  _sorts.length > 1
                      ? 'مرتب‌سازی ${formatPersianInteger(_sorts.length)} مرحله‌ای'
                      : 'مرتب‌سازی چندمرحله‌ای',
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'فیلترهای پرکاربرد',
                onSelected: (value) => switch (value) {
                  'save' => _saveFilterPreset(),
                  'load' => _openFilterPresets(),
                  _ => null,
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'save', child: Text('ذخیره فیلتر فعلی')),
                  PopupMenuItem(
                    value: 'load',
                    child: Text('فیلترهای ذخیره‌شده'),
                  ),
                ],
                child: const Chip(
                  avatar: Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text('فیلترها'),
                ),
              ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('پاک‌کردن فیلترها'),
                ),
              if (widget.enableSelection)
                FilterChip(
                  selected: allSelected,
                  label: const Text('انتخاب همه رکوردها'),
                  avatar: const Icon(Icons.select_all_rounded, size: 18),
                  onSelected: (value) => setState(() {
                    if (value) {
                      _selected.addAll(rows.map(_keyFor));
                    } else {
                      _selected.removeAll(rows.map(_keyFor));
                    }
                  }),
                ),
              OutlinedButton.icon(
                onPressed: rows.isEmpty
                    ? null
                    : () async {
                        await _copyRows(rows, columns);
                        if (context.mounted) {
                          showCrmNotice(
                            context,
                            _selected.isEmpty
                                ? 'رکوردهای نمایشی کپی شدند.'
                                : 'رکوردهای انتخاب‌شده کپی شدند.',
                            type: CrmNoticeType.success,
                          );
                        }
                      },
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('کپی'),
              ),
              TextButton.icon(
                onPressed: _resetLayout,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('چیدمان پیش‌فرض'),
              ),
              Text(
                '${formatPersianInteger(rows.length)} ردیف',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (frozenColumns.isEmpty || scrollingColumns.isEmpty)
          CrmTableScroll(
            child: _buildTable(
              columns,
              pageRows,
              rowOffset: start,
              includeRowNumbers: true,
              includeSelection: true,
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTable(
                frozenColumns,
                pageRows,
                rowOffset: start,
                includeRowNumbers: true,
                includeSelection: true,
              ),
              Expanded(
                child: CrmTableScroll(
                  child: _buildTable(
                    scrollingColumns,
                    pageRows,
                    rowOffset: start,
                    includeRowNumbers: false,
                    includeSelection: false,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعداد در صفحه: '),
                DropdownButton<int>(
                  value: _pageSize,
                  items: const [10, 25, 50, 100]
                      .map(
                        (size) => DropdownMenuItem(
                          value: size,
                          child: Text(formatPersianInteger(size)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _pageSize = value;
                      _page = 0;
                    });
                    unawaited(_saveLayout());
                  },
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'صفحه قبل',
                  onPressed: _page <= 0 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Text(
                  'صفحه ${formatPersianInteger(_page + 1)} از ${formatPersianInteger(pageCount)}',
                ),
                IconButton(
                  tooltip: 'صفحه بعد',
                  onPressed: _page >= pageCount - 1
                      ? null
                      : () => setState(() => _page++),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static int _compare(Object? left, Object? right) {
    if (left is num && right is num) return left.compareTo(right);
    if (left is DateTime && right is DateTime) return left.compareTo(right);
    return left.toString().toLowerCase().compareTo(
      right.toString().toLowerCase(),
    );
  }
}

class RecordActions extends StatelessWidget {
  const RecordActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.editTooltip = 'ویرایش',
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: editTooltip,
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'حذف',
          color: Theme.of(context).colorScheme.error,
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context, {
  required String label,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('انتقال به حذف‌شده‌ها'),
          content: Text(
            '«$label» از فهرست پنهان و با سرور همگام‌سازی می‌شود. ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('انصراف'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('حذف'),
            ),
          ],
        ),
      ) ??
      false;
}

class SoftEntrance extends StatelessWidget {
  const SoftEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : duration,
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class SoftPageSwitcher extends StatelessWidget {
  const SoftPageSwitcher({
    super.key,
    required this.pageId,
    required this.child,
  });

  final Object pageId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: disabled ? Duration.zero : const Duration(milliseconds: 240),
      reverseDuration: disabled
          ? Duration.zero
          : const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.015, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(pageId), child: child),
    );
  }
}

class CrmPageHeader extends StatelessWidget {
  const CrmPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Wrap(spacing: 10, runSpacing: 8, children: actions),
      ],
    );
  }
}

class CrmPageToolbar extends StatelessWidget {
  const CrmPageToolbar({
    super.key,
    this.onNew,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.onReport,
    this.onExportExcel,
    this.onImportExcel,
    this.onTools,
    this.onRefresh,
    this.onSearch,
    this.onAdvancedFilter,
    this.extraActions = const [],
  });

  final VoidCallback? onNew;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onView;
  final VoidCallback? onReport;
  final VoidCallback? onExportExcel;
  final VoidCallback? onImportExcel;
  final VoidCallback? onTools;
  final VoidCallback? onRefresh;
  final VoidCallback? onSearch;
  final VoidCallback? onAdvancedFilter;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    Widget action(String label, IconData icon, VoidCallback? callback) {
      return OutlinedButton.icon(
        onPressed: callback,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            action('جدید', Icons.add_rounded, onNew),
            action('ویرایش', Icons.edit_outlined, onEdit),
            action('حذف', Icons.delete_outline_rounded, onDelete),
            action('نمایش', Icons.visibility_outlined, onView),
            action('گزارش و چاپ', Icons.print_outlined, onReport),
            action('خروجی Excel', Icons.file_download_outlined, onExportExcel),
            action('ورود Excel', Icons.file_upload_outlined, onImportExcel),
            action('ابزار', Icons.handyman_outlined, onTools),
            action('بروزرسانی', Icons.refresh_rounded, onRefresh),
            action('جستجو', Icons.search_rounded, onSearch),
            action(
              'فیلتر پیشرفته',
              Icons.filter_alt_outlined,
              onAdvancedFilter,
            ),
            ...extraActions,
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SoftEntrance(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.change,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? change;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoftEntrance(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        toPersianDigits(value),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (change != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          change!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xff12966b),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});

  final String label;

  Color _color() {
    if (label == 'موفق' || label == 'فعال' || label == 'فروش انجام شد') {
      return const Color(0xff12966b);
    }
    if (label == 'پیگیری' || label == 'مشتری بالقوه') {
      return const Color(0xffe58a00);
    }
    if (label == 'ناموفق' || label == 'غیر فعال') {
      return const Color(0xffd84b4b);
    }
    return const Color(0xff52627a);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String compactMoney(int amount) {
  return formatCompactMoney(amount);
}

String compactDate(DateTime date) {
  return formatJalaliDate(date);
}
