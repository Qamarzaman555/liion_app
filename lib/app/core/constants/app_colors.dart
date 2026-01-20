import 'package:flutter/material.dart';

class AppColors {
  static const Color textfieldColor = Color(0xFFA1A1A1);
  static const Color whiteColor = Colors.white;
  static const Color white54Color = Colors.white54;
  static const Color toastColor = Color(0x8a000000);
  static const Color blackColor = Colors.black;
  static const Color transparentColor = Colors.transparent;
  static const Color redColor = Colors.red;
  static const Color greyColor = Colors.grey;
  static const Color greenColor = Colors.green;
  static const Color errorColor = Colors.red;
  static const Color primaryColor = Color(0xFF006555);
  static const Color secondaryColor = Color(0xFF66A399);
  static const Color cardBGColor = Color(0xFFEAEAEA);
  static const Color primaryInvertColor = Color(0xFFCCCCCC);
  static const Color yellowColor = Color(0xFFFFBC00);
}

class NewAppColors {
  NewAppColors._();

  // App Basic
  static const Color primary = Color(0xFF016553);
  static const Color secondary = Color(0xFFCCCCCC);
  static const Color accent = Color(0xFF00C896);

  // Alternative Primary
  static const Color primaryAlt = Color(0xFF4DAEA7);

  // Divider Color
  static const Color divider = Color(0xFFCCCCCC);

  // Nav Bar Selected Color
  static const Color navBarSelected = Color(0xFFC2DAD6);

  // Text Colors
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Color(0xFF282828);
  static const Color textWhite = Colors.white;
  static const Color textLightGreen = Color(0xFF1EBF66);
  static const Color textDarkGreen = Color(0xFF1EBF66);

  // Background Colors
  static const Color light = Color(0xFFf6f6f6);
  static const Color dark = Color(0xFF272727);
  static const Color primaryBackground = Color(0xFFf3f5ff);
  static const Color whiteBackground = Colors.white;

  // Background Container Colors
  static const Color lightContainer = Color(0xFFf6f6f6);
  static const Color mediumContainer = Color(0xFFF0F0F2);
  static Color darkContainer = NewAppColors.textWhite.withOpacity(0.1);

  // Card Colors
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardSelected = Color(0xFF282828);
  static const Color cardGreenBackground = Color(0xFFDAF5E8);
  static const Color cardRedBackground = Color(0xFFFEE0E0);

  // Button Colors
  static const Color buttonPrimary = Color(0xFF016553);
  static const Color buttonSecondary = Color(0xFFCCCCCC);
  static const Color buttonDisabled = Color(0xFFCCCCCC);

  // Border Colors
  static const Color borderPrimary = Color(0xFFd9d9d9);
  static const Color borderSecondary = Color(0xFFe6e6e6);
  static const Color containerBorder = Colors.black12;

  // Error and Validation Colors
  static const Color error = Color(0xFFFF5F57);
  static const Color success = Color(0xFF388e3c);
  static const Color warning = Color(0xFFf57c00);
  static const Color info = Color(0xFF1976d2);

  // Neutral Shades
  static const Color black = Color(0xFF232323);
  static const Color blue = Color(0xFF4C7FFC);
  static const Color white = Color(0xFFffffff);
  static const Color darkerGrey = Color(0xFF4f4f4f);
  static const Color darkGrey = Color(0xFF939393);
  static const Color grey = Color(0xFFEAEAEA);
  static const Color lightGrey = Color(0xFFf9f9f9);
  static const Color softGrey = Color(0xFFf4f4f4);

  // Transparent
  static const Color transparent = Colors.transparent;

  // Gradient Colors

  static const Gradient linearGradient = LinearGradient(
    begin: Alignment(0, 0),
    end: Alignment(0.707, -0.707),
    colors: [Color(0xffff9a9e), Color(0xfffad0c4), Color(0xfffad0c4)],
  );
}
