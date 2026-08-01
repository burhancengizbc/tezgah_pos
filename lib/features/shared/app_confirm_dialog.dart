import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppConfirmDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Evet',
    String cancelText = 'Vazgeç',
    bool isDanger = false,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: isDanger ? AppColors.danger : null)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText, style: const TextStyle(color: AppColors.dTextDim)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? AppColors.danger : AppColors.primary,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}