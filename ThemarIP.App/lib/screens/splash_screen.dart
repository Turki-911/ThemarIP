import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ApiService _apiService = ApiService();

  // Status tracking
  double _progress = 0.15;
  String _statusMessage = 'Initializing system kernel...';
  String _statusSubtext = 'Loading local cryptographic modules';
  bool _hasError = false;
  String? _errorDetails;
  ApiHealthResult? _healthResult;

  @override
  void initState() {
    super.initState();
    _startSystemBootstrap();
  }

  Future<void> _startSystemBootstrap() async {
    setState(() {
      _progress = 0.20;
      _statusMessage = 'Initializing system kernel...';
      _statusSubtext = 'Loading local configuration and network settings';
      _hasError = false;
      _errorDetails = null;
    });

    await ApiConfig.loadSavedHost();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Step 2: Check backend infrastructure & database
    setState(() {
      _progress = 0.55;
      _statusMessage = 'Verifying API & database connection...';
      _statusSubtext =
          'Connecting to ${ApiConfig.baseUrl} (themarip.db)';
    });

    final health = await _apiService.checkHealth();
    if (!mounted) return;

    _healthResult = health;

    if (!health.isHealthy) {
      // Backend is offline or degraded
      setState(() {
        _hasError = true;
        _errorDetails = health.errorMessage ??
            'Could not reach ThemarIP backend on ${health.endpoint}.';
        _statusMessage = 'Backend Connection Offline';
        _statusSubtext = 'Unable to connect to ${ApiConfig.baseUrl}';
        _progress = 0.55;
      });
      return;
    }

    // Step 3: Success connection
    setState(() {
      _progress = 0.85;
      _statusMessage = 'Database synchronized';
      _statusSubtext =
          'Connected to ${health.dbProvider} (${health.dbCategories} categories verified, ${health.latencyMs}ms latency)';
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Step 4: Verify authentication session
    setState(() {
      _progress = 1.0;
      _statusMessage = 'System Ready';
      _statusSubtext = 'Launching application workspace...';
    });

    final token = await AuthService.getToken();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // Returning authorized user -> Ingestion & Statement upload
      Navigator.of(context).pushReplacementNamed('/upload');
    } else {
      // First-time user -> Onboarding walkthrough
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  void _proceedAnyway() async {
    final token = await AuthService.getToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/upload');
    } else {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiConfig.activeHost);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161226),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderGlow),
        ),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: AppTheme.neonPink, size: 22),
            SizedBox(width: 10),
            Text(
              'Server Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'When testing on a physical iPhone, enter your Mac\'s Wi-Fi or Hotspot IP address:',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Host IP or Domain',
                hintText: '172.20.10.5',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixText: ':5267',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Quick presets:',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('🌐 Live Cloud (HTTPS)'),
                  backgroundColor: AppTheme.neonPink.withValues(alpha: 0.2),
                  labelStyle: const TextStyle(fontSize: 11, color: AppTheme.neonPink, fontWeight: FontWeight.bold),
                  onPressed: () => controller.text = ApiConfig.livePublicApiUrl,
                ),
                ActionChip(
                  label: const Text('172.20.10.5 (Mac)'),
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                  labelStyle: const TextStyle(fontSize: 11, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
                  onPressed: () => controller.text = '172.20.10.5',
                ),
                ActionChip(
                  label: const Text('localhost'),
                  backgroundColor: Colors.white10,
                  labelStyle: const TextStyle(fontSize: 11, color: Colors.white70),
                  onPressed: () => controller.text = 'localhost',
                ),
                ActionChip(
                  label: const Text('10.0.2.2 (Android)'),
                  backgroundColor: Colors.white10,
                  labelStyle: const TextStyle(fontSize: 11, color: Colors.white70),
                  onPressed: () => controller.text = '10.0.2.2',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ApiConfig.setCustomHost(controller.text);
              _startSystemBootstrap();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save & Reconnect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07050E),
      body: Stack(
        children: [
          // Ambient Glow Effect 1 (Top Left Electric Violet)
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.electricViolet.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Ambient Glow Effect 2 (Bottom Right Neon Pink)
          Positioned(
            bottom: -140,
            right: -140,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonPink.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Central Main Card & Branding
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Shield / Emblem with Pulse Animation
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Pulsing Glow Ring
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1.15, 1.15),
                              duration: 1800.ms,
                              curve: Curves.easeInOut,
                            )
                            .fadeIn(duration: 800.ms),

                        // Middle Glow Ring
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.neonPink.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(1.05, 1.05),
                              end: const Offset(0.95, 0.95),
                              duration: 2200.ms,
                              curve: Curves.easeInOut,
                            ),

                        // Core Logo Box (Glassmorphic)
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.electricViolet.withValues(alpha: 0.45),
                                blurRadius: 36,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: AppTheme.neonPink.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.credit_card_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        )
                            .animate()
                            .scale(
                              duration: 900.ms,
                              curve: Curves.easeOutBack,
                            )
                            .shimmer(
                              delay: 900.ms,
                              duration: 1800.ms,
                              color: Colors.white24,
                            ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // App Title & Typography
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Themar',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'IP',
                            style: TextStyle(
                              color: AppTheme.neonPink,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: AppTheme.neonPink.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).moveY(begin: 16, end: 0),
                    const SizedBox(height: 8),

                    // Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: AppTheme.primaryPurple,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'BANK MUSCAT PFM INTELLIGENCE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryPurple,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).moveY(begin: 10, end: 0),
                    const SizedBox(height: 12),

                    Text(
                      'Automated Statement Extraction & Multi-Tier Analytics',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted.withValues(alpha: 0.8),
                        letterSpacing: 0.2,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 44),

                    // Diagnostic Loading / Connection Section
                    if (!_hasError) ...[
                      // Progress Bar
                      Container(
                        width: double.infinity,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.centerLeft,
                          widthFactor: _progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.neonPink.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status Information Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_progress < 1.0)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.neonPink,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppTheme.emeraldGreen,
                            ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _statusMessage,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusSubtext,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                    ] else ...[
                      // Connection Error / Diagnostics Panel
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1428),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.wifi_off_rounded,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Backend Connection Notice',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'Target: ${ApiConfig.baseUrl}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorDetails ??
                                  'Ensure that ThemarIP.API is active and your phone is on the same Wi-Fi.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _startSystemBootstrap,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPurple,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _showServerConfigDialog,
                                  icon: const Icon(
                                    Icons.settings_ethernet_rounded,
                                    size: 15,
                                  ),
                                  label: const Text('Change IP'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: _proceedAnyway,
                                  child: const Text(
                                    'Skip',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).scale(
                            begin: const Offset(0.95, 0.95),
                            curve: Curves.easeOut,
                          ),
                    ],

                    const SizedBox(height: 48),

                    // Live Infrastructure Diagnostics Badge (Clickable to edit IP)
                    InkWell(
                      onTap: _showServerConfigDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF110D20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDiagnosticBadge(
                              label: 'Host IP',
                              value: ApiConfig.activeHost,
                              isSuccess: _healthResult?.isHealthy == true,
                            ),
                            Container(
                              height: 16,
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              color: Colors.white12,
                            ),
                            _buildDiagnosticBadge(
                              label: 'Database',
                              value: 'themarip.db',
                              isSuccess: _healthResult?.isHealthy == true,
                            ),
                            Container(
                              height: 16,
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              color: Colors.white12,
                            ),
                            _buildDiagnosticBadge(
                              label: 'Security',
                              value: 'JWT/Bearer',
                              isSuccess: true,
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: AppTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Version & Copyright
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'ThemarIP Financial Intelligence v2.4 • Omani Banking Sandbox',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticBadge({
    required String label,
    required String value,
    required bool isSuccess,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSuccess ? AppTheme.emeraldGreen : Colors.amber,
            boxShadow: [
              BoxShadow(
                color: (isSuccess ? AppTheme.emeraldGreen : Colors.amber)
                    .withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: AppTheme.textMuted.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
