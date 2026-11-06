import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/password_checklist.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

class AdminChangePasswordPage extends StatefulWidget {
  const AdminChangePasswordPage({super.key});

  @override
  State<AdminChangePasswordPage> createState() =>
      _AdminChangePasswordPageState();
}

class _AdminChangePasswordPageState extends State<AdminChangePasswordPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_currentCtrl.text.isEmpty) {
      AppToast.error(context, 'Enter your current password.');
      return;
    }
    if (!passwordMeetsRules(_newCtrl.text, _confirmCtrl.text)) {
      AppToast.error(
        context,
        'Your new password doesn’t meet every requirement listed above.',
      );
      return;
    }
    setState(() => _loading = true);
    final result = await ApiService.changePassword(
      oldPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result['status'] != 'success') {
      AppToast.error(
        context,
        result['message']?.toString() ?? "Couldn't change your password.",
      );
      return;
    }
    AppToast.success(context, 'Password changed');
    Navigator.pop(context);
  }

  final _baseline = FormBaseline();
  bool get _hasChanges => _baseline.changed(
    ready: true,
    values: [_currentCtrl.text, _newCtrl.text, _confirmCtrl.text],
  );

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _hasChanges,
      listenTo: Listenable.merge([_currentCtrl, _newCtrl, _confirmCtrl]),
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        appBar: AppBar(title: const Text('Change Password')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PasswordField(
                    label: 'Current password',
                    controller: _currentCtrl,
                    visible: _showCurrent,
                    autofill: AutofillHints.password,
                    onToggle:
                        () => setState(() => _showCurrent = !_showCurrent),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _PasswordField(
                    label: 'New password',
                    controller: _newCtrl,
                    visible: _showNew,
                    autofill: AutofillHints.newPassword,
                    onToggle: () => setState(() => _showNew = !_showNew),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _PasswordField(
                    label: 'Confirm new password',
                    controller: _confirmCtrl,
                    visible: _showConfirm,
                    autofill: AutofillHints.newPassword,
                    onToggle:
                        () => setState(() => _showConfirm = !_showConfirm),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  PasswordChecklist(
                    password: _newCtrl.text,
                    confirm: _confirmCtrl.text,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child:
                          _loading
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text('Update password'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.visible,
    required this.autofill,
    required this.onToggle,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool visible;
  final String autofill;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          text: label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.ink,
          ),
          children: const [
            TextSpan(text: ' *', style: TextStyle(color: AppColors.brand)),
          ],
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        obscureText: !visible,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [autofill],
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          suffixIcon: IconButton(
            tooltip: visible ? 'Hide $label' : 'Show $label',
            onPressed: onToggle,
            icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 19,
              color: AppColors.inkFaint,
            ),
          ),
        ),
      ),
    ],
  );
}
