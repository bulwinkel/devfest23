import 'package:flutter/material.dart';

class Snack {
  Snack(this.context);
  final BuildContext context;

  void success(
    String message, {
    Color? textColor,
    Color? backgroundColor,
    String? actionLabel,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: textColor == null ? null : TextStyle(color: textColor),
      ),
      backgroundColor: backgroundColor,
      action: SnackBarAction(
        label: actionLabel ?? 'ok',
        onPressed: () {},
      ),
    ));
  }

  /// Displays a red snackbar indicating error
  void error(
    String message, {
    String? actionLabel,
  }) {
    success(
      message,
      textColor: Theme.of(context).colorScheme.onErrorContainer,
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      actionLabel: actionLabel,
    );
  }
}

extension ShowSnackBar on BuildContext {
  /// Displays a basic snackbar
  Snack get snack => Snack(this);
}
