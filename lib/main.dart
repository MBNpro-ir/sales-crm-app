import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'core/crm_store.dart';
import 'core/update_service.dart';
import 'ui/app_shell.dart';
import 'ui/widgets/update_installer.dart';
import 'ui/desktop_window_controller.dart';
import 'ui/login_page.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await WindowsSingleInstance.ensureSingleInstance(
      arguments,
      'sales_crm_mbnpro_ir',
      onSecondWindow: (_) => unawaited(_restoreExistingWindow()),
    );
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(1024, 680),
        center: true,
        skipTaskbar: false,
        title: 'فروش‌یار CRM',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  final store = CrmStore();
  await store.initialize();
  runApp(CrmApp(store: store));
}

Future<void> _restoreExistingWindow() async {
  if (!Platform.isWindows) return;
  if (await windowManager.isMinimized()) await windowManager.restore();
  await windowManager.show();
  await windowManager.focus();
}

class CrmApp extends StatelessWidget {
  const CrmApp({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        return MaterialApp(
          title: 'فروش‌یار CRM',
          debugShowCheckedModeBanner: false,
          locale: const Locale('fa', 'IR'),
          supportedLocales: const [Locale('fa', 'IR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          themeMode: store.themeMode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(store.textScale),
                boldText: store.boldText,
                highContrast: store.highContrast,
                disableAnimations: store.reduceMotion,
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: UpdateCoordinator(
            store: store,
            child: DesktopWindowController(
              store: store,
              child: store.hasSession
                  ? AppShell(store: store)
                  : LoginPage(store: store),
            ),
          ),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final seed = switch (store.accent) {
      CrmAccent.ocean => const Color(0xff0b63ce),
      CrmAccent.emerald => const Color(0xff087f5b),
      CrmAccent.violet => const Color(0xff7044c4),
      CrmAccent.amber => const Color(0xffb76800),
      CrmAccent.rose => const Color(0xffb63a5d),
    };
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final highContrast = store.highContrast;
    final outline = highContrast
        ? (brightness == Brightness.dark ? Colors.white : Colors.black)
        : scheme.outlineVariant;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Vazirmatn',
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff6f8fc)
          : const Color(0xff10131a),
      materialTapTargetSize: store.largeTouchTargets
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      visualDensity: store.largeTouchTargets
          ? VisualDensity.standard
          : VisualDensity.compact,
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.light
            ? Colors.white
            : scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline, width: highContrast ? 1.5 : 0.6),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xfff4f6fa)
            : Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline, width: highContrast ? 1.5 : 0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline, width: highContrast ? 1.5 : 0),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: store.largeTouchTargets ? 18 : 14,
        ),
      ),
      focusColor: seed.withValues(alpha: 0.18),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        textStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontFamily: 'Vazirmatn',
        ),
      ),
      pageTransitionsTheme: store.reduceMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
              },
            )
          : null,
    );
  }
}

class UpdateCoordinator extends StatefulWidget {
  const UpdateCoordinator({
    super.key,
    required this.store,
    required this.child,
  });

  final CrmStore store;
  final Widget child;

  @override
  State<UpdateCoordinator> createState() => _UpdateCoordinatorState();
}

class _UpdateCoordinatorState extends State<UpdateCoordinator> {
  final _updates = UpdateService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutomatically());
  }

  Future<void> _checkAutomatically() async {
    if (!widget.store.automaticUpdates) return;
    try {
      final update = await _updates.checkForUpdate();
      if (update == null || !mounted) return;
      final install = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('به‌روزرسانی جدید آماده است'),
          content: Text(
            'نسخهٔ ${update.version} آماده دریافت و نصب است. برنامه پس از پایان نصب دوباره باز می‌شود.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('بعداً'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('به‌روزرسانی اکنون'),
            ),
          ],
        ),
      );
      if (install == true && mounted) {
        await showCrmUpdateInstaller(
          context,
          service: _updates,
          update: update,
        );
      }
    } catch (_) {
      // A failed background check must never prevent normal CRM work.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
