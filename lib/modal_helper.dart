import 'package:flutter/material.dart';

/// Simple global modal helper that prevents multiple modal bottom sheets
/// or dialogs from being opened at the same time. This helps avoid
/// duplicate openings when taps fire quickly or due to platform quirks.
class ModalHelper {
  static bool _modalOpen = false;

  /// Shows a modal bottom sheet but prevents another one from opening
  /// while one is already visible. Returns the result from the sheet.
  static Future<T?> showSingleModalBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Color? backgroundColor,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
  }) async {
    if (_modalOpen) return null;
    _modalOpen = true;
    try {
      final res = await showModalBottomSheet<T>(
        context: context,
        backgroundColor: backgroundColor,
        isScrollControlled: isScrollControlled,
        useRootNavigator: useRootNavigator,
        builder: builder,
      );
      return res;
    } finally {
      // ensure flag reset
      _modalOpen = false;
    }
  }

  /// Show a dialog but only if no other modal is shown. Useful for
  /// avoiding duplicate dialogs when multiple triggers happen quickly.
  static Future<T?> showSingleDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    if (_modalOpen) return null;
    _modalOpen = true;
    try {
      final res = await showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );
      return res;
    } finally {
      _modalOpen = false;
    }
  }
}
