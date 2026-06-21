import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class InAppNotificationHelper {
  static OverlayEntry? _currentOverlayEntry;

  static void show({
    BuildContext? context,
    OverlayState? overlayState,
    required String title,
    required String body,
    required IconData icon,
    Color iconColor = AppTheme.primaryBlue,
  }) {
    // Dismiss any existing notification first
    dismiss();

    final activeOverlayState = overlayState ?? (context != null ? Overlay.of(context) : null);
    if (activeOverlayState == null) return;
    
    _currentOverlayEntry = OverlayEntry(
      builder: (context) => _InAppNotificationBanner(
        title: title,
        body: body,
        icon: icon,
        iconColor: iconColor,
        onDismiss: () => dismiss(),
        displayDuration: const Duration(seconds: 5),
      ),
    );

    activeOverlayState.insert(_currentOverlayEntry!);
  }

  static void dismiss() {
    if (_currentOverlayEntry != null) {
      _currentOverlayEntry!.remove();
      _currentOverlayEntry = null;
    }
  }
}

class _InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDismiss;
  final Duration displayDuration;

  const _InAppNotificationBanner({
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
    required this.onDismiss,
    required this.displayDuration,
  });

  @override
  State<_InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    // Start auto-dismiss timer inside the widget state
    _autoDismissTimer = Timer(widget.displayDuration, () {
      if (mounted) {
        _animateOut();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOut() async {
    _autoDismissTimer?.cancel();
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 12;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Dismissible(
            key: const Key('in_app_notification_banner'),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.body,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textLight),
                    onPressed: _animateOut,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
