import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const GrandparentGuardianApp());
}

class GrandparentGuardianApp extends StatelessWidget {
  const GrandparentGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grandparent Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[50],
        primaryColor: const Color(0xFF0F172A),
        useMaterial3: true,
      ),
      home: const MainDashboard(),
    );
  }
}

enum AppState { safe, listening, analyzing, danger }

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  // Hoisted state from legacy GuardianScreen
  AppState _currentState = AppState.safe;
  String _transcribedText = '';
  String _analysisResult = '';
  int _scamProbability = 0;
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _warningPlayer = AudioPlayer();
  final List<Map<String, dynamic>> _callLogs = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speechToText.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            _transcribedText.isNotEmpty &&
            _currentState == AppState.listening) {
          _stopListening();
        }
      },
    );
  }

  Future<void> _startListening() async {
    bool hasMic = false;
    if (kIsWeb) {
      hasMic = true; // Web handles its own mic requests securely via browser prompts
    } else {
      var micStatus = await Permission.microphone.request();
      hasMic = micStatus.isGranted;
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
            setState(() {
              _transcribedText = result.recognizedWords;
            });
          },
          localeId: 'en_IN',
        );
      } else {
        _showSnackBar('Speech recognition not available on this device.');
      }
    } else {
      _showSnackBar('Microphone permission required.');
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _currentState = AppState.analyzing;
    });
    _analyzeCall();
  }

  Future<void> _analyzeCall() async {
    if (_transcribedText.isEmpty) {
      _showSnackBar('No speech detected during scan.', backgroundColor: Colors.orange);
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _currentState = AppState.safe;
        _currentIndex = 0;
      });
      return;
    }
    
    try {
      String baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://192.168.137.55:8000'; 
      
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': _transcribedText}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        int parsedProb = jsonResponse['probability'] ?? 0;
        
        if (jsonResponse['status'] == 'scam_detected') {
          await _speechToText.stop();
          if (mounted) {
            _warningPlayer.setReleaseMode(ReleaseMode.loop);
            _warningPlayer.play(AssetSource('warning.wav'));
            setState(() {
              _currentState = AppState.danger;
              _analysisResult = jsonResponse['analysis'] ?? 'Danger! Proceed with caution.';
              _scamProbability = parsedProb;
              _callLogs.insert(0, {
                 'number': 'Scam Caller',
                 'preview': _transcribedText,
                 'risk': parsedProb,
                 'danger': true
              });
            });
            // Auto-hangup happens instantly by jumping to danger.
          }
        } else {
          _showSnackBar('✓ Analysis complete: Call is Safe.', backgroundColor: Colors.green);
          setState(() {
            _currentState = AppState.safe;
            _currentIndex = 0;
            _callLogs.insert(0, {
                 'number': 'Safe Caller',
                 'preview': _transcribedText,
                 'risk': parsedProb,
                 'danger': false
            });
          });
        }
      } else {
        _showSnackBar('Connection Failed: Server returned status ${response.statusCode}', backgroundColor: Colors.red);
        setState(() {
          _currentState = AppState.safe;
          _currentIndex = 0;
        });
      }
    } catch (e) {
      _showSnackBar('Connection Failed: $e', backgroundColor: Colors.red);
      setState(() {
        _currentState = AppState.safe;
        _currentIndex = 0;
      });
    }
  }
  void _muteCall() {
    _warningPlayer.stop();
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Family Alerted Successfully!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
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

  void _showSnackBar(String msg, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 20, color: Colors.white)),
      backgroundColor: backgroundColor,
    ));
  }

  void _triggerProtection() {
    setState(() {
      _currentIndex = 1;
    });
    _startListening();
  }

  void _runDemoPitch() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => IncomingCallScreen(
        onAccept: () {
          Navigator.pop(context);
          _triggerProtection();
        },
        onDecline: () {
          Navigator.pop(context);
        },
      ),
    ));
  }

  void _showScamDialog(String analysis) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.red, width: 8),
          ),
          contentPadding: const EdgeInsets.all(30),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_rounded, color: Colors.red, size: 90),
              const SizedBox(height: 20),
              const Text(
                '⚠️ SCAM CALL DISCONNECTED ⚠️',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              Text(
                analysis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF333333), fontSize: 24, fontWeight: FontWeight.w600, height: 1.4),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 70),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Acknowledge', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == AppState.danger) {
      return Scaffold(
        backgroundColor: Colors.red,
        body: SafeArea(
          child: _buildDangerState(),
        ),
      );
    }

    final List<Widget> pages = [
      HomeTab(
        onStartProtection: _triggerProtection,
        onDemoPitch: _runDemoPitch,
      ),
      MonitorTab(
        currentState: _currentState,
        transcribedText: _transcribedText,
        onStop: _stopListening,
      ),
      LogsTab(logs: _callLogs),
      const SettingsTab(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0F172A),
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.shield_rounded), label: 'Monitor'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildDangerState() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 180, color: Colors.white),
          const SizedBox(height: 20),
          const Text(
            '⚠️ SCAM DETECTED ⚠️',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '$_scamProbability% PROBABILITY',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.yellowAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              _analysisResult,
              style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 80),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 25),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: const Size(double.infinity, 80),
            ),
            onPressed: _muteCall,
            child: const Text('MUTE CALL', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 25),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: const Size(double.infinity, 80),
            ),
            onPressed: _alertFamily,
            child: const Text('ALERT FAMILY', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ======================= HOME TAB =======================
class HomeTab extends StatelessWidget {
  final VoidCallback onStartProtection;
  final VoidCallback onDemoPitch;
  const HomeTab({super.key, required this.onStartProtection, required this.onDemoPitch});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.shield_rounded, size: 120, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            'Grandparent Guardian',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your personal AI shield against scam calls.',
            style: TextStyle(fontSize: 22, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              minimumSize: const Size(double.infinity, 80),
              elevation: 4,
            ),
            onPressed: onStartProtection,
            child: const Text('Start Protection →', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF0F172A), width: 3),
              ),
              minimumSize: const Size(double.infinity, 75),
              elevation: 0,
            ),
            onPressed: onDemoPitch,
            icon: const Icon(Icons.play_circle_fill_rounded, size: 36),
            label: const Text('Run Demo Pitch', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 50),
          _buildFeatureCard(Icons.mic_rounded, 'Real-time Analysis'),
          const SizedBox(height: 16),
          _buildFeatureCard(Icons.notifications_active_rounded, 'Instant Alerts'),
          const SizedBox(height: 16),
          _buildFeatureCard(Icons.family_restroom_rounded, 'Caregiver Sync'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(width: 20),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

// ======================= MONITOR TAB =======================
class MonitorTab extends StatelessWidget {
  final AppState currentState;
  final String transcribedText;
  final VoidCallback onStop;

  const MonitorTab({super.key, required this.currentState, required this.transcribedText, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStateContent(),
      ),
    );
  }

  Widget _buildStateContent() {
    switch (currentState) {
      case AppState.safe:
      case AppState.danger: // Handled globally by scaffold overriding, fallback safely here.
        return _buildSafe();
      case AppState.listening:
        return _buildActive();
      case AppState.analyzing:
        return _buildAnalyzing();
    }
  }

  Widget _buildSafe() {
    return Column(
      key: const ValueKey('monitor_safe'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(50),
          decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
          child: const Icon(Icons.shield_outlined, size: 140, color: Colors.green),
        ),
        const SizedBox(height: 40),
        Text('Guard on Standby', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildActive() {
    return Padding(
      key: const ValueKey('monitor_active'),
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PulsingMic(),
            const SizedBox(height: 40),
            const Text('Listening...', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(24),
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: SingleChildScrollView(
                child: Text(
                  transcribedText.isEmpty ? 'Waiting for speech...' : transcribedText,
                  style: const TextStyle(fontSize: 26, color: Color(0xFF0F172A), height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                minimumSize: const Size(double.infinity, 80),
                elevation: 0,
              ),
              onPressed: onStop,
              child: const Text('Stop Scanner', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzing() {
    return Column(
      key: const ValueKey('monitor_analyzing'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(color: Color(0xFF0F172A), strokeWidth: 10),
        ),
        const SizedBox(height: 50),
        const Text('Analyzing Call...', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }
}

// ======================= LOGS TAB =======================
class LogsTab extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const LogsTab({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('Call History', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 20),
          Expanded(
            child: logs.isEmpty 
              ? Center(child: Text("No recorded calls yet.", style: TextStyle(fontSize: 20, color: Colors.grey[400])))
              : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final isDanger = log['danger'] as bool;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildLogCard(
                    icon: isDanger ? Icons.warning_rounded : Icons.check_circle_rounded,
                    iconColor: isDanger ? Colors.red : Colors.green,
                    bgColor: isDanger ? Colors.red.withOpacity(0.05) : Colors.white,
                    number: log['number'],
                    preview: '"${log['preview']}"',
                    riskText: '${log['risk']}% Risk',
                    riskColor: isDanger ? Colors.red : Colors.green,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String number,
    required String preview,
    required String riskText,
    required Color riskColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: bgColor == Colors.white ? Border.all(color: Colors.grey[200]!) : null,
        boxShadow: bgColor == Colors.white ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)] : [],
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(preview, style: TextStyle(fontSize: 18, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(riskText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: riskColor)),
        ],
      ),
    );
  }
}

// ======================= SETTINGS TAB =======================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _sensitivity = 0.5;
  bool _loudWarning = true;
  bool _autoMute = false;
  bool _smsAlert = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('Settings', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 30),
          
          _buildSettingsCard(
            title: 'Emergency Contacts',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('kp abhijith', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text('(555) 123-4567', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Edit', style: TextStyle(fontSize: 20, color: Colors.blue)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          _buildSettingsCard(
            title: 'Scanner Sensitivity',
            child: Column(
              children: [
                Slider(
                  value: _sensitivity,
                  activeColor: const Color(0xFF0F172A),
                  inactiveColor: Colors.grey[300],
                  onChanged: (val) => setState(() => _sensitivity = val),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Relaxed', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      Text('Strict', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSettingsCard(
            title: 'Alert Preferences',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Loud Audio Warning', style: TextStyle(fontSize: 22, color: Color(0xFF0F172A))),
                  activeColor: const Color(0xFF0F172A),
                  value: _loudWarning,
                  onChanged: (val) => setState(() => _loudWarning = val),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Mute on Scam', style: TextStyle(fontSize: 22, color: Color(0xFF0F172A))),
                  activeColor: const Color(0xFF0F172A),
                  value: _autoMute,
                  onChanged: (val) => setState(() => _autoMute = val),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('SMS Alert to Family', style: TextStyle(fontSize: 22, color: Color(0xFF0F172A))),
                  activeColor: const Color(0xFF0F172A),
                  value: _smsAlert,
                  onChanged: (val) => setState(() => _smsAlert = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class PulsingMic extends StatefulWidget {
  const PulsingMic({super.key});

  @override
  State<PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<PulsingMic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic_rounded, size: 80, color: Color(0xFF0F172A)),
      ),
    );
  }
}

// ======================= DEMO SCREENS =======================
class IncomingCallScreen extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    _ringtonePlayer.play(AssetSource('ringtone.wav'));
  }

  @override
  void dispose() {
    _ringtonePlayer.stop();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 100),
            const Text(
              'Incoming Demo Call...',
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w400, color: Colors.white),
            ),
            const SizedBox(height: 15),
            const Text(
              '8815572506',
              style: TextStyle(fontSize: 26, color: Colors.white70),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    FloatingActionButton.large(
                      heroTag: 'declineBtn',
                      backgroundColor: Colors.red,
                      onPressed: () {
                        _ringtonePlayer.stop();
                        widget.onDecline();
                      },
                      elevation: 0,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 45),
                    ),
                    const SizedBox(height: 15),
                    const Text('Decline', style: TextStyle(color: Colors.white, fontSize: 20)),
                  ],
                ),
                Column(
                  children: [
                    FloatingActionButton.large(
                      heroTag: 'acceptBtn',
                      backgroundColor: Colors.green,
                      onPressed: () {
                        _ringtonePlayer.stop();
                        widget.onAccept();
                      },
                      elevation: 0,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.call, color: Colors.white, size: 45),
                    ),
                    const SizedBox(height: 15),
                    const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 20)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}