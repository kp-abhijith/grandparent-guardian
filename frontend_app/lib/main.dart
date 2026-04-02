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
//  THEME CONSTANTS
// ─────────────────────────────────────────────
const kGreen     = Color(0xFF22C55E);
const kNavy      = Color(0xFF0F172A);
const kDanger    = Color(0xFFEF4444);
const kGold      = Color(0xFFF59E0B);
const kLightGray = Color(0xFFF8FAFC);
const kMuted     = Color(0xFF64748B);

const kBackendUrl = String.fromEnvironment('BACKEND_URL',
    defaultValue: 'http://192.168.1.3:8000');

// ─────────────────────────────────────────────
//  APP
// ─────────────────────────────────────────────
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
          titleLarge:   TextStyle(fontSize: 28, fontWeight: FontWeight.bold,  color: kNavy),
          bodyLarge:    TextStyle(fontSize: 24, color: kNavy),
          labelLarge:   TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

  AppState _currentState    = AppState.safe;
  String   _transcribedText = '';
  String   _accumulatedText = '';
  String   _analysisResult  = '';
  int      _scamProbability = 0;
  int      _scamsBlocked    = 0;
  int      _callsAnalyzed   = 0;

  final SpeechToText _speechToText  = SpeechToText();
  final AudioPlayer  _warningPlayer = AudioPlayer();
  final List<Map<String, dynamic>> _callLogs = [];

  bool _isManualMode = false;
  final TextEditingController _manualController = TextEditingController();
  final String _familyPhone = '919876543210';

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
    await _speechToText.initialize(
      onStatus: _onSpeechStatusChanged,
      onError:  (error) => print("Speech Error: $error"),
    );
  }

  void _onSpeechStatusChanged(String status) {
    if (_currentState != AppState.listening) return;

    if (status == 'done' || status == 'notListening') {
      // Lock in what we have, then restart
      _accumulatedText = _transcribedText;

      Future.delayed(const Duration(milliseconds: 400), () {
        if (_currentState == AppState.listening) {
          _startNewListenSession();
        }
      });
    }
  }

  Future<void> _startListening() async {
    if (_isManualMode) {
      setState(() {
        _currentState    = AppState.listening;
        _transcribedText = '';
        _accumulatedText = '';
      });
      return;
    }

    bool hasMic = false;
    if (!kIsWeb) {
      var micStatus = await Permission.microphone.request();
      hasMic = micStatus.isGranted;
    } else {
      hasMic = true;
    }

    if (!hasMic && !await _speechToText.hasPermission) {
      _showSnackBar('Microphone permission required. Use Manual mode.',
          color: Colors.orange);
      return;
    }

    if (_speechToText.isAvailable) {
      setState(() {
        _currentState    = AppState.listening;
        _transcribedText = '';
        _accumulatedText = '';
      });
      _startNewListenSession();
    } else {
      _showSnackBar('Speech recognition not available. Use Manual mode.',
          color: Colors.orange);
    }
  }

  // ─────────────────────────────────────────────
  //  ECHO FIX: capture baseText as LOCAL variable
  //  so every partial in THIS session compares
  //  against the SAME starting point — never shifts
  // ─────────────────────────────────────────────
  void _startNewListenSession() {
    // Snapshot accumulated text ONCE at session start
    // This is the key fix — local variable, not instance variable
    final String baseText = _accumulatedText.trim();

    _speechToText.listen(
      onResult: (result) {
        final String newWords = result.recognizedWords.trim();
        if (newWords.isEmpty) return;

        setState(() {
          if (baseText.isEmpty) {
            // First session — just use whatever STT gives
            _transcribedText = newWords;
          } else {
            final String newLower  = newWords.toLowerCase();
            final String baseLower = baseText.toLowerCase();

            if (newLower.startsWith(baseLower)) {
              // STT naturally remembered and continued from base
              // e.g. base="hello my name is", new="hello my name is John"
              _transcribedText = newWords;
            } else if (baseLower.contains(newLower)) {
              // STT sent a tiny fragment that's already inside base — ignore it
              // e.g. base="hello my name is John", new="John"
              _transcribedText = baseText;
            } else {
              // STT started completely fresh — safely append
              // e.g. base="hello my name is", new="good morning"
              _transcribedText = '$baseText $newWords'.trim();
            }
          }
        });
      },
      localeId:       'en_IN',
      listenMode:     ListenMode.dictation,
      partialResults: true,
      cancelOnError:  false,
      pauseFor:       const Duration(seconds: 10),
      listenFor:      const Duration(seconds: 15),
    );
  }

  Future<void> _stopListening() async {
    setState(() => _currentState = AppState.analyzing);
    if (!_isManualMode) await _speechToText.stop();
    if (_isManualMode && _transcribedText.isEmpty) {
      _transcribedText = _manualController.text.trim();
    }
    _analyzeCall();
  }

  Future<void> _analyzeCall() async {
    final textToAnalyze = _isManualMode
        ? _manualController.text.trim()
        : _transcribedText;

    if (textToAnalyze.isEmpty) {
      _showSnackBar('No text to analyze.', color: Colors.orange);
      setState(() { _currentState = AppState.safe; _currentIndex = 0; });
      return;
    }

    if (_isManualMode) setState(() => _transcribedText = textToAnalyze);

    try {
      final baseUrl = kIsWeb ? 'http://localhost:8000' : kBackendUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': textToAnalyze}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json     = jsonDecode(response.body);
        final prob     = (json['probability'] ?? 0) as int;
        final isScam   = json['status'] == 'scam_detected';
        final analysis = json['analysis'] ?? (isScam ? 'Scam detected.' : 'Call is safe.');
        final phone    = _isManualMode ? 'Manual Text Entry' : '+91 98765 43210';

        setState(() => _callsAnalyzed++);

        if (isScam) {
          setState(() => _scamsBlocked++);
          _playWarning();
          setState(() {
            _currentState    = AppState.danger;
            _analysisResult  = analysis;
            _scamProbability = prob;
            _callLogs.insert(0, {
              'title':   'Scam Caller',
              'phone':   phone,
              'preview': textToAnalyze,
              'risk':    prob,
              'danger':  true,
              'tactic':  analysis,
            });
          });
        } else {
          _showSnackBar('✓ Call is Safe ($prob% risk)', color: kGreen);
          setState(() {
            _currentState = AppState.safe;
            _currentIndex  = 0;
            _callLogs.insert(0, {
              'title':   'Safe Caller',
              'phone':   phone,
              'preview': textToAnalyze,
              'risk':    prob,
              'danger':  false,
              'tactic':  analysis,
            });
          });
        }
      } else {
        _showSnackBar('Server error: ${response.statusCode}', color: kDanger);
        setState(() { _currentState = AppState.safe; _currentIndex = 0; });
      }
    } catch (e) {
      _showSnackBar('Cannot reach backend. Check server is running.', color: kDanger);
      setState(() { _currentState = AppState.safe; _currentIndex = 0; });
    }
  }

  void _playWarning() {
    try {
      _warningPlayer.setReleaseMode(ReleaseMode.loop);
      _warningPlayer.play(AssetSource('warning.wav'));
    } catch (_) {}
  }

  Future<void> _alertFamily() async {
    _warningPlayer.stop();
    _showSnackBar('Transmitting SMS Alert...', color: kGold);

    try {
      final baseUrl = kIsWeb ? 'http://localhost:8000' : kBackendUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/alert-family'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transcript':   _transcribedText,
          'analysis':     _analysisResult,
          'probability':  _scamProbability,
          'family_phone': '8815572506',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSnackBar('✅ Family alerted via SMS!', color: kGreen);
      } else {
        _showSnackBar('Server error: ${response.statusCode}', color: kDanger);
      }
    } catch (e) {
      _showSnackBar('Network Error: Cannot reach server.', color: kDanger);
    }

    _manualController.clear();
    setState(() {
      _currentState    = AppState.safe;
      _currentIndex    = 0;
      _transcribedText = '';
      _accumulatedText = '';
      _analysisResult  = '';
      _scamProbability = 0;
    });
  }

  void _muteCall() {
    _warningPlayer.stop();
    _manualController.clear();
    setState(() {
      _currentState    = AppState.safe;
      _currentIndex    = 0;
      _transcribedText = '';
      _accumulatedText = '';
      _analysisResult  = '';
      _scamProbability = 0;
    });
  }

  void _showSnackBar(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontSize: 18, color: Colors.white)),
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
        onAccept:  () { Navigator.pop(context); _triggerProtection(); },
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
      HomeTab(
        onStartProtection: _triggerProtection,
        onDemoPitch:       _runDemoPitch,
        scamsBlocked:      _scamsBlocked,
        callsAnalyzed:     _callsAnalyzed,
      ),
      MonitorTab(
        currentState:        _currentState,
        transcribedText:     _transcribedText,
        onStop:              _stopListening,
        isManualMode:        _isManualMode,
        onToggleMode:        (v) => setState(() {
          _isManualMode = v;
          _manualController.clear();
        }),
        manualController:    _manualController,
        onManualTextChanged: (v) => setState(() => _transcribedText = v),
      ),
      LogsTab(logs: _callLogs, scamsBlocked: _scamsBlocked),
      SettingsTab(
        familyPhone: _familyPhone,
        onTestScam:  (text) {
          _manualController.text = text;
          _isManualMode = true;
          setState(() => _currentIndex = 1);
          _triggerProtection();
        },
      ),
    ];

    return Scaffold(
      body: SafeArea(
          child: IndexedStack(index: _currentIndex, children: pages)),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return BottomNavigationBar(
      currentIndex:         _currentIndex,
      onTap:                (i) => setState(() => _currentIndex = i),
      backgroundColor:      Colors.white,
      selectedItemColor:    kGreen,
      unselectedItemColor:  kMuted,
      type:                 BottomNavigationBarType.fixed,
      elevation:            8,
      selectedLabelStyle:   const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      unselectedLabelStyle: const TextStyle(fontSize: 14),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded,     size: 32), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.shield_rounded,   size: 32), label: 'Monitor'),
        BottomNavigationBarItem(icon: Icon(Icons.history_rounded,  size: 32), label: 'Logs'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_rounded, size: 32), label: 'Settings'),
      ],
    );
  }

  Widget _buildDangerState() {
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
            Text('$_scamProbability% RISK',
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
              child: Text(_analysisResult,
                  style: const TextStyle(
                      fontSize: 26, height: 1.4, color: kNavy),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 48),
            _bigButton('🔇  MUTE CALL',    kNavy,  _muteCall),
            const SizedBox(height: 20),
            _bigButton('🔔  ALERT FAMILY', kGreen, _alertFamily),
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

// ─────────────────────────────────────────────
//  HOME TAB
// ─────────────────────────────────────────────
class HomeTab extends StatelessWidget {
  final VoidCallback onStartProtection;
  final VoidCallback onDemoPitch;
  final int scamsBlocked;
  final int callsAnalyzed;

  const HomeTab({
    super.key,
    required this.onStartProtection,
    required this.onDemoPitch,
    required this.scamsBlocked,
    required this.callsAnalyzed,
  });

  @override
  Widget build(BuildContext context) {
    final safeCalls = callsAnalyzed - scamsBlocked;
    final safeRatio = callsAnalyzed == 0 ? 1.0 : safeCalls / callsAnalyzed;
    final scamRatio = callsAnalyzed == 0 ? 0.0 : scamsBlocked / callsAnalyzed;

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

          // ── Threat Intelligence Card ──────────────
          Container(
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
                    Text('$callsAnalyzed Total Calls',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kNavy)),
                    Text('$scamsBlocked Blocked',
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
                            flex: (scamRatio * 100).toInt(),
                            child: Container(color: kDanger)),
                        if (callsAnalyzed == 0)
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
                    if (callsAnalyzed > 0)
                      const Text('Scam Risk',
                          style: TextStyle(
                              color: kDanger,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
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

// ─────────────────────────────────────────────
//  MONITOR TAB
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
//  LOGS TAB
// ─────────────────────────────────────────────
class LogsTab extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final int scamsBlocked;
  const LogsTab(
      {super.key, required this.logs, required this.scamsBlocked});

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
            if (logs.isNotEmpty)
              Text('$scamsBlocked blocked',
                  style: const TextStyle(
                      fontSize: 20,
                      color: kDanger,
                      fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
          child: logs.isEmpty
              ? const Center(
                  child: Text('No calls yet',
                      style:
                          TextStyle(fontSize: 24, color: kMuted)))
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32),
                  itemCount:   logs.length,
                  itemBuilder: (ctx, i) =>
                      _LogCard(log: logs[i]),
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
    final color    = isDanger ? kDanger : kGreen;
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
                Text(log['title'] as String,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(log['phone'] as String,
                    style: const TextStyle(
                        fontSize: 16, color: kMuted)),
                const SizedBox(height: 6),
                Text('"${log['preview']}"',
                    style: const TextStyle(
                        fontSize: 20, color: kNavy),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if ((log['tactic'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(log['tactic'] as String,
                      style: TextStyle(
                          fontSize: 16,
                          color: color.withOpacity(0.8),
                          fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${log['risk']}%',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SETTINGS TAB
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
//  PULSING MIC
// ─────────────────────────────────────────────
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
          CurvedAnimation(
              parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
            color: kGreen.withOpacity(0.1),
            shape: BoxShape.circle),
        child: const Icon(Icons.mic_rounded,
            size: 90, color: kGreen),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  INCOMING CALL SCREEN (DEMO)
// ─────────────────────────────────────────────
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
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                _callBtn(kDanger, Icons.call_end_rounded,
                    'Decline', () {
                  _ringtone.stop();
                  widget.onDecline();
                }),
                _callBtn(
                    kGreen, Icons.call_rounded, 'Accept',
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
            child:
                Icon(icon, size: 40, color: Colors.white),
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