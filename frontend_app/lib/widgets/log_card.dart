import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme.dart';

String detectScamCategory(String tactic) {
  final lower = tactic.toLowerCase();
  if (lower.contains('otp') || lower.contains('pin') || lower.contains('password')) {
    return 'OTP Theft';
  }
  if (lower.contains('arrest') || lower.contains('police') || lower.contains('court')) {
    return 'Digital Arrest';
  }
  if (lower.contains('lottery') || lower.contains('prize') || lower.contains('won')) {
    return 'Lottery Scam';
  }
  if (lower.contains('kyc') || lower.contains('account') && lower.contains('block')) {
    return 'KYC Fraud';
  }
  return 'Unknown';
}

Color badgeColor(String category) {
  switch (category) {
    case 'OTP Theft':      return const Color(0xFFEF4444);
    case 'Digital Arrest':  return const Color(0xFFF97316);
    case 'Lottery Scam':   return const Color(0xFFF59E0B);
    case 'KYC Fraud':      return const Color(0xFF3B82F6);
    default:               return const Color(0xFF374151);
  }
}

String _relativeTime(dynamic createdAt) {
  if (createdAt == null) return 'Just now';
  if (createdAt is Timestamp) {
    return timeago.format(createdAt.toDate(), allowFromNow: true);
  }
  return 'Just now';
}

class LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const LogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final isDanger = log['danger'] as bool? ?? false;
    final color    = isDanger ? kDanger : kGreen;
    final tactic   = log['tactic'] as String? ?? '';
    final category = isDanger ? detectScamCategory(tactic) : '';
    final bColor   = badgeColor(category);
    final timeStr  = _relativeTime(log['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(24),
        border:       Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15)
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              isDanger
                  ? Icons.warning_rounded
                  : Icons.check_circle_rounded,
              size: 36,
              color: color),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(log['title'] as String? ?? 'Unknown',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 14, color: kMuted)),
                  ],
                ),
                Text(log['phone'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 16, color: kMuted)),
                const SizedBox(height: 6),
                Text('"${log['preview'] ?? ''}"',
                    style: const TextStyle(
                        fontSize: 20, color: kNavy),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (tactic.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(tactic,
                      style: TextStyle(
                          fontSize: 16,
                          color: color.withOpacity(0.8),
                          fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (isDanger && category.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color:        bColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(category,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: bColor)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${log['risk'] ?? 0}%',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ],
      ),
    );
  }
}
