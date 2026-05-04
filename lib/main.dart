import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/payment_result_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HarayaApp());
}

class HarayaApp extends StatelessWidget {
  const HarayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haraya',
      theme: harayaTheme(),
      debugShowCheckedModeBanner: false,
      home: const _AppLifecycleWrapper(child: _SplashGate()),
    );
  }
}

/// Wrapper to handle app lifecycle events for payment result checking
class _AppLifecycleWrapper extends StatefulWidget {
  final Widget child;
  const _AppLifecycleWrapper({required this.child});

  @override
  State<_AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<_AppLifecycleWrapper> 
    with WidgetsBindingObserver {
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      setState(() {
        _currentUser = jsonDecode(userData) as Map<String, dynamic>;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check for payment result when app resumes from background
    if (state == AppLifecycleState.resumed && _currentUser != null) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        await PaymentResultService.checkPendingPaymentResult(
          context: context,
          user: _currentUser!,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Check if user is already logged in (has stored session)
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
  await Future.delayed(const Duration(milliseconds: 800));

  final prefs = await SharedPreferences.getInstance();
  final userData = prefs.getString('user_data');

  if (!mounted) return;

  if (userData != null) {
    final user = jsonDecode(userData) as Map<String, dynamic>;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(user: user),
      ),
    );
  } else {
    // 👇 GUEST MODE (NO LOGIN REQUIRED)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(
          user: {
            "fname": "Guest",
            "role": "guest",
            "email": "",
          },
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFE8DB),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AnimatedLogo(),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: Color(0xFF5682B1),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF5682B1), Color(0xFF739EC9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: Color(0x445682B1), blurRadius: 20, offset: Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.home_rounded, color: Colors.white, size: 46),
            ),
            const SizedBox(height: 16),
            const Text(
              'Haraya',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222831),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Community Marketplace',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFF888888),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
