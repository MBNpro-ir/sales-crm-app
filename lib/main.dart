import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/crm_store.dart';
import 'ui/app_shell.dart';
import 'ui/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = CrmStore();
  await store.initialize();
  runApp(CrmApp(store: store));
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
          home: store.hasSession
              ? AppShell(store: store)
              : LoginPage(store: store),
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
