import 'package:flutter/material.dart';
import '../theme.dart';

class SettingsTab extends StatefulWidget {
  final String familyPhone;
  final void Function(String) onTestScam;
  const SettingsTab(
      {super.key,
      required this.familyPhone,
      required this.onTestScam});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _loudWarning = true;
  bool _autoMute    = false;
  bool _smsAlert    = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings',
              style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: kNavy)),
          const SizedBox(height: 32),
          _sectionLabel('FAMILY ALERT'),
          _card(
              child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.sms_rounded,
                  color: kGreen, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SMS via Twilio',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kNavy)),
                  Text('+${widget.familyPhone}',
                      style: const TextStyle(
                          fontSize: 16, color: kMuted)),
                  const Text('Real SMS sent on scam detection',
                      style:
                          TextStyle(fontSize: 15, color: kMuted)),
                ],
              ),
            ),
          ])),
          const SizedBox(height: 24),
          _sectionLabel('TEST SCENARIOS'),
          _card(
              child: Column(children: [
            _testBtn('Test: OTP Scam (English)',
                'Hello, I will send you 10000 rupees. Please share your OTP with me.'),
            const SizedBox(height: 12),
            _testBtn('Test: OTP Scam (Hindi)',
                'aapka account band ho jayega turant OTP bhej dijiye warna paisa dub jayega'),
            const SizedBox(height: 12),
            _testBtn('Test: Safe Call',
                'Hi aunty, how are you? I just called to say hello and check on you.'),
          ])),
          const SizedBox(height: 24),
          _sectionLabel('ALERT PREFERENCES'),
          _card(
              child: Column(children: [
            _toggle('Loud Audio Warning', _loudWarning,
                (v) => setState(() => _loudWarning = v)),
            const Divider(),
            _toggle('Auto-Mute on Scam', _autoMute,
                (v) => setState(() => _autoMute = v)),
            const Divider(),
            _toggle('SMS Alert to Family', _smsAlert,
                (v) => setState(() => _smsAlert = v)),
          ])),
          const SizedBox(height: 24),
          _sectionLabel('ABOUT'),
          _card(
              child: Column(children: [
            _aboutRow('App',      'Grandparent Guardian'),
            const Divider(),
            _aboutRow('Team',     'Compile Crew'),
            const Divider(),
            _aboutRow('College',  'AITR Indore'),
            const Divider(),
            _aboutRow('AI Model', 'Llama 3.2 (Ollama)'),
            const Divider(),
            _aboutRow('SMS',      'Twilio'),
          ])),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _testBtn(String label, String transcript) {
    return SizedBox(
      width:  double.infinity,
      height: 60,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side:  BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => widget.onTestScam(transcript),
        child: Text(label,
            style: const TextStyle(
                fontSize: 17,
                color: kNavy,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: kMuted,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10)
          ],
        ),
        child: child,
      );

  Widget _toggle(
      String label, bool val, ValueChanged<bool> onChange) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style:
              const TextStyle(fontSize: 20, color: kNavy)),
      activeColor: kGreen,
      value:       val,
      onChanged:   onChange,
    );
  }

  Widget _aboutRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 18, color: kMuted)),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    color: kNavy,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
