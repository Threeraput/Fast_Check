// ============================================================
// app_theme.dart — ไฟล์กลางสำหรับ Design System ทั้งแอป
// ============================================================
// แก้สีทั้งแอปได้ที่นี่ที่เดียว!
// เปลี่ยน AppColors.primary → สีทั้งแอปเปลี่ยนทันที
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ----------------------------------------------------------
// 🎨 COLORS — แก้สีที่นี่ที่เดียว
// ----------------------------------------------------------
class AppColors {
  AppColors._();

  // --- Primary (สีหลัก) ---
  static const Color primary        = Color(0xFF2563EB); // น้ำเงิน
  static const Color primaryLight   = Color(0xFFEFF6FF); // น้ำเงินอ่อนมาก
  static const Color primaryMid     = Color(0xFF3B82F6); // น้ำเงินกลาง
  static const Color primaryDark    = Color(0xFF17325C); // น้ำเงินเข้มสำหรับ heading

  // --- Background ---
  static const Color bg             = Color(0xFFF8FAFC); // พื้นหลังหลัก
  static const Color surface        = Color(0xFFFFFFFF); // การ์ด / ฟิลด์
  static const Color surfaceAlt     = Color(0xFFF1F5F9); // พื้นหลังรอง
  static const Color surfaceSoft    = Color(0xFFDFE9FF); // พื้นหลังโทนอ่อนแบบหน้า classroom

  // --- Text ---
  static const Color textPrimary    = Color(0xFF0F172A); // ตัวอักษรเข้ม
  static const Color textSecondary  = Color(0xFF64748B); // ตัวอักษรรอง
  static const Color textHint       = Color(0xFF94A3B8); // placeholder

  // --- Border ---
  static const Color border         = Color(0xFFE2E8F0);
  static const Color borderFocus    = Color(0xFF2563EB); // เมื่อ focus

  // --- Status ---
  static const Color success        = Color(0xFF16A34A);
  static const Color successLight   = Color(0xFFF0FDF4);
  static const Color error          = Color(0xFFDC2626);
  static const Color errorLight     = Color(0xFFFEF2F2);
  static const Color warning        = Color(0xFFD97706);
  static const Color warningLight   = Color(0xFFFFFBEB);

  // --- Misc ---
  static const Color divider        = Color(0xFFE2E8F0);
  static const Color shadow         = Color(0x0C0F172A);
  static const Color overlay        = Color(0x80000000);
}

// ----------------------------------------------------------
// 🌈 GRADIENTS — ธีมพื้นหลังที่ใช้ร่วมกันทั้งแอป
// ----------------------------------------------------------
class AppGradients {
  AppGradients._();

  static const Gradient authBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3F6FF), Color(0xFFFFFFFF), Color(0xFFF1F7FF)],
  );

  static const Gradient classroomBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF2F6FF),
      Color(0xFFE3ECFF),
      Color(0xFFD2E1FF),
      Color(0xFFE8F0FF),
    ],
  );

  static const Gradient imageHeroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x22000000), Color(0xA6000000)],
  );
}

// ----------------------------------------------------------
// 📐 SIZES — ขนาดต่าง ๆ
// ----------------------------------------------------------
class AppSizes {
  AppSizes._();

  // Border radius
  static const double radiusSm  = 10.0;
  static const double radiusMd  = 14.0;
  static const double radiusLg  = 18.0;
  static const double radiusXl  = 22.0;

  // Button height
  static const double btnHeight = 42.0;

  // Font sizes
  static const double textXs   = 11.0;
  static const double textSm   = 12.0;
  static const double textBase = 13.0;
  static const double textMd   = 14.0;
  static const double textLg   = 16.0;
  static const double textXl   = 18.0;
  static const double text2xl  = 20.0;
  static const double text3xl  = 24.0;
}

