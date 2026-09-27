import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text.dart';
import 'tokens.dart';

class _SlideFadeBuilder extends PageTransitionsBuilder {
  const _SlideFadeBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return opSlideFade(animation, child);
  }
}

/// The one page transition used across the app: a short slide from the right with a fade.
Widget opSlideFade(Animation<double> animation, Widget child) {
  final curved = CurvedAnimation(parent: animation, curve: OpMotion.curve);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(curved),
      child: child,
    ),
  );
}

ThemeData buildOpTheme() {
  final scheme = const ColorScheme.light(
    primary: OpColors.forest,
    onPrimary: OpColors.paper,
    secondary: OpColors.fern,
    onSecondary: OpColors.paper,
    error: OpColors.alarm,
    surface: OpColors.paper,
    onSurface: OpColors.ink,
    surfaceContainerLowest: OpColors.card,
    surfaceContainerLow: OpColors.card,
    surfaceContainer: OpColors.card,
    surfaceContainerHigh: OpColors.card,
    surfaceContainerHighest: OpColors.paperDeep,
    outline: OpColors.line,
    outlineVariant: OpColors.line,
  );

  final controlShape = RoundedRectangleBorder(borderRadius: OpRadius.controlAll);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: OpColors.paper,
    fontFamily: 'IBMPlexSans',
    fontFamilyFallback: const ['NotoSansTelugu'],
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displaySmall: OpText.display,
      headlineMedium: OpText.title,
      headlineSmall: OpText.title,
      titleLarge: OpText.heading,
      titleMedium: OpText.lead,
      titleSmall: OpText.bodyStrong,
      bodyLarge: OpText.body,
      bodyMedium: OpText.body,
      bodySmall: OpText.small,
      labelLarge: OpText.button,
      labelMedium: OpText.smallStrong,
      labelSmall: OpText.label,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _SlideFadeBuilder(),
      TargetPlatform.iOS: _SlideFadeBuilder(),
      TargetPlatform.windows: _SlideFadeBuilder(),
      TargetPlatform.macOS: _SlideFadeBuilder(),
      TargetPlatform.linux: _SlideFadeBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: OpColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: OpColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: OpText.heading,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(color: OpColors.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OpColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      hintStyle: OpText.body.copyWith(color: OpColors.inkFaint),
      labelStyle: OpText.body.copyWith(color: OpColors.inkSoft),
      floatingLabelStyle: OpText.smallStrong.copyWith(color: OpColors.fern),
      border: OutlineInputBorder(borderRadius: OpRadius.controlAll, borderSide: const BorderSide(color: OpColors.lineSoft)),
      enabledBorder: OutlineInputBorder(
          borderRadius: OpRadius.controlAll, borderSide: const BorderSide(color: OpColors.line, width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: OpRadius.controlAll, borderSide: const BorderSide(color: OpColors.fern, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: OpRadius.controlAll, borderSide: const BorderSide(color: OpColors.alarm, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: OpRadius.controlAll, borderSide: const BorderSide(color: OpColors.alarm, width: 2)),
      errorStyle: OpText.small.copyWith(color: OpColors.alarm),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: OpColors.forest,
        foregroundColor: OpColors.paper,
        minimumSize: const Size.fromHeight(OpSpace.buttonHeight),
        shape: controlShape,
        textStyle: OpText.button,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: OpColors.ink,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: OpColors.ink, width: 1.5),
        shape: controlShape,
        textStyle: OpText.smallStrong.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: OpColors.fern,
        minimumSize: const Size(48, 48),
        shape: controlShape,
        textStyle: OpText.smallStrong.copyWith(fontSize: 15),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: OpColors.inkSoft, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? OpColors.forest : null),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? OpColors.paper : OpColors.inkSoft),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? OpColors.fern : OpColors.paperDeep),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? OpColors.fern : OpColors.line),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: OpColors.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: OpColors.line,
      shape: RoundedRectangleBorder(borderRadius: OpRadius.sheetTop),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: OpColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OpRadius.sheet)),
      titleTextStyle: OpText.heading,
      contentTextStyle: OpText.body,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: OpColors.forest,
      contentTextStyle: OpText.bodyStrong.copyWith(color: OpColors.paper),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: OpRadius.controlAll),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      elevation: 6,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: OpColors.fern),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: OpColors.ink, borderRadius: OpRadius.smallAll),
      textStyle: OpText.small.copyWith(color: OpColors.paper),
    ),
  );
}
