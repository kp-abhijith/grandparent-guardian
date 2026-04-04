import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import 'firebase_options.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/sms_service.dart';
import 'screens/home_tab.dart';
import 'screens/monitor_tab.dart';
import 'screens/logs_tab.dart';
import 'screens/settings_tab.dart';
import 'screens/danger_screen.dart';
import 'widgets/incoming_call_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase init failed (offline mode): $e');
  }
  runApp(const GrandparentGuardianApp());
}

class GrandparentGuardianApp extends StatelessWidget {
  const GrandparentGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grandparent Guardian',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const MainDashboard(),
    );
  }
}

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
  String   _documentId      = '';

  final SpeechToText _speechToText  = SpeechToText();
  final AudioPlayer  _warningPlayer = AudioPlayer();

  bool _isManualMode = false;
  final TextEditingController _manualController = TextEditingController();
  final String _familyPhone = '919876543210';

  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();
  String _userId = '';



  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        setState(() => _userId = user.uid);
      } else {
        final newUser = await _authService.signInAnonymously();
        if (newUser != null) {
          setState(() => _userId = newUser.uid);
        }
      }
    } catch (e) {
      debugPrint('Auth failed (offline mode): $e');
    }
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

  void _startNewListenSession() {
    final String baseText = _accumulatedText.trim();
    debugPrint('[DEBUG] _startNewListenSession, baseText: "$baseText"');

    _speechToText.listen(
      onResult: (result) {
        final String newWords = result.recognizedWords.trim();
        debugPrint('[DEBUG] Speech recognized: "$newWords", confidence: ${result.confidence}');
        if (newWords.isEmpty) return;

        setState(() {
          if (baseText.isEmpty) {
            _transcribedText = newWords;
          } else {
            final String newLower  = newWords.toLowerCase();
            final String baseLower = baseText.toLowerCase();

            if (newLower.startsWith(baseLower)) {
              _transcribedText = newWords;
            } else if (baseLower.contains(newLower)) {
              _transcribedText = baseText;
            } else {
              _transcribedText = '$baseText $newWords'.trim();
            }
          }
        });
        debugPrint('[DEBUG] Updated transcribedText: "$_transcribedText"');
      },
      localeId:       'en-IN',
      listenMode:     ListenMode.dictation,
      partialResults: true,
      cancelOnError:  false,
      pauseFor:       const Duration(seconds: 10),
      listenFor:      const Duration(seconds: 15),
    );
  }

  Future<void> _stopListening() async {
    debugPrint('[DEBUG] _stopListening called, isManualMode: $_isManualMode');
    setState(() => _currentState = AppState.analyzing);
    if (!_isManualMode) await _speechToText.stop();
    if (_isManualMode) {
      final manualText = _manualController.text.trim();
      debugPrint('[DEBUG] Manual text from controller: "$manualText"');
      setState(() => _transcribedText = manualText);
    }
    _analyzeCall();
  }

  Future<void> _analyzeCall() async {
    final textToAnalyze = _isManualMode
        ? _manualController.text.trim()
        : _transcribedText;

    if (textToAnalyze.isEmpty) {
      _showSnackBar('No text to analyze.', color: Colors.orange);
      return;
    }

    // Build URL properly - kBackendUrl already has http://
    final String targetUrl = kIsWeb ? 'localhost:8000' : kBackendUrl.split('://').last;
    final baseUrl = 'http://$targetUrl';
    debugPrint('Connecting to: $baseUrl');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': textToAnalyze}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json     = jsonDecode(response.body);
        final prob     = (json['probability'] ?? 0) as int;
        final isScam   = json['status'] == 'scam_detected';
        final analysis = json['analysis'] ?? (isScam ? 'Scam detected.' : 'Call is safe.');
        final phone   = _isManualMode ? 'Manual Text Entry' : '+91 98765 43210';

        // Save to Firestore (if user logged in)
        if (_userId.isNotEmpty) {
          try {
            final docId = await _firebaseService.addScamLog(
              userId:  _userId,
              title:   isScam ? 'Scam Caller' : 'Safe Caller',
              phone:   phone,
              preview: textToAnalyze,
              risk:    prob,
              danger:  isScam,
              tactic:  analysis,
            );
            if (isScam) _documentId = docId;
          } catch (_) {
            // Firestore failed - continue anyway
          }
        }

        if (isScam) {
          _playWarning();
          setState(() {
            _currentState    = AppState.danger;
            _analysisResult  = analysis;
            _scamProbability = prob;
          });
        } else {
          _showSnackBar('✓ Call is Safe ($prob% risk)', color: kGreen);
          setState(() => _currentState = AppState.safe);
        }
      } else {
        _showSnackBar('⚠ Server error: ${response.statusCode}', color: Colors.red);
      }
    } catch (e) {
      _showSnackBar('⚠ Cannot connect to $baseUrl', color: Colors.red);
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
      final result = await SmsService.alertFamily(
        transcript:  _transcribedText,
        analysis:    _analysisResult,
        probability: _scamProbability,
        familyPhone: '6263758539',
      );

      if (result['success'] == true) {
        _showSnackBar('✅ Family alerted via SMS!', color: kGreen);
      } else {
        _showSnackBar(result['error'] ?? 'SMS failed', color: kDanger);
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
      _documentId      = '';
    });
  }

  Future<void> _blockCaller() async {
    if (_documentId.isEmpty) return;
    await _firebaseService.blockCaller(_documentId);
    _showSnackBar('Caller Blocked ✓', color: kGreen);
    _warningPlayer.stop();
    _manualController.clear();
    setState(() {
      _currentState    = AppState.safe;
      _currentIndex    = 0;
      _transcribedText = '';
      _accumulatedText = '';
      _analysisResult  = '';
      _scamProbability = 0;
      _documentId      = '';
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
      _documentId      = '';
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
      return Scaffold(
        body: SafeArea(
          child: DangerScreen(
            scamProbability: _scamProbability,
            analysisResult:  _analysisResult,
            onMute:          _muteCall,
            onAlertFamily:   _alertFamily,
            onBlock:         _blockCaller,
          ),
        ),
      );
    }

    final pages = [
      HomeTab(
        onStartProtection: _triggerProtection,
        onDemoPitch:       _runDemoPitch,
        userId:            _userId,
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
      LogsTab(userId: _userId),
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
}