// ----------------------------------------------------------
// 🎨 THEME — สร้าง ThemeData สำหรับ MaterialApp
// ----------------------------------------------------------
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryMid,
      surface: AppColors.surface,
      error: AppColors.error,
    );
    final modernText = GoogleFonts.anuphanTextTheme(
      const TextTheme(
        displayLarge : TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        titleLarge   : TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium  : TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleSmall   : TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge    : TextStyle(fontSize: 13, color: AppColors.textPrimary),
        bodyMedium   : TextStyle(fontSize: 12, color: AppColors.textPrimary),
        bodySmall    : TextStyle(fontSize: 11, color: AppColors.textSecondary),
        labelLarge   : TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        labelSmall   : TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
    return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: modernText,
    primaryTextTheme: modernText,

    // Page transitions (smooth)
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),

    // AppBar — glass frosted
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      actionsIconTheme: const IconThemeData(color: AppColors.textPrimary, size: 21),
    ),

    // FilledButton
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, AppSizes.btnHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        elevation: 0,
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, AppSizes.btnHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: const BorderSide(color: Color(0xFF3A74E8), width: 1.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    ),

    // Card — glass
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.64),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.72), width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),

    // Input — glass frosted
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.52),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(
        fontSize: AppSizes.textSm,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: AppSizes.textSm,
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(
        fontSize: AppSizes.textBase,
        color: AppColors.textHint,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72), width: 1.1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72), width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: AppSizes.textBase,
      ),
    ),

    // ListTile
    listTileTheme: const ListTileThemeData(
      dense: false,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minLeadingWidth: 34,
      horizontalTitleGap: 12,
    ),

    // Chip
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.surfaceAlt,
      labelStyle: const TextStyle(fontSize: AppSizes.textSm, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      selectedColor: AppColors.primaryLight,
    ),

    // ElevatedButton
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, AppSizes.btnHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primaryDark,
      unselectedLabelColor: AppColors.textSecondary,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      indicator: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFD3FF)),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      selectedIconTheme: IconThemeData(size: 22),
      unselectedIconTheme: IconThemeData(size: 21),
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      showUnselectedLabels: true,
      elevation: 4,
      type: BottomNavigationBarType.fixed,
    ),

    // TextSelection
    textSelectionTheme: TextSelectionThemeData(
      selectionHandleColor: AppColors.primary,
      selectionColor: AppColors.primary.withValues(alpha: 0.20),
      cursorColor: AppColors.textPrimary,
    ),

  );
  }
}

// ----------------------------------------------------------
// 🧩 SHARED WIDGETS — ชิ้นส่วน UI ที่ใช้ซ้ำ
// ----------------------------------------------------------

/// InputDecoration มาตรฐาน — ใช้ได้ทุกหน้า
InputDecoration appInput({
  required String label,
  IconData? icon,
  Widget? suffixIcon,
  String? hint,
  String? errorText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: AppColors.surface,
    prefixIcon: icon != null
        ? Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(icon, size: 17, color: AppColors.textSecondary),
          )
        : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffixIcon,
    labelStyle: const TextStyle(
      fontSize: AppSizes.textSm,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      fontSize: AppSizes.textSm,
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      borderSide: const BorderSide(color: AppColors.border, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      borderSide: const BorderSide(color: AppColors.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}

/// Card ที่มี glass effect
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.82),
              width: 1.05,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A3A6B).withValues(alpha: 0.10),
                blurRadius: 20,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}

/// Section header เล็กๆ สวยๆ
class AppSectionTitle extends StatelessWidget {
  final String text;
  const AppSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: AppSizes.textXs,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Badge เล็กๆ glass pill สำหรับ role / status
class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const AppBadge(
    this.label, {
    super.key,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final fg = textColor ?? accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.textXs,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Global workspace-like backdrop — glass ambient orbs
class AppWorkspaceBackdrop extends StatelessWidget {
  final Widget child;

  const AppWorkspaceBackdrop({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F0FF),
            Color(0xFFD6E6FF),
            Color(0xFFE4EEFF),
            Color(0xFFEFF5FF),
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Top-right: large warm blue orb
          Positioned(
            top: -140,
            right: -100,
            child: _Orb(size: 360, color: const Color(0xFF5B9EFF), alpha: 0.22),
          ),
          // Top-left: purple accent orb
          Positioned(
            top: -60,
            left: -80,
            child: _Orb(size: 260, color: const Color(0xFF8B6FFF), alpha: 0.14),
          ),
          // Mid-left: teal orb
          Positioned(
            top: 260,
            left: -110,
            child: _Orb(size: 280, color: const Color(0xFF3BBFBD), alpha: 0.13),
          ),
          // Center: soft white glow
          Positioned(
            top: 180,
            right: -60,
            child: _Orb(size: 200, color: const Color(0xFF93C5FD), alpha: 0.18),
          ),
          // Bottom-right: deep blue orb
          Positioned(
            bottom: -150,
            right: -80,
            child: _Orb(size: 340, color: const Color(0xFF6A91FF), alpha: 0.20),
          ),
          // Bottom-left: indigo orb
          Positioned(
            bottom: -70,
            left: -60,
            child: _Orb(size: 220, color: const Color(0xFF7C3AED), alpha: 0.11),
          ),
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double alpha;
  const _Orb({required this.size, required this.color, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}
