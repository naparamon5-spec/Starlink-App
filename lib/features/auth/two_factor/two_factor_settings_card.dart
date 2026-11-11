import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/auth/two_factor/authenticator_widgets.dart';
import 'package:starlink_app/features/security/security_icon_tile.dart';
import 'package:starlink_app/services/api_service.dart';

const _primary = Color(0xFF133341);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _success = Color(0xFF10B981);

/// "Two-factor authentication" card for Security Settings: a switch that links
/// an authenticator app or turns 2FA off (when their role doesn't require it),
/// plus re-linking a new phone.
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
    // Replacing a linked app needs a code from it (the backend refuses
    // otherwise), so a stolen session can't move it to another phone.
    String? currentCode;
    if (_enabled) {
      currentCode = await showDialog<String>(
        context: context,
        builder:
            (_) => const _CurrentCodeDialog(
              title: 'Link a new phone?',
              message:
                  'Enter the current 6-digit code from the authenticator app '
                  "you're replacing. Lost that phone? Ask an admin to reset "
                  'two-step sign-in.',
              confirmLabel: 'Continue',
            ),
      );
      if (currentCode == null || currentCode.length != kTotpLength || !mounted) {
        return;
      }
    }
    final linked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AuthenticatorSetupPage(currentCode: currentCode),
      ),
    );
    if (linked == true) _load();
  }

  Future<void> _disable() async {
    final code = await showDialog<String>(
      context: context,
      builder:
          (_) => const _CurrentCodeDialog(
            title: 'Turn off two-factor?',
            message:
                'Enter the current 6-digit code from your authenticator app '
                'to confirm.',
            confirmLabel: 'Turn off',
            danger: true,
          ),
    );
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

    final locked = _enabled && _required;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SecurityIconTile(Icons.verified_user_outlined),
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
                  const SizedBox(height: 2),
                  Text(
                    _enabled ? 'On' : 'Off',
                    style: TextStyle(
                      fontSize: 12,
                      color: _enabled ? _success : _inkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _enabled,
              onChanged:
                  locked
                      ? null
                      : (on) {
                        if (on) {
                          _openSetup();
                        } else {
                          _disable();
                        }
                      },
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
        if (_enabled)
          TextButton(
            onPressed: _openSetup,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Link a new phone'),
          ),
      ],
    );
  }
}

/// Asks for a current code. Owns its controller so it outlives the dialog's
/// closing animation.
class _CurrentCodeDialog extends StatefulWidget {
  const _CurrentCodeDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.danger = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  @override
  State<_CurrentCodeDialog> createState() => _CurrentCodeDialogState();
}

class _CurrentCodeDialogState extends State<_CurrentCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: Icons.shield_outlined,
      tone: widget.danger ? AppDialogTone.danger : AppDialogTone.primary,
      title: widget.title,
      message: widget.message,
      content: TotpCodeField(
        controller: _controller,
        autofocus: true,
        onCompleted: (v) => Navigator.pop(context, v),
      ),
      confirmLabel: widget.confirmLabel,
      onConfirm: () => Navigator.pop(context, _controller.text.trim()),
      cancelLabel: 'Cancel',
      onCancel: () => Navigator.pop(context),
    );
  }
}

/// Links (or re-links) an authenticator app for the signed-in user.
/// Pops `true` once the backend confirms the code.
class AuthenticatorSetupPage extends StatefulWidget {
  const AuthenticatorSetupPage({super.key, this.currentCode});

  /// A code from the app being replaced; required when one is already linked.
  final String? currentCode;

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
    final res = await ApiService.confirmTwoFactorSetup(
      code,
      currentCode: widget.currentCode,
    );
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
