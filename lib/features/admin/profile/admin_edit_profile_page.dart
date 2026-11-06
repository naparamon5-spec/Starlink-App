import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/account_detail_parts.dart';
import 'package:starlink_app/shared/widgets/app_version_label.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

/// The signed-in admin's or agent's own details.
class AdminEditProfilePage extends StatefulWidget {
  const AdminEditProfilePage({super.key, this.bearerToken});

  /// No longer needed; kept so existing callers still build.
  final String? bearerToken;

  @override
  State<AdminEditProfilePage> createState() => _AdminEditProfilePageState();
}

class _AdminEditProfilePageState extends State<AdminEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _position = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  Map<String, dynamic> _profile = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final res = await ApiService.getOwnUserRecord();
    if (!mounted) return;
    final data = res['data'];
    if (res['status'] != 'success' || data is! Map) {
      setState(() {
        _loading = false;
        _loadError =
            res['message']?.toString() ?? "Couldn't load your profile.";
      });
      return;
    }
    final profile = Map<String, dynamic>.from(data);
    _first.text = accountText(profile['first_name']);
    _middle.text = accountText(profile['middle_name']);
    _last.text = accountText(profile['last_name']);
    _position.text = accountText(profile['position']);
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final id = accountText(_profile['id']);
    if (id.isEmpty) {
      AppToast.error(context, 'User ID not found. Please log out and back in.');
      return;
    }
    setState(() => _saving = true);
    final res = await ApiService.updateUser(id, {
      'first_name': _first.text.trim(),
      'middle_name': _middle.text.trim(),
      'last_name': _last.text.trim(),
      'position': _position.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['status'] != 'success') {
      AppToast.error(
        context,
        res['message']?.toString() ?? "Couldn't update your profile.",
      );
      return;
    }
    AppToast.success(context, 'Profile updated');
    Navigator.pop(context, true);
  }

  final _baseline = FormBaseline();
  bool get _hasChanges => _baseline.changed(
    ready: !_loading && _loadError == null,
    values: [_first.text, _middle.text, _last.text, _position.text],
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? hint,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
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
            children: [
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.brand),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: !_saving,
          validator: validator,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _hasChanges,
      listenTo: Listenable.merge([_first, _middle, _last, _position]),
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        appBar: AppBar(title: const Text('Edit Profile')),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? _buildError()
                : _buildForm(),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    ),
  );

  Widget _buildForm() {
    final name = accountText(_profile['name']);
    final email = accountText(_profile['email']);
    final role = accountText(_profile['role']).replaceAll('_', ' ');
    final company = accountText(_profile['company_name']);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.navy,
                      child: Text(
                        accountInitials(name),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? '—' : name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                          if (role.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Text(
                  'COMPANY',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  company.isEmpty ? '—' : company,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  'First name',
                  _first,
                  required: true,
                  validator:
                      (v) =>
                          (v ?? '').trim().isEmpty
                              ? 'First name is required.'
                              : null,
                ),
                _field('Middle name', _middle),
                _field(
                  'Last name',
                  _last,
                  required: true,
                  validator:
                      (v) =>
                          (v ?? '').trim().isEmpty
                              ? 'Last name is required.'
                              : null,
                ),
                _field('Position', _position, hint: 'e.g. IT Manager'),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Save details'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AppVersionLabel(),
        ],
      ),
    );
  }
}
