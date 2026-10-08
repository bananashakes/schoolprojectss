import 'package:flutter/material.dart';

// reusable styled snackbar used in aura pages
void showAuraSnackBar(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline_rounded,
  Color backgroundColor = const Color(0xFF1B1224),
  Color iconColor = const Color(0xFFB28CFF),
  Color borderColor = const Color(0xFF8B5CF6),
  Color textColor = Colors.white,
  Color shadowColor = Colors.black,
  double borderOpacity = 0.45,
  double shadowOpacity = 0.35,
  double blurRadius = 16,
  double spreadRadius = 0,
  double fontSize = 13,
  Offset shadowOffset = const Offset(0, 6),
  EdgeInsets margin = const EdgeInsets.fromLTRB(18, 0, 18, 20),
  Duration duration = const Duration(seconds: 2),
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: margin,
      duration: duration,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor.withValues(alpha: borderOpacity),
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: shadowOpacity),
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
              offset: shadowOffset,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
