import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/admin/profile/admin_manage_users_page.dart';
import 'package:starlink_app/features/auth/change_password.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/account_detail_parts.dart';
import 'package:starlink_app/shared/widgets/password_checklist.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

/// One portal account: who it is, its editable details, and its security
/// actions. Status and password actions never apply to your own account, and
/// agents only get them for customer and end-user accounts.
class AdminUserDetailPage extends StatefulWidget {
  const AdminUserDetailPage({super.key, required this.userId});
  final String userId;

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _position = TextEditingController();

  bool _loading = true;
  String? _loadError;
  Map<String, dynamic> _user = const {};
  String _myRole = '';
  String _myId = '';
  bool _saving = false;
  bool _toggling = false;
  bool _sendingReset = false;

  bool get _isSelf => _myId.isNotEmpty && _myId == widget.userId;
  bool get _isActive => accountText(_user['inactive']) == 'N';
  bool get _canManage =>
      canToggleUser(myRole: _myRole, myId: _myId, user: _user);
  bool get _canEdit => _isSelf || _canManage;

  bool get _isDirty =>
      !_loading &&
      _loadError == null &&
      (_first.text != accountText(_user['first_name']) ||
          _middle.text != accountText(_user['middle_name']) ||
          _last.text != accountText(_user['last_name']) ||
          _position.text != accountText(_user['position']));

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
    final results = await Future.wait([
      ApiService.getUserById2(widget.userId),
      ApiService.getMe(),
    ]);
    if (!mounted) return;
    final res = results[0];
    final data = res['data'];
    final me = results[1]['data'];
    setState(() {
      _loading = false;
      if (me is Map) {
        _myRole = accountText(me['role'] ?? me['user_role']).toLowerCase();
        _myId = accountText(me['id']);
      }
      if (res['status'] == 'success' && data is Map) {
        _applyUser(Map<String, dynamic>.from(data));
      } else {
        _loadError = accountText(res['message']);
      }
    });
  }

  void _applyUser(Map<String, dynamic> user) {
    _user = user;
    _first.text = accountText(user['first_name']);
    _middle.text = accountText(user['middle_name']);
    _last.text = accountText(user['last_name']);
    _position.text = accountText(user['position']);
  }

  void _snack(String message, {bool isError = false}) => AppToast.result(context, message, ok: !isError);

  String _failure(Map<String, dynamic> res, String fallback) {
    final message = accountText(res['message']);
    return message.isNotEmpty ? message : fallback;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      _snack('First and last name are required.', isError: true);
      return;
    }
    setState(() => _saving = true);
    final res = await ApiService.updateUser(widget.userId, {
      'first_name': _first.text.trim(),
      'middle_name': _middle.text.trim(),
      'last_name': _last.text.trim(),
      'position': _position.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['status'] != 'success') {
      _snack(_failure(res, "Couldn't save the changes."), isError: true);
      return;
    }
    _snack('Profile updated');
    await _load();
  }

  Future<void> _toggleStatus() async {
    final activate = !_isActive;
    if (!activate) {
      final ok = await showAppConfirm(context, title: 'Deactivate this user?', message: '${accountText(_user['name'])} (${accountText(_user['email'])}) '
"will be signed out and won't be able to sign in until "
'reactivated.', confirmLabel: 'Deactivate', icon: Icons.person_off_outlined, tone: AppDialogTone.danger);
      if (ok != true || !mounted) return;
    }
    setState(() => _toggling = true);
    final res =
        activate
            ? await ApiService.activateUser(widget.userId)
            : await ApiService.deactivateUser(widget.userId);
    if (!mounted) return;
    final ok = res['status'] == 'success';
    setState(() {
      _toggling = false;
      if (ok) _user = {..._user, 'inactive': activate ? 'N' : 'Y'};
    });
    _snack(
      ok ? 'Status updated' : _failure(res, "Couldn't update the status."), isError: !ok);
  }

  Future<void> _sendReset() async {
    final ok = await showAppConfirm(context, title: 'Send reset link?', message: 'A password reset link will be emailed to '
'${accountText(_user['email'])}.', confirmLabel: 'Send', icon: Icons.mail_outline_rounded);
    if (ok != true || !mounted) return;
    setState(() => _sendingReset = true);
    final res = await ApiService.sendResetPasswordEmail(widget.userId);
    if (!mounted) return;
    setState(() => _sendingReset = false);
    _snack(
      res['status'] == 'success'
          ? 'Reset link sent'
          : _failure(res, "Couldn't send the reset link."), isError: res['status'] != 'success');
  }

  Future<void> _openSetPassword() async {
    final set = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _SetPasswordSheet(userId: widget.userId),
    );
    if (set == true && mounted) _snack('Password set');
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _isDirty,
      listenTo: Listenable.merge([_first, _middle, _last, _position]),
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        appBar: AppBar(title: const Text('User')),
        body:
            _loading && _user.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? _buildError()
                : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    _buildDetails(),
                    if (_canManage || _isSelf) ...[
                      const SizedBox(height: 14),
                      _buildSecurity(),
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 34, color: AppColors.inkFaint),
          const SizedBox(height: 10),
          const Text(
            'User not found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (_loadError!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    ),
  );

  Widget _buildHeader() {
    final full =
        '${accountText(_user['first_name'])} '
                '${accountText(_user['last_name'])}'
            .trim();
    final name =
        accountText(_user['name']).isNotEmpty
            ? accountText(_user['name'])
            : full;
    final email = accountText(_user['email']);
    final role = accountText(_user['role']).replaceAll('_', ' ').toUpperCase();
    final company = accountText(_user['company_name']);
    const compact = Size(0, 34);
    const padding = EdgeInsets.symmetric(horizontal: 14);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.3,
                        color: AppColors.navy,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (role.isNotEmpty)
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
                              role,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        if (company.isNotEmpty)
                          Text(
                            company,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkFaint,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 6,
              children: [
                DotBadge(
                  _isActive ? 'ACTIVE' : 'INACTIVE',
                  color: _isActive ? AppColors.successInk : AppColors.inkMuted,
                ),
                if (_canManage)
                  _isActive
                      ? TextButton(
                        onPressed: _toggling ? null : _toggleStatus,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          minimumSize: compact,
                          padding: padding,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Deactivate'),
                      )
                      : OutlinedButton(
                        onPressed: _toggling ? null : _toggleStatus,
                        style: OutlinedButton.styleFrom(
                          minimumSize: compact,
                          padding: padding,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Activate'),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    ),
  );

  Widget _field(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: !_canEdit,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
                  ),
      ],
    ),
  );

  Widget _buildDetails() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Details'),
          _field('First name', _first),
          _field('Middle name', _middle),
          _field('Last name', _last),
          _field('Position', _position),
          if (_canEdit)
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
                        : const Text('Save changes'),
              ),
            )
          else
            const Text(
              'Only admins can change staff accounts.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurity() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Security'),
          if (_canManage) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _sendingReset ? null : _sendReset,
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('Send reset link'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openSetPassword,
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('Set password'),
              ),
            ),
          ] else ...[
            const Text(
              'This is your account. Change your password here:',
              style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminChangePasswordPage(),
                      ),
                    ),
                child: const Text('Change password'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Set someone's password directly (PUT /auth/user/set-password/:id).
class _SetPasswordSheet extends StatefulWidget {
  const _SetPasswordSheet({required this.userId});
  final String userId;

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _visible = false;
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final res = await ApiService.setUserPassword(widget.userId, _password.text);
    if (!mounted) return;
    if (res['status'] == 'success') {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _saving = false);
    final message = accountText(res['message']);
    AppToast.error(
      context,
      message.isEmpty ? "Couldn't set the password." : message,
    );
  }

  Widget _field(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: !_visible,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !_saving,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            suffixIcon: IconButton(
              tooltip: _visible ? 'Hide passwords' : 'Show passwords',
              onPressed: () => setState(() => _visible = !_visible),
              icon: Icon(
                _visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 19,
                color: AppColors.inkFaint,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final valid = passwordMeetsRules(_password.text, _confirm.text);
    return UnsavedChangesGuard(
      isDirty: () => _password.text.isNotEmpty || _confirm.text.isNotEmpty,
      listenTo: Listenable.merge([_password, _confirm]),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 14),
            _field('New password', _password),
            _field('Confirm password', _confirm),
            PasswordChecklist(password: _password.text, confirm: _confirm.text),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.maybePop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: valid && !_saving ? _submit : null,
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
                            : const Text('Set password'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
