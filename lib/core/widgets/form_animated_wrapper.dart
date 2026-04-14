import 'package:flutter/material.dart';

/// Wraps a widget with the standard slide-up + fade-in entry animation
/// used across police_station_form, agency_form, department_form, etc.
///
/// Usage:
/// ```dart
/// FormAnimatedWrapper(
///   child: Column(children: [header, section1, section2, button]),
/// )
/// ```
class FormAnimatedWrapper extends StatefulWidget {
  final Widget child;
  final Duration slideDuration;
  final Duration fadeDuration;
  final Offset slideBegin;

  const FormAnimatedWrapper({
    super.key,
    required this.child,
    this.slideDuration = const Duration(milliseconds: 600),
    this.fadeDuration = const Duration(milliseconds: 800),
    this.slideBegin = const Offset(0, 0.08),
  });

  @override
  State<FormAnimatedWrapper> createState() => _FormAnimatedWrapperState();
}

class _FormAnimatedWrapperState extends State<FormAnimatedWrapper>
    with TickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late AnimationController _fadeCtrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(duration: widget.slideDuration, vsync: this);
    _fadeCtrl = AnimationController(duration: widget.fadeDuration, vsync: this);

    _slide = Tween<Offset>(begin: widget.slideBegin, end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _slideCtrl.forward();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: widget.child,
      ),
    );
  }
}
