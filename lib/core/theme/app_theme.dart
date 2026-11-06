import 'package:flutter/material.dart';

/// Ardent Networks design tokens, matching the Starlink web portal
/// (ardent_starlink_client: app/assets/css/tokens.css + main.css).
class AppColors {
  AppColors._();

  // Brand
  static const brand = Color(0xFFE90408); // main CTA, focus, key accent
  static const brandHover = Color(0xFFC80307);
  static const crimson = Color(0xFFC6324C);
  static const salmon = Color(0xFFFF5969);
  static const navy = Color(0xFF133341); // headers, sidebar, secondary button
  static const navyLight = Color(0xFF1E4D62);
  static const navyDark = Color(0xFF0C2029);

  // Ink
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF333333);
  static const inkMuted = Color(0xFF666666);
  static const inkFaint = Color(0xFF888888);

  // Surfaces
  static const paper = Color(0xFFFFFFFF);
  static const paperSubtle = Color(0xFFF8F8F8); // page background
  static const paperMuted = Color(0xFFEFEFEF);

  // Lines
  static const line = Color(0xFFD7D7D7);
  static const lineSoft = Color(0xFFEFEFEF);
  static const lineStrong = Color(0xFFB0B0B0);

  // Status
  static const success = Color(0xFF10B981);
  static const successInk = Color(0xFF047857);
  static const warning = Color(0xFFF59E0B);
  static const warningInk = Color(0xFFB45309);
  static const info = Color(0xFF3B82F6);
  static const infoInk = Color(0xFF1D4ED8);
  static const danger = Color(0xFFE90408);
  static const dangerInk = Color(0xFFC40307);
}

/// Radii used by the web portal.
class AppRadius {
  AppRadius._();
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0; // inputs, cards
  static const xl = 24.0;
}

/// Soft navy shadows ("shadow-sm/md/lg" on the web).
class AppShadows {
  AppShadows._();
  static const sm = [
    BoxShadow(color: Color(0x0F133341), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const md = [
    BoxShadow(color: Color(0x17133341), blurRadius: 20, offset: Offset(0, 6)),
  ];
  static const lg = [
    BoxShadow(color: Color(0x1F133341), blurRadius: 44, offset: Offset(0, 16)),
  ];
  // Red glow under the primary button.
  static const brandButton = [
    BoxShadow(color: Color(0x38E90408), blurRadius: 10, offset: Offset(0, 3)),
  ];
}

class AppTheme {
  AppTheme._();

  static const fontFamily = 'Montserrat';

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.navy,
      onSecondary: Colors.white,
      tertiary: AppColors.crimson,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      surfaceContainerLowest: AppColors.paper,
      surfaceContainerLow: AppColors.paperSubtle,
      surfaceContainer: AppColors.paperSubtle,
      surfaceContainerHigh: AppColors.paperMuted,
      surfaceContainerHighest: AppColors.paperMuted,
      outline: AppColors.line,
      outlineVariant: AppColors.lineSoft,
      shadow: AppColors.navy,
      inverseSurface: AppColors.navy,
      onInverseSurface: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.paperSubtle,
    );

    const pill = StadiumBorder();
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.14,
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 26, vertical: 13);

    OutlineInputBorder inputBorder(Color c, [double w = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.navy,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.inkFaint,
          elevation: 0,
          shadowColor: AppColors.brand.withValues(alpha: 0.35),
          shape: pill,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.inkFaint,
          shape: pill,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          shape: pill,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      // Only `border` is themed (no fill, no enabled/focused borders): many
      // fields sit inside their own styled box with `border: InputBorder.none`,
      // and a themed enabledBorder or fill would draw a second box inside it.
      // Flutter derives the focused (red) and error states from `border`.
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.inkFaint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: AppColors.navy),
        prefixIconColor: AppColors.inkFaint,
        suffixIconColor: AppColors.inkFaint,
        border: inputBorder(AppColors.line),
        errorStyle: const TextStyle(
          color: AppColors.dangerInk,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: const Color(0x40133341),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColors.inkSoft,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.line,
        dragHandleSize: Size(40, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      // Pill chips: white with a border, navy when selected (web filters).
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: AppColors.navy,
        disabledColor: AppColors.paperMuted,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(
            color:
                s.contains(WidgetState.selected)
                    ? AppColors.navy
                    : AppColors.line,
            width: 1.5,
          ),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
        // Selected chips use secondaryLabelStyle.
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: AppColors.navy.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          side: const BorderSide(color: AppColors.lineSoft),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.paper),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md + 2),
            ),
          ),
        ),
      ),
      // Web Tabs: navy label, red underline.
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.navy,
        unselectedLabelColor: AppColors.inkMuted,
        indicatorColor: AppColors.brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.line,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkMuted,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          color: AppColors.inkMuted,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        extendedTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.navy,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        todayBorder: const BorderSide(color: AppColors.brand),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(4),
        thumbColor: WidgetStatePropertyAll(
          AppColors.lineStrong.withValues(alpha: 0.7),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lineSoft,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: AppColors.paperMuted,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.brand : null,
        ),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        ),
      ),
      // Web portal switch: navy track when on, gray when off, white knob.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) {
          final c =
              s.contains(WidgetState.selected)
                  ? AppColors.navy
                  : AppColors.lineStrong;
          // Faded while disabled (e.g. while a status change is saving).
          return s.contains(WidgetState.disabled)
              ? c.withValues(alpha: 0.4)
              : c;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.brand,
        selectionColor: AppColors.brand.withValues(alpha: 0.14),
        selectionHandleColor: AppColors.brand,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brand.withValues(alpha: 0.10),
      ),
    );
  }
}
