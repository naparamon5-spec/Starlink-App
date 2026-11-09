import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/security/security_icon_tile.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/services/biometric_service.dart';
import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';

/// On/off switch for biometric login, same as ANI HRIS: changing it asks for
/// the account password.
class BiometricSettingsCard extends StatefulWidget {
  const BiometricSettingsCard({super.key});

  @override
  State<BiometricSettingsCard> createState() => _BiometricSettingsCardState();
}

class _BiometricSettingsCardState extends State<BiometricSettingsCard> {
  bool _loading = true;
  bool _available = false;
  bool _enabled = false;
  bool _busy = false;
  BiometricMethod _method = BiometricMethod.pin;

  @override
  void initState() {
    super.initState();
    BiometricService.enrollmentChanges.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    BiometricService.enrollmentChanges.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnrolled();
    final method = await BiometricService.bestMethod();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
      _method = method;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmPasswordDialog(enabling: value),
    );
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _busy = true);
    final check = await ApiService.confirmCurrentPassword(password);
    String? problem;
    if (check['status'] != 'success') {
      problem =
          check['message']?.toString() ?? 'Could not confirm your password.';
    } else if (value) {
      final refresh = await ApiService.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        problem = 'Please sign in again before turning this on.';
      } else {
        await BiometricService.enroll(check['email'].toString(), refresh);
      }
    } else {
      await BiometricService.clearEnrollment();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (problem == null) _enabled = value;
    });
    if (problem != null) {
      AppToast.error(context, problem);
    } else {
      AppToast.success(
        context,
        value
            ? 'You can now sign in with ${_method.label}'
            : 'Biometric login turned off',
      );
    }
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
    return Row(
      children: [
        const SecurityIconTile(Icons.fingerprint_rounded),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Biometric Login',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _available
                    ? 'Sign in with ${_method.label} instead of typing your password.'
                    : BiometricService.setupMessage,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _enabled,
          onChanged: (_available || _enabled) && !_busy ? _toggle : null,
        ),
      ],
    );
  }
}

/// Owns its controller so it outlives the dialog's closing animation.
class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog({required this.enabling});

  final bool enabling;

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final _controller = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: Icons.fingerprint_rounded,
      tone: widget.enabling ? AppDialogTone.primary : AppDialogTone.danger,
      title:
          widget.enabling
              ? 'Enable biometric login'
              : 'Disable biometric login',
      message:
          widget.enabling
              ? 'Confirm your password so we can sign you in with biometrics next time.'
              : 'Confirm your password to disable biometric login.',
      content: TextField(
        controller: _controller,
        obscureText: !_visible,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(
            tooltip: _visible ? 'Hide password' : 'Show password',
            icon: Icon(
              _visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ),
      ),
      confirmLabel: widget.enabling ? 'Confirm & enable' : 'Confirm & disable',
      onConfirm: _submit,
      cancelLabel: 'Cancel',
      onCancel: () => Navigator.pop(context),
    );
  }
}
