import 'package:flutter/material.dart';
import '../theme.dart';

class DangerScreen extends StatelessWidget {
  final int scamProbability;
  final String analysisResult;
  final VoidCallback onMute;
  final VoidCallback onAlertFamily;

  const DangerScreen({
    super.key,
    required this.scamProbability,
    required this.analysisResult,
    required this.onMute,
    required this.onAlertFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 120, color: kDanger),
            const SizedBox(height: 24),
            const Text('⚠️ SCAM DETECTED!',
                style: TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w900, color: kDanger),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('$scamProbability% RISK',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: kGold)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(24),
                border:       Border.all(color: kDanger, width: 3),
              ),
              child: Text(analysisResult,
                  style: const TextStyle(
                      fontSize: 26, height: 1.4, color: kNavy),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 48),
            _bigButton('🔇  MUTE CALL',    kNavy,  onMute),
            const SizedBox(height: 20),
            _bigButton('🔔  ALERT FAMILY', kGreen, onAlertFamily),
          ],
        ),
      ),
    );
  }

  Widget _bigButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width:  double.infinity,
      height: 80,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }
}
