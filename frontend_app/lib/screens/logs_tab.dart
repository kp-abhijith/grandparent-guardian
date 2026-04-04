import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../widgets/log_card.dart';

class LogsTab extends StatelessWidget {
  final String userId;
  const LogsTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
          child: Row(children: [
            const Text('Call History',
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: kNavy)),
            const Spacer(),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('scam_logs')
                  .where('userId', isEqualTo: userId)
                  .where('isBlocked', isEqualTo: true)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Text('$count blocked',
                    style: const TextStyle(
                        fontSize: 20,
                        color: kDanger,
                        fontWeight: FontWeight.bold));
              },
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('scam_logs')
                .where('userId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(fontSize: 18, color: kDanger)));
              }
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: kGreen));
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                    child: Text('No calls yet',
                        style: TextStyle(fontSize: 24, color: kMuted)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                itemCount: docs.length,
                itemBuilder: (ctx, i) =>
                    LogCard(log: docs[i].data() as Map<String, dynamic>),
              );
            },
          ),
        ),
      ],
    );
  }
}
