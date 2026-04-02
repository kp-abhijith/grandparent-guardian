import 'package:flutter/material.dart';
import '../theme.dart';

class PulsingMic extends StatefulWidget {
  const PulsingMic({super.key});
  @override
  State<PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<PulsingMic>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.2).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
            color: kGreen.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.mic_rounded, size: 90, color: kGreen),
      ),
    );
  }
}
