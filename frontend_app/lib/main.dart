import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const GrandparentGuardianApp());
}

// ─────────────────────────────────────────────
//  ELDERLY-FRIENDLY THEME
// ─────────────────────────────────────────────
const kGreen      = Color(0xFF22C55E);
const kNavy       = Color(0xFF0F172A);
const kDanger     = Color(0xFFEF4444);
const kGold       = Color(0xFFF59E0B);
const kLightGray  = Color(0xFFF8FAFC);
const kMuted      = Color(0xFF64748B);

class GrandparentGuardianApp extends StatelessWidget {
  const GrandparentGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grandparent Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: kGreen,
        fontFamily: 'Roboto',
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: kNavy),
          titleLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kNavy),
          bodyLarge: TextStyle(fontSize: 24, color: kNavy),
          labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

enum AppState { safe, listening, analyzing, danger }

// ─────────────────────────────────────────────
//  MAIN DASHBOARD
// ─────────────────────────────────────────────
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  AppState _currentState = AppState.safe;
  String _transcribedText = '';
  String _analysisResult = '';
  int _scamProbability = 0;
  int _scamsBlocked = 0;
  int _callsAnalyzed = 0;

  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _warningPlayer = AudioPlayer();
  final List<Map<String, dynamic>> _callLogs = [];

  bool _isManualMode = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _manualController.dispose();
    _warningPlayer.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
  }

  Future<void> _startListening() async {
    if (_isManualMode) {
      setState(() => _currentState = AppState.listening);
      return;
    }

    bool hasMic = false;
    if (!kIsWeb) {
      var micStatus = await Permission.microphone.request();
      hasMic = micStatus.isGranted;
    } else {
      hasMic = true;
    }

    if (hasMic || await _speechToText.hasPermission) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _currentState = AppState.listening;
          _transcribedText = '';
        });
        await _speechToText.listen(
          onResult: (result) {
            setState(() => _transcribedText = result.recognizedWords);
          },
          localeId: 'en_IN',
        );
      }
    }
  }

  Future<void> _stopListening() async {
    if (!_isManualMode) await _speechToText.stop();
    if (_isManualMode && _transcribedText.isEmpty) {
      _transcribedText = _manualController.text.trim();
    }
    setState(() => _currentState = AppState.analyzing);
    _analyzeCall();
  }

