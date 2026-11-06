import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Shared pieces of the authenticator-app (TOTP) two-factor flow, used both at
// sign-in (forced setup) and in Security Settings.

const _primary = Color(0xFF133341);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);

/// Length of an authenticator code.
const kTotpLength = 6;

/// What the backend returns to link an authenticator app.
class AuthenticatorSetupInfo {
  const AuthenticatorSetupInfo({
    required this.otpauthUrl,
    required this.secret,
    this.issuer = 'Ardent Starlink',
    this.account = '',
  });

  /// `otpauth://totp/...` — encoded in the QR code.
  final String otpauthUrl;

  /// Base32 key for typing into the app by hand.
  final String secret;
  final String issuer;
  final String account;

  /// Reads either camelCase or snake_case keys; null when there's no secret.
  static AuthenticatorSetupInfo? fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return null;
    final secret = (m['secret'] ?? '').toString().trim();
    final url = (m['otpauthUrl'] ?? m['otpauth_url'] ?? '').toString().trim();
    if (secret.isEmpty && url.isEmpty) return null;
    return AuthenticatorSetupInfo(
      otpauthUrl: url,
      secret: secret,
      issuer: (m['issuer'] ?? 'Ardent Starlink').toString(),
      account: (m['account'] ?? '').toString(),
    );
  }
}

/// QR code + setup key + "open in app" button for linking an authenticator.
class AuthenticatorLinkPanel extends StatelessWidget {
  const AuthenticatorLinkPanel({super.key, required this.info});

  final AuthenticatorSetupInfo info;

  /// The secret in groups of 4 so it's easier to type.
  String get _groupedSecret {
    final s = info.secret.replaceAll(' ', '');
    final parts = <String>[];
    for (var i = 0; i < s.length; i += 4) {
      parts.add(s.substring(i, i + 4 > s.length ? s.length : i + 4));
    }
    return parts.join(' ');
  }

  Future<void> _openInApp(BuildContext context) async {
    final uri = Uri.tryParse(info.otpauthUrl);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && context.mounted) {
      AppToast.error(context, 'No authenticator app found. Install Google or Microsoft '
            'Authenticator, or enter the setup key manually.');
    }
  }

  void _copySecret(BuildContext context) {
    Clipboard.setData(ClipboardData(text: info.secret.replaceAll(' ', '')));
    AppToast.success(context, 'Setup key copied');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Step(
          number: 1,
          text:
              'Install Google Authenticator or Microsoft Authenticator on your phone.',
        ),
        const _Step(
          number: 2,
          text:
              'In the app, add an account and scan this QR code. On this same '
              'phone, tap "Open in authenticator app" or enter the setup key.',
        ),
        const _Step(
          number: 3,
          text: 'Enter the 6-digit code the app shows to finish.',
        ),
        const SizedBox(height: 16),
        if (info.otpauthUrl.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: QrImageView(
                data: info.otpauthUrl,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: 14),
        if (info.otpauthUrl.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openInApp(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open in authenticator app'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        if (info.secret.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Setup key',
            style: TextStyle(
              fontSize: 12,
              color: _inkSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: _surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _groupedSecret,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy setup key',
                  onPressed: () => _copySecret(context),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose "Time based" if the app asks for a key type.',
            style: TextStyle(fontSize: 11, color: _inkTertiary),
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: _inkSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single 6-digit code field: supports paste and the OS one-time-code autofill.
class TotpCodeField extends StatelessWidget {
  const TotpCodeField({
    super.key,
    required this.controller,
    this.onCompleted,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: kTotpLength,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: _ink,
        letterSpacing: 12,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: _inkTertiary.withOpacity(0.5),
          letterSpacing: 12,
        ),
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: border(_border),
        enabledBorder: border(_border),
        focusedBorder: border(_primary, 2),
        disabledBorder: border(_border),
      ),
      onChanged: (v) {
        if (v.length == kTotpLength) onCompleted?.call(v);
      },
    );
  }
}
