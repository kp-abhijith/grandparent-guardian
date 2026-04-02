import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme.dart';

class IncomingCallScreen extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const IncomingCallScreen(
      {super.key,
      required this.onAccept,
      required this.onDecline});

  @override
  State<IncomingCallScreen> createState() =>
      _IncomingCallScreenState();
}

class _IncomingCallScreenState
    extends State<IncomingCallScreen> {
  final AudioPlayer _ringtone = AudioPlayer();

  @override
  void initState() {
    super.initState();
    try {
      _ringtone.setReleaseMode(ReleaseMode.loop);
      _ringtone.play(AssetSource('ringtone.wav'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _ringtone.stop();
    _ringtone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.person_rounded,
                size: 100, color: Colors.white),
            const SizedBox(height: 16),
            const Text('Incoming Call',
                style: TextStyle(
                    fontSize: 24, color: Colors.white70)),
            const SizedBox(height: 8),
            const Text('+91 98765 43210',
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color:        kGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('⚠ Unknown number — Demo',
                  style: TextStyle(
                      color: kGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _callBtn(kDanger, Icons.call_end_rounded,
                    'Decline', () {
                  _ringtone.stop();
                  widget.onDecline();
                }),
                _callBtn(kGreen, Icons.call_rounded, 'Accept',
                    () {
                  _ringtone.stop();
                  widget.onAccept();
                }),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _callBtn(Color color, IconData icon, String label,
      VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width:  80,
            height: 80,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 22)),
      ],
    );
  }
}