Future<void> _analyzeCall() async {
    final textToAnalyze = _isManualMode ? _manualController.text.trim() : _transcribedText;
    if (textToAnalyze.isEmpty) {
      _showSnackBar('No text to analyze.', color: Colors.orange);
      setState(() { _currentState = AppState.safe; _currentIndex = 0; });
      return;
    }

    try {
      final baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://192.168.137.55:8000';
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': textToAnalyze}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final prob = (json['probability'] ?? 0) as int;
        final isScam = json['status'] == 'scam_detected';
        final analysis = json['analysis'] ?? (isScam ? 'Scam detected.' : 'Call is safe.');

        setState(() => _callsAnalyzed++);

        // Generate a mock number for the demo, or label it as manual entry
        final displayPhone = _isManualMode ? "Manual Text Entry" : "+91 98765 43210";

        if (isScam) {
          setState(() => _scamsBlocked++);
          _playWarning();
          setState(() {
            _currentState = AppState.danger;
            _analysisResult = analysis;
            _scamProbability = prob;
            _callLogs.insert(0, {
              'title': 'Scam Caller',
              'phone': displayPhone, // 🟢 Added phone number
              'preview': textToAnalyze,
              'risk': prob,
              'danger': true,
              'tactic': analysis,
            });
          });
        } else {
          _showSnackBar('✓ Call is Safe ($prob% risk)', color: kGreen);
          setState(() {
            _currentState = AppState.safe;
            _currentIndex = 0;
            _callLogs.insert(0, {
              'title': 'Safe Caller',
              'phone': displayPhone, // 🟢 Added phone number
              'preview': textToAnalyze,
              'risk': prob,
              'danger': false,
              'tactic': analysis,
            });
          });
        }
      }
    } catch (e) {
      _showSnackBar('Cannot reach backend.', color: kDanger);
      setState(() { _currentState = AppState.safe; _currentIndex = 0; });
    }
  }

  void _playWarning() {
    try {
      _warningPlayer.setReleaseMode(ReleaseMode.loop);
      _warningPlayer.play(AssetSource('warning.wav'));
    } catch (_) {}
  }

  void _muteCall() {
    _warningPlayer.stop();
    _manualController.clear();
    setState(() {
      _currentState = AppState.safe;
      _currentIndex = 0;
      _transcribedText = '';
      _analysisResult = '';
      _scamProbability = 0;
    });
  }

  void _alertFamily() {
    _warningPlayer.stop();
    _manualController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 28), SizedBox(width: 12), Text('Family Alerted Successfully!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
        backgroundColor: kGreen,
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() {
      _currentState = AppState.safe;
      _currentIndex = 0;
      _transcribedText = '';
      _analysisResult = '';
      _scamProbability = 0;
    });
  }

  void _showSnackBar(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 18, color: Colors.white)),
      backgroundColor: color ?? kNavy,
    ));
  }

  void _triggerProtection() {
    setState(() => _currentIndex = 1);
    _startListening();
  }

  void _runDemoPitch() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => IncomingCallScreen(
        onAccept: () { Navigator.pop(context); _triggerProtection(); },
        onDecline: () => Navigator.pop(context),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == AppState.danger) {
      return Scaffold(body: SafeArea(child: _buildDangerState()));
    }

    final pages = [
      HomeTab(onStartProtection: _triggerProtection, onDemoPitch: _runDemoPitch, scamsBlocked: _scamsBlocked, callsAnalyzed: _callsAnalyzed),
      MonitorTab(currentState: _currentState, transcribedText: _transcribedText, onStop: _stopListening, isManualMode: _isManualMode, onToggleMode: (v) => setState(() => _isManualMode = v), manualController: _manualController, onManualTextChanged: (v) => setState(() => _transcribedText = v)),
      LogsTab(logs: _callLogs, scamsBlocked: _scamsBlocked),
      SettingsTab(onTestScam: (text) { _manualController.text = text; _isManualMode = true; setState(() => _currentIndex = 1); _triggerProtection(); }),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _currentIndex, children: pages)),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      backgroundColor: Colors.white,
      selectedItemColor: kGreen,
      unselectedItemColor: kMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      unselectedLabelStyle: const TextStyle(fontSize: 14),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 32), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.shield_rounded, size: 32), label: 'Monitor'),
        BottomNavigationBarItem(icon: Icon(Icons.history_rounded, size: 32), label: 'Logs'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_rounded, size: 32), label: 'Settings'),
      ],
    );
  }

  // 🟢 Wrapped in SingleChildScrollView to prevent yellow overflow bars!
  Widget _buildDangerState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 120, color: kDanger),
            const SizedBox(height: 24),
            const Text('⚠️ SCAM DETECTED!', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: kDanger), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('$_scamProbability% RISK', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kGold)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kDanger, width: 3)),
              child: Text(_analysisResult, style: const TextStyle(fontSize: 26, height: 1.4, color: kNavy), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 48),
            _bigDangerButton('🔇 MUTE CALL', kNavy, _muteCall),
            const SizedBox(height: 20),
            _bigDangerButton('🔔 ALERT FAMILY', kGreen, _alertFamily),
          ],
        ),
      ),
    );
  }

  Widget _bigDangerButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HOME TAB
// ─────────────────────────────────────────────
class HomeTab extends StatelessWidget {
  final VoidCallback onStartProtection;
  final VoidCallback onDemoPitch;
  final int scamsBlocked;
  final int callsAnalyzed;

  const HomeTab({super.key, required this.onStartProtection, required this.onDemoPitch, required this.scamsBlocked, required this.callsAnalyzed});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: kGreen.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded, size: 140, color: kGreen),
          ),
          const SizedBox(height: 24),
          const Text('Grandparent Guardian', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: kNavy), textAlign: TextAlign.center),
          const Text('Your personal AI shield against scam calls', style: TextStyle(fontSize: 22, color: kMuted), textAlign: TextAlign.center),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 80,
            child: ElevatedButton(
              onPressed: onStartProtection,
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: const Text('Start Protection →', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 70,
            child: OutlinedButton(
              onPressed: onDemoPitch,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: kNavy, width: 3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: const Text('▶ Run Demo Pitch', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kNavy)),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(child: _statCard('$scamsBlocked', 'Scams Blocked', kDanger)),
              const SizedBox(width: 20),
              Expanded(child: _statCard('$callsAnalyzed', 'Calls Analyzed', kGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
      child: Column(children: [Text(value, style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: color)), Text(label, style: const TextStyle(fontSize: 18, color: kMuted), textAlign: TextAlign.center)]),
    );
  }
}

// ─────────────────────────────────────────────
//  MONITOR TAB
// ─────────────────────────────────────────────
class MonitorTab extends StatelessWidget {
  final AppState currentState;
  final String transcribedText;
  final VoidCallback onStop;
  final bool isManualMode;
  final ValueChanged<bool> onToggleMode;
  final TextEditingController manualController;
  final ValueChanged<String> onManualTextChanged;

