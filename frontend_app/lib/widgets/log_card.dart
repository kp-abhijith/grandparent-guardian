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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showLogDetails(context),
          child: Container(
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
          ),
        ),
      ),
    );
  }

  void _showLogDetails(BuildContext context) {
    final isDanger = log['danger'] as bool? ?? false;
    final color = isDanger ? kDanger : kGreen;
    final title = log['title'] as String? ?? 'Unknown';
    final phone = log['phone'] as String? ?? 'Not available';
    final transcript = log['preview'] as String? ?? 'No transcript available';
    final tactic = log['tactic'] as String? ?? 'No analysis available';
    final risk = log['risk'] as int? ?? 0;
    final category = isDanger ? detectScamCategory(tactic) : '';
    final bColor = badgeColor(category);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kLightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            isDanger
                                ? Icons.warning_rounded
                                : Icons.check_circle_rounded,
                            size: 36,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDanger ? 'Scam Caller' : 'Safe Caller',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                              if (category.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: bColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: kLightGray, thickness: 2),
                    const SizedBox(height: 24),
                    _detailRow('Phone Number', phone, Icons.phone_rounded),
                    const SizedBox(height: 20),
                    Text(
                      'Risk Level',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$risk%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: kLightGray, thickness: 2),
                    const SizedBox(height: 24),
                    Text(
                      'Transcript',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kLightGray,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        transcript,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.5,
                          color: kNavy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AI Analysis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDanger
                            ? kDanger.withOpacity(0.08)
                            : kGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        tactic.isNotEmpty ? tactic : 'No analysis available',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.5,
                          color: isDanger ? kDanger : kNavy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kNavy,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 28, color: kMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: kMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kNavy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
