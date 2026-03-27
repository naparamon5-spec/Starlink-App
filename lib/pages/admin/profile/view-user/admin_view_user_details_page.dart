import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/api_service.dart';

// ── Design Tokens (match AdminManageUsersPage) ────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _info = Color(0xFF0043CE);
const _purple = Color(0xFF8A3FFC);
const _teal = Color(0xFF009D9A);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

// ─────────────────────────────────────────────────────────────────────────────
// AdminUserDetailPage
// Navigate to this page by pushing with a `userId` argument:
//
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => AdminUserDetailPage(userId: user['id'].toString()),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

class AdminUserDetailPage extends StatefulWidget {
  final String userId;

  const AdminUserDetailPage({super.key, required this.userId});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _errorMessage;

  // Edit mode controllers
  bool _isEditing = false;
  bool _isSaving = false;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchUser();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _positionCtrl.dispose();
    super.dispose();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getUserById2(widget.userId);
      if (result['status'] == 'success') {
        final data = result['data'];
        final Map<String, dynamic> user =
            data is Map<String, dynamic>
                ? data
                : (data is Map ? Map<String, dynamic>.from(data) : {});

        setState(() {
          _user = user;
          _isLoading = false;
        });
        _populateControllers(user);
        _fadeCtrl.forward(from: 0);
        _slideCtrl.forward(from: 0);
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load user.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _populateControllers(Map<String, dynamic> u) {
    _firstNameCtrl.text = u['first_name']?.toString() ?? '';
    _lastNameCtrl.text = u['last_name']?.toString() ?? '';
    _middleNameCtrl.text = u['middle_name']?.toString() ?? '';
    _positionCtrl.text = u['position']?.toString() ?? '';
  }

  // ── Save edits ─────────────────────────────────────────────────────────────
  Future<void> _saveEdits() async {
    setState(() => _isSaving = true);
    try {
      final result = await ApiService.updateUser(widget.userId, {
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'middle_name': _middleNameCtrl.text.trim(),
        'position': _positionCtrl.text.trim(),
      });

      if (result['status'] == 'success') {
        // Update local state with edited values
        setState(() {
          _user = {
            ..._user!,
            'first_name': _firstNameCtrl.text.trim(),
            'last_name': _lastNameCtrl.text.trim(),
            'middle_name': _middleNameCtrl.text.trim(),
            'position': _positionCtrl.text.trim(),
            'name':
                '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
          };
          _isEditing = false;
          _isSaving = false;
        });
        _showSnack('User updated successfully.', _success);
      } else {
        setState(() => _isSaving = false);
        _showSnack(result['message'] ?? 'Update failed.', _primary);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack(e.toString().replaceAll('Exception: ', ''), _primary);
    }
  }

  // ── Toggle active/inactive ─────────────────────────────────────────────────
  Future<void> _toggleActivation() async {
    if (_user == null) return;
    final isActive = _isActive(_user!);
    final action = isActive ? 'deactivate' : 'activate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isActive ? 'Deactivate User?' : 'Activate User?',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            content: Text(
              isActive
                  ? 'This will prevent the user from logging in.'
                  : 'This will restore the user\'s access.',
              style: const TextStyle(color: _inkSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _inkSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? _primary : _success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  isActive ? 'Deactivate' : 'Activate',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final result =
          isActive
              ? await ApiService.deactivateUser(widget.userId)
              : await ApiService.activateUser(widget.userId);

      if (result['status'] == 'success') {
        setState(() {
          _user = {..._user!, 'inactive': isActive ? 'Y' : 'N'};
        });
        _showSnack(
          isActive ? 'User deactivated.' : 'User activated.',
          isActive ? _warning : _success,
        );
      } else {
        _showSnack(result['message'] ?? 'Action failed.', _primary);
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), _primary);
    }
  }

  // ── Send reset password email ──────────────────────────────────────────────
  Future<void> _sendResetPasswordEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Send Reset Password Email?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            content: Text(
              'A password reset link will be sent to ${_user?['email'] ?? 'this user'}.',
              style: const TextStyle(color: _inkSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _inkSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _info,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Send',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.sendResetPasswordEmail(widget.userId);
      if (result['status'] == 'success') {
        _showSnack(result['message'] ?? 'Password reset email sent.', _info);
      } else {
        _showSnack(
          result['message'] ?? 'Failed to send reset email.',
          _primary,
        );
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), _primary);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool _isActive(Map<String, dynamic> u) =>
      (u['inactive'] ?? 'N').toString().toUpperCase() != 'Y';

  String _displayName(Map<String, dynamic> u) {
    final first = u['first_name']?.toString().trim() ?? '';
    final last = u['last_name']?.toString().trim() ?? '';
    final name = u['name']?.toString().trim() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      return '$first $last'.trim();
    }
    return name.isNotEmpty ? name : 'Unknown User';
  }

  String _initials(Map<String, dynamic> u) {
    final name = _displayName(u);
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _normaliseRole(String raw) {
    switch (raw.toLowerCase()) {
      case 'end_user':
        return 'End User';
      case 'admin':
        return 'Admin';
      case 'agent':
        return 'Agent';
      case 'customer':
        return 'Customer';
      case 'biller':
        return 'Biller';
      default:
        return raw.isEmpty ? '—' : raw;
    }
  }

  Color _roleColor(String raw) {
    switch (raw.toLowerCase()) {
      case 'admin':
        return _primary;
      case 'agent':
        return _warning;
      case 'customer':
        return _info;
      case 'end_user':
        return _success;
      case 'biller':
        return _purple;
      default:
        return _teal;
    }
  }

  IconData _roleIcon(String raw) {
    switch (raw.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'agent':
        return Icons.support_agent_outlined;
      case 'customer':
        return Icons.business_outlined;
      case 'end_user':
        return Icons.person_outline;
      case 'biller':
        return Icons.receipt_long_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body:
            _isLoading
                ? _buildLoader()
                : _errorMessage != null
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  Widget _buildLoader() => Column(
    children: [
      _buildAppBar(title: 'User Details', subtitle: 'Loading...'),
      const Expanded(
        child: Center(child: CircularProgressIndicator(color: _primary)),
      ),
    ],
  );

  Widget _buildError() => Column(
    children: [
      _buildAppBar(title: 'User Details', subtitle: 'Error'),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    color: _primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Could not load user',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _inkSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchUser,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildBody() {
    final u = _user!;
    final role = u['role']?.toString() ?? '';
    final roleColor = _roleColor(role);
    final isActive = _isActive(u);

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        _buildAppBar(
          title: _displayName(u),
          subtitle: _normaliseRole(role),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isEditing)
                _headerIconBtn(
                  Icons.edit_outlined,
                  Colors.white70,
                  () => setState(() => _isEditing = true),
                ),
              const SizedBox(width: 4),
              _headerIconBtn(Icons.refresh_rounded, Colors.white70, _fetchUser),
            ],
          ),
        ),

        Expanded(
          child: FadeTransition(
            opacity: _fadeCtrl,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile hero card ─────────────────────────────────
                  _buildHeroCard(u, roleColor, isActive, role),
                  const SizedBox(height: 16),

                  // ── Edit form or info sections ─────────────────────────
                  if (_isEditing)
                    _buildEditForm()
                  else ...[
                    _buildSection('Account Information', [
                      _infoRow(
                        Icons.email_outlined,
                        'Email',
                        u['email']?.toString() ?? '—',
                      ),
                      // _infoRow(
                      //   Icons.badge_outlined,
                      //   'Username',
                      //   u['username']?.toString() ?? '—',
                      // ),
                      _infoRow(
                        Icons.work_outline,
                        'Position',
                        u['position']?.toString().trim().isNotEmpty == true
                            ? u['position'].toString()
                            : '—',
                      ),
                      _infoRow(
                        Icons.code_outlined,
                        'Code',
                        u['com_eu_code']?.toString() ??
                            u['code']?.toString() ??
                            '—',
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Personal Details', [
                      _infoRow(
                        Icons.person_outline,
                        'First Name',
                        u['first_name']?.toString() ?? '—',
                      ),
                      _infoRow(
                        Icons.person_outline,
                        'Middle Name',
                        u['middle_name']?.toString().trim().isNotEmpty == true
                            ? u['middle_name'].toString()
                            : '—',
                      ),
                      _infoRow(
                        Icons.person_outline,
                        'Last Name',
                        u['last_name']?.toString() ?? '—',
                      ),
                    ]),
                    const SizedBox(height: 16),
                    // _buildSection('System Details', [
                    //   _infoRow(
                    //     Icons.tag,
                    //     'User ID',
                    //     u['id']?.toString() ?? '—',
                    //   ),
                    //   _infoRow(
                    //     Icons.calendar_today_outlined,
                    //     'Created At',
                    //     _formatDate(u['created_at']?.toString()),
                    //   ),
                    //   _infoRow(
                    //     Icons.update_outlined,
                    //     'Updated At',
                    //     _formatDate(u['updated_at']?.toString()),
                    //   ),
                    // ]),
                  ],

                  const SizedBox(height: 24),

                  // ── Action buttons ─────────────────────────────────────
                  if (!_isEditing) _buildActionButtons(isActive),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar({
    required String title,
    required String subtitle,
    Widget? trailing,
  }) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    ),
  );

  Widget _headerIconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      );

  // ── Hero Card ──────────────────────────────────────────────────────────────
  Widget _buildHeroCard(
    Map<String, dynamic> u,
    Color roleColor,
    bool isActive,
    String role,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        // Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [roleColor, roleColor.withOpacity(0.65)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: roleColor.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _initials(u),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _displayName(u),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          u['email']?.toString() ?? '—',
          style: const TextStyle(fontSize: 13, color: _inkSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: roleColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_roleIcon(role), size: 12, color: roleColor),
                  const SizedBox(width: 5),
                  Text(
                    _normaliseRole(role).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: roleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isActive ? _success : _inkTertiary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? _success : _inkTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isActive ? _success : _inkTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // ── Info Section ───────────────────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _inkTertiary,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const Divider(height: 1, color: _border),
        ...rows,
      ],
    ),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _inkTertiary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
        // Copy button
        if (value != '—')
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              _showSnack('Copied to clipboard', _inkSecondary);
            },
            child: const Icon(
              Icons.copy_outlined,
              size: 14,
              color: _inkTertiary,
            ),
          ),
      ],
    ),
  );

  // ── Edit Form ──────────────────────────────────────────────────────────────
  Widget _buildEditForm() => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Text(
                'EDIT PROFILE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _inkTertiary,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap:
                    _isSaving ? null : () => setState(() => _isEditing = false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _inkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _editField(_firstNameCtrl, 'First Name', Icons.person_outline),
              const SizedBox(height: 12),
              _editField(_middleNameCtrl, 'Middle Name', Icons.person_outline),
              const SizedBox(height: 12),
              _editField(_lastNameCtrl, 'Last Name', Icons.person_outline),
              const SizedBox(height: 12),
              _editField(_positionCtrl, 'Position', Icons.work_outline),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveEdits,
                  child:
                      _isSaving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _editField(TextEditingController ctrl, String label, IconData icon) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _inkSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: InputDecoration(
                hintText: 'Enter $label',
                hintStyle: const TextStyle(color: _inkTertiary, fontSize: 13),
                prefixIcon: Icon(icon, size: 17, color: _primary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      );

  // ── Action Buttons ─────────────────────────────────────────────────────────
  Widget _buildActionButtons(bool isActive) => Column(
    children: [
      // Activate / Deactivate
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? _warning : _success,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _toggleActivation,
          icon: Icon(
            isActive
                ? Icons.block_outlined
                : Icons.check_circle_outline_rounded,
            size: 18,
          ),
          label: Text(
            isActive ? 'Deactivate User' : 'Activate User',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
      const SizedBox(height: 10),

      // Send Reset Password Email
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _info,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _sendResetPasswordEmail,
          icon: const Icon(Icons.lock_reset_outlined, size: 18),
          label: const Text(
            'Send Reset Password Email',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
      const SizedBox(height: 10),

      // Edit button (shortcut)
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    ],
  );
  // ── Date formatter ─────────────────────────────────────────────────────────
  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}
