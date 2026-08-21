/// Small, self-dismissing notifications.
///
/// A full-width snackbar is the wrong shape for this app: it covers the action
/// bar, it stays until something else replaces it, and in a reading tool the
/// bottom of the window is where the user is looking. These are compact, sit
/// out of the way in the bottom-right, fade out on their own, and vanish on a
/// click.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// How long a toast stays before fading out.
const Duration kToastDuration = Duration(milliseconds: 2800);

/// How long a toast carrying an action stays, since it invites a decision.
const Duration kToastWithActionDuration = Duration(milliseconds: 5000);

/// Shows a compact toast over the current route.
///
/// A new toast replaces the one on screen: stacking them would recreate the
/// problem the shape is meant to solve.
void showToast(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _ToastHost.instance.show(
    overlay: overlay,
    message: message,
    isError: isError,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

/// Removes any toast currently on screen.
void hideToast() => _ToastHost.instance.dismiss();

/// Owns the single visible toast.
final class _ToastHost {
  _ToastHost._();

  static final _ToastHost instance = _ToastHost._();

  OverlayEntry? _entry;
  Timer? _timer;

  void show({
    required OverlayState overlay,
    required String message,
    required bool isError,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    dismiss();
    final entry = OverlayEntry(
      builder: (BuildContext context) => _ToastCard(
        message: message,
        isError: isError,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                dismiss();
                onAction();
              },
        onDismiss: dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(
      actionLabel == null ? kToastDuration : kToastWithActionDuration,
      dismiss,
    );
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.isError,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isError
        ? const Color(0xFF8C2F2F)
        : AppColors.text;

    return Positioned(
      right: 20,
      // Keep notifications above persistent bottom action bars. Reader and
      // review actions are intentionally anchored to the bottom-right, so a
      // toast at the raw window edge would intercept the next click.
      bottom: 84,
      child: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutCubic,
                ),
              ),
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                // Clicking anywhere on the toast dismisses it.
                onTap: widget.onDismiss,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: EdgeInsets.fromLTRB(
                    14,
                    10,
                    widget.actionLabel == null ? 14 : 6,
                    10,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null) ...<Widget>[
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: widget.onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