  const MonitorTab({super.key, required this.currentState, required this.transcribedText, required this.onStop, required this.isManualMode, required this.onToggleMode, required this.manualController, required this.onManualTextChanged});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: _buildContent());

  Widget _buildContent() {
    switch (currentState) {
      case AppState.safe:
      case AppState.danger:
        return _buildStandby();
      case AppState.listening:
        return _buildListening();
      case AppState.analyzing:
        return _buildAnalyzing();
    }
  }

  Widget _buildStandby() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(60), decoration: BoxDecoration(color: kGreen.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.shield_rounded, size: 160, color: kGreen)),
            const SizedBox(height: 32),
            const Text('Guard on Standby', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kNavy)),
            const Text('Protection is ready', style: TextStyle(fontSize: 22, color: kMuted)),
          ],
        ),
      ),
    );
  }

  // 🟢 Wrapped in SingleChildScrollView to prevent keyboard overflow!
  Widget _buildListening() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            if (!isManualMode)
              const PulsingMic()
            else
              const Icon(Icons.keyboard_rounded, size: 80, color: kGreen),
            const SizedBox(height: 30),
            Text(isManualMode ? 'Type the call transcript' : 'Listening...', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kNavy)),
            const SizedBox(height: 24),
            if (isManualMode)
              Container(
                decoration: BoxDecoration(color: kLightGray, borderRadius: BorderRadius.circular(24), border: Border.all(color: kGreen)),
                child: TextField(
                  controller: manualController,
                  onChanged: onManualTextChanged,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 22, color: kNavy),
                  decoration: const InputDecoration(
                    hintText: 'Paste or type call transcript here...',
                    hintStyle: TextStyle(fontSize: 20, color: kMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(24),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: kLightGray, borderRadius: BorderRadius.circular(24)),
                child: Text(transcribedText.isEmpty ? 'Waiting for speech...' : transcribedText, style: TextStyle(fontSize: 24, color: transcribedText.isEmpty ? kMuted : kNavy)),
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: onStop,
                style: ElevatedButton.styleFrom(backgroundColor: kDanger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                child: const Text('Analyze Now →', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🟢 Updated text to reflect the Local AI model instead of Gemini
  Widget _buildAnalyzing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: kGreen, strokeWidth: 8),
          const SizedBox(height: 32),
          const Text('Analyzing Intent...', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kNavy)),
          const Text('Local Neural Network is checking for threats', style: TextStyle(fontSize: 22, color: kMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LOGS TAB, SETTINGS TAB, PULSING MIC, INCOMING CALL SCREEN
// ─────────────────────────────────────────────
class LogsTab extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final int scamsBlocked;
  const LogsTab({super.key, required this.logs, required this.scamsBlocked});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
          child: Row(
            children: [
              const Text('Call History', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kNavy)), 
              const Spacer(), 
              if (logs.isNotEmpty) Text('$scamsBlocked scams blocked', style: const TextStyle(fontSize: 20, color: kDanger))
            ],
          ),
        ),
        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text('No calls yet', style: TextStyle(fontSize: 24, color: kMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) => _LogCard(log: logs[i]),
                ),
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final isDanger = log['danger'] as bool;
    final color = isDanger ? kDanger : kGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
      child: Row(
        children: [
          Icon(isDanger ? Icons.warning_rounded : Icons.check_circle_rounded, size: 36, color: color),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log['title'] as String, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                // 🟢 Added phone number display below the title
                Text(log['phone'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kMuted)),
                const SizedBox(height: 8),
                Text('"${log['preview']}"', style: const TextStyle(fontSize: 20, color: kNavy), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${log['risk']}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  final void Function(String) onTestScam;
  const SettingsTab({super.key, required this.onTestScam});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings coming soon...', style: TextStyle(fontSize: 28, color: kMuted)));
  }
}

class PulsingMic extends StatefulWidget {
  const PulsingMic({super.key});
  @override
  State<PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<PulsingMic> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: kGreen.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.mic_rounded, size: 90, color: kGreen),
      ),
    );
  }
}

class IncomingCallScreen extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const IncomingCallScreen({super.key, required this.onAccept, required this.onDecline});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final AudioPlayer _ringtone = AudioPlayer();
  
  @override
  void initState() {
    super.initState();
    _ringtone.setReleaseMode(ReleaseMode.loop);
    _ringtone.play(AssetSource('ringtone.wav'));
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
            const Icon(Icons.person_rounded, size: 100, color: Colors.white),
            const SizedBox(height: 16),
            const Text('Incoming Call', style: TextStyle(fontSize: 24, color: Colors.white70)),
            const SizedBox(height: 8),
            // 🟢 Added the phone number to the incoming call UI
            const Text('+91 98765 43210', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Unknown Caller', style: TextStyle(fontSize: 20, color: Colors.white54)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _callBtn(kDanger, Icons.call_end_rounded, 'Decline', widget.onDecline),
                _callBtn(kGreen, Icons.call_rounded, 'Accept', widget.onAccept),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _callBtn(Color color, IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(width: 80, height: 80, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, size: 40, color: Colors.white)),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 22)),
      ],
    );
  }
}