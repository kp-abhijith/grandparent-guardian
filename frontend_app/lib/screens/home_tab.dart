import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onStartProtection;
  final VoidCallback onDemoPitch;
  final String userId;

  const HomeTab({
    super.key,
    required this.onStartProtection,
    required this.onDemoPitch,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
                color: kGreen.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded, size: 140, color: kGreen),
          ),
          const SizedBox(height: 24),
          const Text('Grandparent Guardian',
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: kNavy),
              textAlign: TextAlign.center),
          const Text('Your personal AI shield against scam calls',
              style: TextStyle(fontSize: 22, color: kMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 80,
            child: ElevatedButton(
              onPressed: onStartProtection,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Start Protection →',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 70,
            child: OutlinedButton(
              onPressed: onDemoPitch,
              style: OutlinedButton.styleFrom(
                side:  const BorderSide(color: kNavy, width: 3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('▶  Run Demo Pitch',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: kNavy)),
            ),
          ),
          const SizedBox(height: 40),
          _buildThreatCard(),
          const SizedBox(height: 32),
          _featureRow(Icons.mic_rounded,  kGreen,  'Real-time Voice Analysis'),
          const SizedBox(height: 16),
          _featureRow(Icons.bolt_rounded, kGold,   'Instant AI Detection'),
          const SizedBox(height: 16),
          _featureRow(Icons.sms_rounded,  kDanger, 'Real SMS Family Alert'),
        ],
      ),
    );
  }

  Widget _buildThreatCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('scam_logs')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final total = docs.length;
        final detected = docs.where((d) => d['danger'] == true).length;
        final blocked = docs.where((d) => d['isBlocked'] == true).length;
        final safeCalls = total - detected;
        final safeRatio = total == 0 ? 1.0 : safeCalls / total;
        final detectedRatio = total == 0 ? 0.0 : detected / total;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('THREAT INTELLIGENCE',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kMuted,
                      letterSpacing: 1.5)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$total Total Calls',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kNavy)),
                  Text('$detected Detected',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kGold)),
                  Text('$blocked Blocked',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kDanger)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      Expanded(
                          flex: (safeRatio * 100).toInt(),
                          child: Container(color: kGreen)),
                      Expanded(
                          flex: (detectedRatio * 100).toInt(),
                          child: Container(color: kGold)),
                      if (total == 0)
                        Expanded(
                            child: Container(
                                color: Colors.grey.shade200)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Safe',
                      style: TextStyle(
                          color: kGreen,
                          fontWeight: FontWeight.bold)),
                  if (total > 0)
                    const Text('Scam Detected',
                        style: TextStyle(
                            color: kGold,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _featureRow(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 28, color: color),
        ),
        const SizedBox(width: 16),
        Text(label,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kNavy)),
      ]),
    );
  }
}
