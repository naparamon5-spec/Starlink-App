import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/features/admin/profile/view-user/admin_view_user_details_page.dart';

class AdminManageUsersPage extends StatefulWidget {
  const AdminManageUsersPage({super.key});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

String _userText(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return t == 'null' ? '' : t;
}

String _userName(Map<String, dynamic> u) {
  final name = _userText(u['name']);
  if (name.isNotEmpty) return name;
  return '${_userText(u['first_name'])} ${_userText(u['last_name'])}'.trim();
}

/// Who may activate or deactivate an account, as on the web portal: admins
/// anyone, agents only customers and end users, and nobody themselves.
bool canToggleUser({
  required String myRole,
  required String myId,
  required Map<String, dynamic> user,
}) {
  if (myId.isNotEmpty && _userText(user['id']) == myId) return false;
  if (myRole == 'admin') return true;
  final target = _userText(user['role']).toLowerCase();
  return myRole == 'agent' && (target == 'customer' || target == 'end_user');
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  List<Map<String, dynamic>> _all = const [];
  int _shown = _pageSize;
  bool _loading = true;
  String? _error;
  String _myRole = '';
  String _myId = '';
  final Set<String> _toggling = {};

  @override
  void initState() {
    super.initState();
    _loadMe();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final me = await ApiService.getMe();
    if (!mounted || me['status'] != 'success') return;
    final d = me['data'];
    if (d is! Map) return;
    setState(() {
      _myRole = _userText(d['role'] ?? d['user_role']).toLowerCase();
      _myId = _userText(d['id']);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    final res = await ApiService.getUsersList();
    if (!mounted) return;
    final d = res['data'];
    final list =
        d is List
            ? d
            : (d is Map && d['data'] is List ? d['data'] as List : []);
    setState(() {
      _loading = false;
      if (res['status'] == 'success') {
        _all =
            list
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
      } else {
        _error = _userText(res['message']);
        if (_error!.isEmpty) _error = "Couldn't load users.";
      }
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((u) {
      return [
        _userName(u),
        u['email'],
        u['role'],
        u['position'],
      ].any((v) => _userText(v).toLowerCase().contains(q));
    }).toList();
  }

  void _snack(String message, {bool isError = false}) => AppToast.result(context, message, ok: !isError);

  Future<void> _setActive(Map<String, dynamic> u, bool active) async {
    final id = _userText(u['id']);
    setState(() => _toggling.add(id));
    final res =
        active
            ? await ApiService.activateUser(id)
            : await ApiService.deactivateUser(id);
    if (!mounted) return;
    setState(() => _toggling.remove(id));
    if (res['status'] != 'success') {
      final message = _userText(res['message']);
      _snack(message.isEmpty ? "Couldn't update this user." : message, isError: true);
      return;
    }
    _snack('${_userName(u)} ${active ? 'activated' : 'deactivated'}');
    await _load();
  }

  /// Deactivating signs the user out everywhere, so it asks first.
  Future<void> _toggle(Map<String, dynamic> u) async {
    if (_userText(u['inactive']) != 'N') return _setActive(u, true);
    final ok = await showAppConfirm(context, title: 'Deactivate this user?', message: '${_userName(u)} (${_userText(u['email'])}) will be signed out '
"and won't be able to sign in until reactivated.", confirmLabel: 'Deactivate', icon: Icons.person_off_outlined, tone: AppDialogTone.danger);
    if (ok == true && mounted) await _setActive(u, false);
  }

  void _openUser(Map<String, dynamic> u) {
    final id = _userText(u['id']);
    if (id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminUserDetailPage(userId: id)),
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _openInvite() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder:
          (_) => CreateUserSheet(
            currentUserRole: _myRole,
            onCreated: () {
              _snack('User invited — an email has been sent');
              _load();
            },
            onError: (message) => _snack(message, isError: true),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      backgroundColor: AppColors.paperSubtle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openInvite,
        icon: const Icon(Icons.person_add_outlined, size: 20),
        label: const Text('Invite User'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 300 && _shown < rows.length) {
              setState(() => _shown += _pageSize);
            }
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() => _shown = _pageSize),
                decoration: const InputDecoration(
                  hintText: 'Search name, email, role, position…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              else if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _search.text.trim().isEmpty
                        ? 'No users found.'
                        : 'No users match your search.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkMuted,
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${rows.length} user${rows.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                for (final u in rows.take(_shown))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _UserCard(
                      user: u,
                      canToggle: canToggleUser(
                        myRole: _myRole,
                        myId: _myId,
                        user: u,
                      ),
                      busy: _toggling.contains(_userText(u['id'])),
                      onTap: () => _openUser(u),
                      onToggle: () => _toggle(u),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.canToggle,
    required this.busy,
    required this.onTap,
    required this.onToggle,
  });

  final Map<String, dynamic> user;
  final bool canToggle;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final name = _userName(user);
    final email = _userText(user['email']);
    final role = _userText(user['role']).replaceAll('_', ' ').toUpperCase();
    final position = _userText(user['position']);
    final active = _userText(user['inactive']) == 'N';
    const compact = Size(0, 34);
    const padding = EdgeInsets.symmetric(horizontal: 14);
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name.isEmpty ? '—' : name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DotBadge(
                    active ? 'ACTIVE' : 'INACTIVE',
                    color: active ? AppColors.successInk : AppColors.inkMuted,
                  ),
                ],
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 8),
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
                  if (position.isNotEmpty)
                    Text(
                      position,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkFaint,
                      ),
                    ),
                ],
              ),
              if (canToggle) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child:
                      active
                          ? TextButton(
                            onPressed: busy ? null : onToggle,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              minimumSize: compact,
                              padding: padding,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Deactivate'),
                          )
                          : OutlinedButton(
                            onPressed: busy ? null : onToggle,
                            style: OutlinedButton.styleFrom(
                              minimumSize: compact,
                              padding: padding,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Activate'),
                          ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Create User Bottom Sheet ───────────────────────────────────────────────────

class CreateUserSheet extends StatefulWidget {
  final VoidCallback onCreated;
  final void Function(String msg) onError;
  final String currentUserRole;
  final String? prefilledRole;
  final String? prefilledCompanyCode;
  final String? prefilledCompanyName;

  const CreateUserSheet({
    super.key,
    required this.onCreated,
    required this.onError,
    required this.currentUserRole,
    this.prefilledRole,
    this.prefilledCompanyCode,
    this.prefilledCompanyName,
  });

  @override
  State<CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<CreateUserSheet> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  List<Map<String, dynamic>> _roles = [];
  bool _loadingRoles = true;
  String? _selectedRoleValue;
  String? _selectedRoleLabel;

  List<Map<String, dynamic>> _companies = [];
  bool _loadingCompanies = false;
  String? _selectedCompanyValue;
  String? _selectedCompanyLabel;

  String? _roleError;
  String? _firstNameError;
  String? _lastNameError;
  String? _companyError;
  String? _emailError;

  bool _isSaving = false;

  bool get _companyEnabled => _selectedRoleValue != null;

  bool get _isEndUserRole =>
      _selectedRoleValue?.toLowerCase() == 'end_user' ||
      _selectedRoleLabel?.toLowerCase() == 'end user';

  @override
  void initState() {
    super.initState();
    _selectedRoleValue = widget.prefilledRole;
    if (widget.prefilledRole != null) {
      if (widget.prefilledRole == 'end_user') {
        _selectedRoleLabel = 'End User';
      } else if (widget.prefilledRole == 'customer') {
        _selectedRoleLabel = 'Customer';
      } else {
        _selectedRoleLabel =
            widget.prefilledRole![0].toUpperCase() +
            widget.prefilledRole!.substring(1);
      }
    }
    _selectedCompanyValue = widget.prefilledCompanyCode;
    _selectedCompanyLabel = widget.prefilledCompanyName;
    _loadRoles();
    if (_selectedRoleValue != null) {
      _loadCompanies(clearSelection: false);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _positionCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  List<String> get _allowedRoleValues {
    final role = widget.currentUserRole.toLowerCase().trim();
    if (role == 'agent') return ['customer', 'end_user'];
    return [];
  }

  Future<void> _loadRoles() async {
    setState(() => _loadingRoles = true);
    try {
      final result = await ApiService.getUserRolesList();
      if (result['status'] == 'success') {
        final raw = result['data'];
        final list = raw is List ? raw : [];
        var roles =
            list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

        final allowed = _allowedRoleValues;
        if (allowed.isNotEmpty) {
          roles =
              roles.where((r) {
                final val =
                    (r['value'] ?? r['name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .trim();
                final lbl =
                    (r['label'] ?? r['display_name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .trim();
                return allowed.contains(val) ||
                    allowed.contains(lbl) ||
                    allowed.contains(lbl.replaceAll(' ', '_'));
              }).toList();
        }

        setState(() {
          _roles = roles;
          _loadingRoles = false;
        });
      } else {
        setState(() => _loadingRoles = false);
      }
    } catch (_) {
      setState(() => _loadingRoles = false);
    }
  }

  Future<void> _loadCompanies({bool clearSelection = true}) async {
    setState(() {
      _loadingCompanies = true;
      _companies = [];
      if (clearSelection) {
        _selectedCompanyValue = null;
        _selectedCompanyLabel = null;
      }
    });

    try {
      if (_isEndUserRole) {
        final result = await ApiService.getEndUserListAll();
        if (!mounted) return;
        final isOk =
            result['status'] == 'success' ||
            result['StatusCode'] == 200 ||
            result['message'] == 'Success';
        if (isOk) {
          final raw = result['data'] as List<dynamic>? ?? [];
          setState(() {
            _companies =
                raw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .where((e) {
                      final label = (e['label'] as String? ?? '').trim();
                      return label.isNotEmpty && e['value'] != null;
                    })
                    .map(
                      (e) => <String, dynamic>{
                        'label': e['label'].toString().trim(),
                        'value': e['value'].toString(),
                      },
                    )
                    .toList();
          });
        }
      } else {
        final result = await ApiService.getCustomersListAll();
        if (!mounted) return;
        final isOk =
            result['StatusCode'] == 200 ||
            result['message'] == 'Success' ||
            result['status'] == 'success';
        if (isOk) {
          final raw = result['data'] as List<dynamic>? ?? [];
          setState(() {
            _companies =
                raw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .where((e) {
                      final label = (e['label'] as String? ?? '').trim();
                      final value = e['value']?.toString().trim() ?? '';
                      return label.isNotEmpty && value.isNotEmpty;
                    })
                    .map(
                      (e) => <String, dynamic>{
                        'label': e['label'].toString().trim(),
                        'value': e['value'].toString().trim(),
                      },
                    )
                    .toList();
          });
        }
      }
    } catch (_) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _loadingCompanies = false);
    }
  }

  bool _validate() {
    final email = _emailCtrl.text.trim();
    setState(() {
      _roleError = _selectedRoleValue == null ? 'Select a role.' : null;
      _firstNameError =
          _firstNameCtrl.text.trim().isEmpty ? 'First name is required.' : null;
      _lastNameError =
          _lastNameCtrl.text.trim().isEmpty ? 'Last name is required.' : null;
      _companyError =
          (_selectedCompanyValue ?? '').isEmpty ? 'Select a company.' : null;
      _emailError =
          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
              ? null
              : 'Enter a valid email.';
    });
    return _roleError == null &&
        _firstNameError == null &&
        _lastNameError == null &&
        _companyError == null &&
        _emailError == null;
  }

  Future<void> _save() async {
    if (_isSaving || !_validate()) return;
    setState(() => _isSaving = true);
    try {
      final result = await ApiService.createUser({
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'middle_name': _middleNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _selectedRoleValue,
        'position': _positionCtrl.text.trim(),
        'com_eu_code': _selectedCompanyValue ?? '',
      });
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (result['status'] == 'success') {
        Navigator.pop(context);
        widget.onCreated();
      } else {
        AppToast.error(
          context,
          result['message']?.toString() ?? "Couldn't invite this user.",
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.error(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  final _baseline = FormBaseline();
  bool get _hasChanges => _baseline.changed(
    ready: true,
    values: [
      _firstNameCtrl.text,
      _lastNameCtrl.text,
      _middleNameCtrl.text,
      _positionCtrl.text,
      _emailCtrl.text,
      _selectedRoleValue,
      _selectedCompanyValue,
    ],
  );

  List<SelectOption<String>> get _roleOptions {
    final options = <SelectOption<String>>[
      for (final r in _roles)
        SelectOption(
          (r['value'] ?? r['name'] ?? '').toString(),
          (r['label'] ?? r['display_name'] ?? r['value'] ?? '').toString(),
        ),
    ];
    final picked = _selectedRoleValue;
    if (picked != null && !options.any((o) => o.value == picked)) {
      options.insert(0, SelectOption(picked, _selectedRoleLabel ?? picked));
    }
    return options;
  }

  List<SelectOption<String>> get _companyOptions {
    final options = <SelectOption<String>>[
      for (final c in _companies)
        SelectOption('${c['value']}', '${c['label']}'),
    ];
    final picked = _selectedCompanyValue;
    if ((picked ?? '').isNotEmpty && !options.any((o) => o.value == picked)) {
      options.insert(0, SelectOption(picked!, _selectedCompanyLabel ?? picked));
    }
    return options;
  }

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text.toUpperCase(),
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
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? hint,
    String? error,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.words,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        TextField(
          controller: controller,
          enabled: !_isSaving,
          keyboardType: keyboard,
          textCapitalization: capitalization,
          decoration: InputDecoration(hintText: hint, errorText: error),
        ),
      ],
    ),
  );

  Widget _select(
    String label, {
    required String? value,
    required List<SelectOption<String>> options,
    required String hint,
    required ValueChanged<String> onChanged,
    bool enabled = true,
    String? error,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: true),
        AppSelect<String>(
          sheetTitle: label,
          value: value,
          hint: hint,
          enabled: enabled && !_isSaving,
          options: options,
          onChanged: onChanged,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Text(
              error,
              style: const TextStyle(fontSize: 12, color: AppColors.dangerInk),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return UnsavedChangesGuard(
      isDirty: () => _hasChanges,
      listenTo: Listenable.merge([
        _firstNameCtrl,
        _lastNameCtrl,
        _middleNameCtrl,
        _positionCtrl,
        _emailCtrl,
      ]),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite User',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Create an account and send an invitation.',
                      style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 18),
                    _select(
                      'Role',
                      value: _selectedRoleValue,
                      options: _roleOptions,
                      hint: _loadingRoles ? 'Loading…' : 'Select role',
                      error: _roleError,
                      onChanged: (v) {
                        setState(() {
                          _selectedRoleValue = v;
                          _selectedRoleLabel =
                              _roleOptions
                                  .firstWhere((o) => o.value == v)
                                  .label;
                          _roleError = null;
                        });
                        // Keeps a company that was preset for this invitation.
                        _loadCompanies(
                          clearSelection: widget.prefilledCompanyCode == null,
                        );
                      },
                    ),
                    _field('Position', _positionCtrl, hint: 'e.g. IT Manager'),
                    _field(
                      'First name',
                      _firstNameCtrl,
                      required: true,
                      error: _firstNameError,
                    ),
                    _field('Middle name', _middleNameCtrl),
                    _field(
                      'Last name',
                      _lastNameCtrl,
                      required: true,
                      error: _lastNameError,
                    ),
                    _select(
                      _isEndUserRole ? 'End user' : 'Company',
                      value: _selectedCompanyValue,
                      options: _companyOptions,
                      hint: _loadingCompanies ? 'Loading…' : 'Select',
                      enabled: _companyEnabled,
                      error: _companyError,
                      onChanged:
                          (v) => setState(() {
                            _selectedCompanyValue = v;
                            _companyError = null;
                          }),
                    ),
                    _field(
                      'Company email',
                      _emailCtrl,
                      required: true,
                      hint: 'name@company.com.ph',
                      error: _emailError,
                      keyboard: TextInputType.emailAddress,
                      capitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed:
                                _isSaving
                                    ? null
                                    : () => Navigator.maybePop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                            child:
                                _isSaving
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Send invitation'),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
