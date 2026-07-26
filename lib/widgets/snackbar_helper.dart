import 'package:flutter/material.dart';

void showAppSnackBar(BuildContext context, String message, {bool isSuccess = true}) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              color: isSuccess ? colorScheme.primary : colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
    );
}
