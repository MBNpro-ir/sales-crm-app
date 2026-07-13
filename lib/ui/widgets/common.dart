import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Normalizes Persian/Arabic/Latin digits, rejects non-numeric characters and
/// renders a live three-digit grouping separator. Stored values should be read
/// with [parsePersianInt], which understands this representation.
class PersianNumberFormatter extends TextInputFormatter {
  const PersianNumberFormatter({this.allowNegative = false});

  final bool allowNegative;

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
    final number = int.tryParse(normalized) ?? 0;
    final value = formatPersianInteger(number, grouping: true);
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

  final List<ResponsiveFormField> children;
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
          children: children
              .map(
                (item) => SizedBox(
                  width: item.full ? constraints.maxWidth : width,
                  child: item,
                ),
              )
              .toList(),
        );
      },
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
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? change;

  @override
  Widget build(BuildContext context) {
    return SoftEntrance(
      child: Card(
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
