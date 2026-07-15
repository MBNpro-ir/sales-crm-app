import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/crm_store.dart';
import '../../core/models.dart';
import 'common.dart';

const crmAttachmentExtensions = <String>[
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'csv',
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'zip',
  'rar',
  '7z',
];

Future<void> showCrmAttachmentManager(
  BuildContext context, {
  required CrmStore store,
  required String entityType,
  required String entityId,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _AttachmentManagerDialog(
      store: store,
      entityType: entityType,
      entityId: entityId,
      title: title,
    ),
  );
}

class _AttachmentManagerDialog extends StatefulWidget {
  const _AttachmentManagerDialog({
    required this.store,
    required this.entityType,
    required this.entityId,
    required this.title,
  });

  final CrmStore store;
  final String entityType;
  final String entityId;
  final String title;

  @override
  State<_AttachmentManagerDialog> createState() =>
      _AttachmentManagerDialogState();
}

class _AttachmentManagerDialogState extends State<_AttachmentManagerDialog> {
  bool _busy = false;

  List<CrmAttachment> get _items =>
      widget.store.attachmentsFor(widget.entityType, widget.entityId);

  Future<void> _add() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'فایل‌های مجاز', extensions: crmAttachmentExtensions),
      ],
    );
    if (file == null || !mounted) return;
    final extension = p
        .extension(file.name)
        .replaceFirst('.', '')
        .toLowerCase();
    if (!crmAttachmentExtensions.contains(extension)) {
      showCrmNotice(
        context,
        'فرمت این فایل برای پیوست مجاز نیست.',
        type: CrmNoticeType.error,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.addAttachment(
        entityType: widget.entityType,
        entityId: widget.entityId,
        fileName: file.name,
        extension: extension,
        bytes: await file.readAsBytes(),
      );
      if (mounted) {
        showCrmNotice(
          context,
          'فایل پیوست شد و برای همگام‌سازی در صف قرار گرفت.',
          type: CrmNoticeType.success,
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        showCrmNotice(context, error.message, type: CrmNoticeType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Uint8List _bytes(CrmAttachment item) =>
      Uint8List.fromList(base64Decode(item.contentBase64));

  Future<void> _download(CrmAttachment item) async {
    final location = await getSaveLocation(
      suggestedName: item.fileName,
      acceptedTypeGroups: [
        XTypeGroup(
          label: item.extension.toUpperCase(),
          extensions: [item.extension],
        ),
      ],
    );
    if (location == null) return;
    await XFile.fromData(
      _bytes(item),
      name: item.fileName,
    ).saveTo(location.path);
    if (mounted) {
      showCrmNotice(
        context,
        'فایل در مسیر انتخاب‌شده ذخیره شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _view(CrmAttachment item) async {
    final directory = Directory(
      p.join(Directory.systemTemp.path, 'SalesCrmAttachments'),
    );
    await directory.create(recursive: true);
    final safeName = item.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(directory.path, '${item.id}-$safeName'));
    await file.writeAsBytes(_bytes(item), flush: true);
    await Process.start('explorer.exe', [
      file.path,
    ], mode: ProcessStartMode.detached);
  }

  Future<void> _delete(CrmAttachment item) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف پیوست'),
            content: Text('فایل «${item.fileName}» حذف شود؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.store.deleteAttachment(item);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('فایل‌های پیوست — ${widget.title}'),
      content: SizedBox(
        width: 720,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _add,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file_rounded),
                  label: const Text('پیوست فایل'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'PDF، Word، Excel، تصویر و فایل فشرده — حداکثر ۱۵ مگابایت',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _items.isEmpty
                  ? const EmptyState(
                      icon: Icons.attach_file_outlined,
                      title: 'فایل پیوستی وجود ندارد',
                      message: 'برای این رکورد هنوز فایلی ثبت نشده است.',
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(item.fileName),
                          subtitle: Text(
                            '${_formatBytes(item.sizeBytes)} • ${item.uploadedBy} • ${formatJalaliDate(item.updatedAt, includeTime: true)}',
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                tooltip: 'مشاهده',
                                onPressed: () => _view(item),
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                              IconButton(
                                tooltip: 'دانلود',
                                onPressed: () => _download(item),
                                icon: const Icon(Icons.download_outlined),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                onPressed: () => _delete(item),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${formatPersianInteger(bytes)} بایت';
    if (bytes < 1024 * 1024) {
      return '${formatPersianInteger((bytes / 1024).round())} کیلوبایت';
    }
    return '${toPersianDigits((bytes / (1024 * 1024)).toStringAsFixed(1))} مگابایت';
  }
}

Future<void> showCrmAuditLog(
  BuildContext context, {
  required CrmStore store,
  required String entityType,
  required String entityId,
  required String title,
}) {
  final entries = store.auditFor(entityType, entityId);
  const encoder = JsonEncoder.withIndent('  ');
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('تاریخچه تغییرات — $title'),
      content: SizedBox(
        width: 820,
        height: 540,
        child: entries.isEmpty
            ? const EmptyState(
                icon: Icons.history_toggle_off_rounded,
                title: 'تاریخچه‌ای ثبت نشده است',
                message:
                    'تغییرات بعدی همراه با کاربر، تاریخ و مقادیر ثبت می‌شوند.',
              )
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ExpansionTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(entry.action),
                    subtitle: Text(
                      '${entry.userName} • ${formatJalaliDate(entry.updatedAt, includeTime: true)}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    children: [
                      if (entry.oldValue.isNotEmpty)
                        _AuditValue(
                          title: 'مقدار قبلی',
                          value: encoder.convert(entry.oldValue),
                        ),
                      if (entry.newValue.isNotEmpty)
                        _AuditValue(
                          title: 'مقدار جدید',
                          value: encoder.convert(entry.newValue),
                        ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
      ],
    ),
  );
}

class _AuditValue extends StatelessWidget {
  const _AuditValue({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SelectableText('$title:\n$value'),
      ),
    );
  }
}
