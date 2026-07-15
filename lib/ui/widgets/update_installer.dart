import 'package:flutter/material.dart';

import '../../core/persian_format.dart';
import '../../core/update_service.dart';

Future<void> showCrmUpdateInstaller(
  BuildContext context, {
  required UpdateService service,
  required AppUpdate update,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _UpdateInstallerDialog(service: service, update: update),
  );
}

class _UpdateInstallerDialog extends StatefulWidget {
  const _UpdateInstallerDialog({required this.service, required this.update});

  final UpdateService service;
  final AppUpdate update;

  @override
  State<_UpdateInstallerDialog> createState() => _UpdateInstallerDialogState();
}

class _UpdateInstallerDialogState extends State<_UpdateInstallerDialog> {
  UpdateDownloadProgress _progress = const UpdateDownloadProgress.initial();
  Object? _error;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
      _progress = const UpdateDownloadProgress.initial();
    });
    try {
      await widget.service.downloadAndInstall(
        widget.update,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = error;
        });
      }
    }
  }

  String _size(int bytes) {
    if (bytes <= 0) return 'نامشخص';
    final megabytes = bytes / (1024 * 1024);
    return '${toPersianDigits(megabytes.toStringAsFixed(1))} مگابایت';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _progress.fraction;
    final percent = fraction == null
        ? null
        : toPersianDigits((fraction * 100).round().toString());
    return PopScope(
      canPop: !_running,
      child: AlertDialog(
        title: Text('دریافت نسخهٔ ${widget.update.version}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error == null) ...[
                Text(
                  _progress.verifying
                      ? 'دانلود کامل شد؛ در حال بررسی صحت SHA-256 بسته...'
                      : 'بستهٔ به‌روزرسانی داخل برنامه دانلود می‌شود.',
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress.verifying ? null : fraction,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _progress.verifying
                          ? 'اعتبارسنجی بسته'
                          : '${_size(_progress.receivedBytes)} از ${_size(_progress.totalBytes)}',
                    ),
                    if (percent != null && !_progress.verifying)
                      Text('$percent٪'),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'پس از تأیید بسته، برنامه خودکار بسته می‌شود، فایل‌ها جایگزین می‌شوند و نسخهٔ جدید دوباره اجرا خواهد شد.',
                ),
              ] else ...[
                Text(
                  'دریافت یا نصب به‌روزرسانی انجام نشد:\n$_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: _error == null
            ? const []
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('بستن'),
                ),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تلاش دوباره'),
                ),
              ],
      ),
    );
  }
}
