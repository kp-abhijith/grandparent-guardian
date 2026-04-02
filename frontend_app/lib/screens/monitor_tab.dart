import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/pulsing_mic.dart';

enum AppState { safe, listening, analyzing, danger }

class MonitorTab extends StatelessWidget {
  final AppState currentState;
  final String   transcribedText;
  final VoidCallback onStop;
  final bool     isManualMode;
  final ValueChanged<bool> onToggleMode;
  final TextEditingController manualController;
  final ValueChanged<String> onManualTextChanged;

  const MonitorTab({
    super.key,
    required this.currentState,
    required this.transcribedText,
    required this.onStop,
    required this.isManualMode,
    required this.onToggleMode,
    required this.manualController,
    required this.onManualTextChanged,
  });

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _buildContent(context));

  Widget _buildContent(BuildContext context) {
    switch (currentState) {
      case AppState.safe:
      case AppState.danger:
        return _buildStandby(context);
      case AppState.listening:
        return _buildListening(context);
      case AppState.analyzing:
        return _buildAnalyzing();
    }
  }

  Widget _buildStandby(BuildContext context) {
    return Center(
      key: const ValueKey('standby'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(60),
              decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.shield_rounded,
                  size: 160, color: kGreen),
            ),
            const SizedBox(height: 32),
            const Text('Guard on Standby',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: kNavy)),
            const SizedBox(height: 8),
            const Text('Protection is ready',
                style: TextStyle(fontSize: 22, color: kMuted)),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:        kLightGray,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('INPUT MODE',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: kMuted,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _modeBtn(context, '🎙  Voice',
                            !isManualMode, () => onToggleMode(false))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _modeBtn(context, '⌨  Type',
                            isManualMode, () => onToggleMode(true))),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    isManualMode
                        ? 'Type any call transcript to test detection'
                        : 'Speak aloud to analyze real-time call audio',
                    style: const TextStyle(fontSize: 16, color: kMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeBtn(BuildContext context, String label, bool active,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:    const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        active ? kGreen : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.bold,
              color:      active ? Colors.white : kMuted,
            )),
      ),
    );
  }

  Widget _buildListening(BuildContext context) {
    return Center(
      key: const ValueKey('listening'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            if (!isManualMode)
              const PulsingMic()
            else
              const Icon(Icons.keyboard_rounded, size: 80, color: kGreen),
            const SizedBox(height: 30),
            Text(
              isManualMode
                  ? 'Type the call transcript'
                  : 'Listening...',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kNavy),
            ),
            const SizedBox(height: 24),
            if (isManualMode) ...[
              Container(
                decoration: BoxDecoration(
                  color:        kLightGray,
                  borderRadius: BorderRadius.circular(24),
                  border:       Border.all(color: kGreen),
                ),
                child: TextField(
                  controller:  manualController,
                  onChanged:   onManualTextChanged,
                  maxLines:    6,
                  autofocus:   true,
                  style:       const TextStyle(fontSize: 22, color: kNavy),
                  decoration: const InputDecoration(
                    hintText:       'Paste or type call transcript here...',
                    hintStyle:      TextStyle(fontSize: 20, color: kMuted),
                    border:         InputBorder.none,
                    contentPadding: EdgeInsets.all(24),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Quick test examples:',
                    style: TextStyle(fontSize: 16, color: kMuted)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _chip('OTP scam (English)',
                      'hello send me that OTP then you will get a loan of 10 lakh'),
                  _chip('OTP scam (Hindi)',
                      'aapka account band ho jayega abhi OTP bhej dijiye'),
                  _chip('Safe call',
                      'I called to say hello and check how you are doing today'),
                ],
              ),
            ] else
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:        kLightGray,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  transcribedText.isEmpty
                      ? 'Waiting for speech...'
                      : transcribedText,
                  style: TextStyle(
                    fontSize: 24,
                    color: transcribedText.isEmpty ? kMuted : kNavy,
                  ),
                ),
              ),
            const SizedBox(height: 40),
            SizedBox(
              width:  double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: onStop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDanger,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Analyze Now →',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return GestureDetector(
      onTap: () {
        manualController.text = value;
        onManualTextChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        kLightGray,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: Colors.grey.shade300),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, color: kNavy)),
      ),
    );
  }

  Widget _buildAnalyzing() {
    return Center(
      key: const ValueKey('analyzing'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: kGreen, strokeWidth: 8),
          const SizedBox(height: 32),
          const Text('Analyzing Intent...',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kNavy)),
          const SizedBox(height: 8),
          const Text('Llama 3.2 is checking for scam tactics',
              style: TextStyle(fontSize: 22, color: kMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
