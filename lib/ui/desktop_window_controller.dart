import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/crm_store.dart';

/// Owns the Windows-only window lifecycle and the notification-area menu.
/// On non-Windows targets it is a transparent wrapper around [child].
class DesktopWindowController extends StatefulWidget {
  const DesktopWindowController({
    super.key,
    required this.store,
    required this.child,
  });

  final CrmStore store;
  final Widget child;

  @override
  State<DesktopWindowController> createState() =>
      _DesktopWindowControllerState();
}

class _DesktopWindowControllerState extends State<DesktopWindowController>
    with WindowListener, TrayListener {
  bool _initialized = false;
  bool _closeDialogVisible = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) unawaited(_initializeWindowsIntegration());
  }

  Future<void> _initializeWindowsIntegration() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      await trayManager.setIcon('windows/runner/resources/app_icon.ico');
      await trayManager.setToolTip('فروش‌یار CRM');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open_window', label: 'باز کردن برنامه'),
            MenuItem.separator(),
            MenuItem(key: 'exit_app', label: 'بستن کامل برنامه'),
          ],
        ),
      );
      _initialized = true;
    } catch (_) {
      // The primary window still has a safe close dialog if the tray cannot
      // initialize, for example on a locked-down corporate Windows profile.
      _initialized = false;
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_restoreWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open_window':
        unawaited(_restoreWindow());
        return;
      case 'exit_app':
        unawaited(_exitApplication());
        return;
    }
  }

  Future<void> _handleWindowClose() async {
    if (_exiting || !Platform.isWindows) return;
    switch (widget.store.closeBehavior) {
      case CloseBehavior.minimizeToTray:
        await _hideToTray();
      case CloseBehavior.exit:
        await _exitApplication();
      case CloseBehavior.ask:
        await _askCloseBehavior();
    }
  }

  Future<void> _askCloseBehavior() async {
    if (_closeDialogVisible || !mounted) return;
    _closeDialogVisible = true;
    try {
      final choice = await showDialog<CloseBehavior>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.power_settings_new_rounded),
          title: const Text('بستن فروش‌یار CRM'),
          content: const Text(
            'می‌خواهید برنامه در پس‌زمینه و ناحیهٔ اعلان ویندوز بماند یا کاملاً بسته شود؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(CloseBehavior.minimizeToTray),
              icon: const Icon(Icons.minimize_rounded),
              label: const Text('رفتن به Tray'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(CloseBehavior.exit),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('خروج کامل'),
            ),
          ],
        ),
      );
      if (choice == CloseBehavior.minimizeToTray) {
        await _hideToTray();
      } else if (choice == CloseBehavior.exit) {
        await _exitApplication();
      }
    } finally {
      _closeDialogVisible = false;
    }
  }

  Future<void> _hideToTray() async {
    if (!_initialized) {
      await _exitApplication();
      return;
    }
    await windowManager.hide();
  }

  Future<void> _restoreWindow() async {
    if (!Platform.isWindows) return;
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitApplication() async {
    if (_exiting || !Platform.isWindows) return;
    _exiting = true;
    await windowManager.setPreventClose(false);
    if (_initialized) await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
