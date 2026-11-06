import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/auth/two_factor/authenticator_widgets.dart';
import 'package:starlink_app/services/api_service.dart';

const _primary = Color(0xFF133341);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _success = Color(0xFF10B981);
const _danger = Color(0xFFE90408);

/// "Two-factor authentication" card for Security Settings: shows whether an
/// authenticator app is linked and lets the user link one, re-link a new
/// phone, or turn 2FA off (when their role doesn't require it).
class TwoFactorSettingsCard extends StatefulWidget {
  const TwoFactorSettingsCard({super.key});

  @override
  State<TwoFactorSettingsCard> createState() => _TwoFactorSettingsCardState();
}

class _TwoFactorSettingsCardState extends State<TwoFactorSettingsCard> {
  bool _loading = true;
  bool _enabled = false;
  bool _required = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.getTwoFactorStatus();
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _loading = false;
      if (res['status'] == 'success' && data is Map) {
        _enabled = data['enabled'] == true;
        _required = data['required'] == true;
      } else {
        _error = 'Could not load two-factor status.';
      }
    });
  }

  Future<void> _openSetup() async {
    final linked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AuthenticatorSetupPage()),
    );
    if (linked == true) _load();
  }

  Future<void> _disable() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AppDialog(
            icon: Icons.shield_outlined,
            tone: AppDialogTone.danger,
            title: 'Turn off two-factor?',
            message:
                'Enter the current 6-digit code from your authenticator app '
                'to confirm.',
            content: TotpCodeField(
              controller: controller,
              autofocus: true,
              onCompleted: (v) => Navigator.pop(ctx, v),
            ),
            confirmLabel: 'Turn off',
            onConfirm: () => Navigator.pop(ctx, controller.text.trim()),
            cancelLabel: 'Cancel',
            onCancel: () => Navigator.pop(ctx),
          ),
    );
    controller.dispose();
    if (code == null || code.length != kTotpLength || !mounted) return;

    final res = await ApiService.disableTwoFactor(code);
    if (!mounted) return;
    final ok = res['status'] == 'success';
    AppToast.result(context, ok
              ? 'Two-factor authentication turned off'
              : (res['message']?.toString() ?? 'Could not turn it off'), ok: ok);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: _inkSecondary),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    final statusColor = _enabled ? _success : _inkSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: _primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Authenticator app',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  Text(
                    _enabled ? 'On' : 'Off',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _enabled
              ? 'Each sign-in asks for a code from Google Authenticator or '
                  'Microsoft Authenticator.'
              : 'Add a code from Google Authenticator or Microsoft '
                  'Authenticator to each sign-in for extra security.',
          style: const TextStyle(
            fontSize: 12,
            color: _inkSecondary,
            height: 1.45,
          ),
        ),
        if (_required)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Required for your account.',
              style: TextStyle(fontSize: 12, color: _inkSecondary),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _openSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 12,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_enabled ? 'Link new phone' : 'Set up'),
                ),
              ),
            ),
            if (_enabled && !_required) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _disable,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _danger,
                    side: const BorderSide(color: _danger),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Turn off'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Links (or re-links) an authenticator app for the signed-in user.
/// Pops `true` once the backend confirms the code.
class AuthenticatorSetupPage extends StatefulWidget {
  const AuthenticatorSetupPage({super.key});

  @override
  State<AuthenticatorSetupPage> createState() => _AuthenticatorSetupPageState();
}

class _AuthenticatorSetupPageState extends State<AuthenticatorSetupPage> {
  final _code = TextEditingController();
  AuthenticatorSetupInfo? _info;
  bool _loading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
    });
    final res = await ApiService.startTwoFactorSetup();
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _loading = false;
      _info =
          res['status'] == 'success' && data is Map
              ? AuthenticatorSetupInfo.fromMap(data)
              : null;
      
    });
    if (_info == null) {
      AppToast.error(
        context,
        res['message']?.toString() ?? 'Could not start authenticator setup.',
      );
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (_verifying || code.length != kTotpLength) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
    });
    final res = await ApiService.confirmTwoFactorSetup(code);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (res['status'] == 'success') {
      AppToast.success(context, 'Authenticator app linked');
      Navigator.pop(context, true);
    } else {
      _code.clear();
      AppToast.error(
        context,
        res['message']?.toString() ?? 'Invalid code. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authenticator app'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_info != null) ...[
                        AuthenticatorLinkPanel(info: _info!),
                        const SizedBox(height: 24),
                        TotpCodeField(
                          controller: _code,
                          enabled: !_verifying,
                          onCompleted: (_) => _confirm(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _verifying
                                  ? null
                                  : (_info == null ? _start : _confirm),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child:
                              _verifying
                                  ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    _info == null
                                        ? 'Try again'
                                        : 'Verify and turn on',
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
