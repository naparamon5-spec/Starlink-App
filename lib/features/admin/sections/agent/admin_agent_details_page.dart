import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/status_labels.dart';
import 'package:starlink_app/features/admin/profile/admin_manage_users_page.dart';
import 'package:starlink_app/features/admin/profile/view-user/admin_view_user_details_page.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_create_end_user_page.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_end_user_details_page.dart';
import 'package:starlink_app/features/admin/sections/subscription/admin_subscription_details_page.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/account_detail_parts.dart';
import 'package:starlink_app/shared/widgets/account_limit_card.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

String _text(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return t == 'null' ? '' : t;
}

String _sln(Map<String, dynamic> s) =>
    _text(s['serviceLineNumber'] ?? s['service_line_number']);

/// One customer: who they are, then their subscriptions, users and end users.
class AdminAgentDetailsPage extends StatefulWidget {
  const AdminAgentDetailsPage({
    super.key,
    required this.agentId,
    required this.agentCode,
    required this.agentName,
  });

  final String agentId;
  final String agentCode;
  final String agentName;

  @override
  State<AdminAgentDetailsPage> createState() => _AdminAgentDetailsPageState();
}

class _AdminAgentDetailsPageState extends State<AdminAgentDetailsPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _subscriptions = const [];
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _endUsers = const [];
  int _tab = 0;
  int _limitVersion = 0;

  // Lines chosen to link, waiting for an end user and Save.
  final List<Map<String, dynamic>> _pending = [];
  bool _savingLinks = false;

  // Changing the end user of lines already linked.
  bool _editingEndUsers = false;
  final Map<String, String> _euDraft = {};
  bool _savingEndUsers = false;

  String get _code {
    final code = _text(_customer?['code']);
    return code.isNotEmpty ? code : widget.agentCode;
  }

  String get _name {
    final name = _text(_customer?['name']);
    return name.isNotEmpty ? name : widget.agentName;
  }

  List<Map<String, dynamic>> get _changedEndUsers => [
    for (final s in _subscriptions)
      if ((_euDraft[_sln(s)] ?? '') != _text(s['eu_code'])) s,
  ];

  bool get _isDirty =>
      _pending.isNotEmpty || (_editingEndUsers && _changedEndUsers.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> res) {
    if (res['status'] != 'success') return const [];
    final d = res['data'];
    final list =
        d is List
            ? d
            : (d is Map && d['data'] is List ? d['data'] as List : []);
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _customer == null;
      _error = null;
    });
    final results = await Future.wait(<Future<Map<String, dynamic>>>[
      ApiService.getCustomerById(widget.agentId),
      ApiService.getSubscriptionsByCustomerId(widget.agentCode),
      ApiService.getUsersByCompanyCode(widget.agentCode),
      ApiService.getEndUsersByCustomer(widget.agentCode),
    ]);
    if (!mounted) return;
    final customer = results[0];
    setState(() {
      _loading = false;
      if (customer['status'] != 'success') {
        _error = _text(customer['message']);
        return;
      }
      final d = customer['data'];
      _customer = d is Map ? Map<String, dynamic>.from(d) : const {};
      _subscriptions = _rows(results[1]);
      _users = _rows(results[2]);
      _endUsers = _rows(results[3]);
      _limitVersion++;
    });
  }

  void _snack(String message, {bool isError = false}) => AppToast.result(context, message, ok: !isError);

  String _failure(Map<String, dynamic> res) =>
      _text(res['message']).isNotEmpty
          ? _text(res['message'])
          : "Couldn't save. Try again.";

  // ── Linking ──────────────────────────────────────────────────────────────

  Future<void> _openLinkSheet() async {
    final exclude = {
      for (final s in _subscriptions) _sln(s),
      for (final p in _pending) _sln(p),
    };
    final picked = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _UnlinkedSheet(exclude: exclude),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      for (final s in picked) {
        _pending.add({
          'serviceLineNumber': _sln(s),
          'nickname': _text(s['nickname']),
          'eu_code': '',
        });
      }
    });
  }

  Future<void> _saveLinks() async {
    setState(() => _savingLinks = true);
    final res = await ApiService.linkSubscriptions(_code, [
      for (final p in _pending)
        {'serviceLineNumber': _sln(p), 'eu_code': p['eu_code']},
    ]);
    if (!mounted) return;
    setState(() => _savingLinks = false);
    if (res['status'] != 'success') {
      _snack(_failure(res), isError: true);
      return;
    }
    setState(_pending.clear);
    _snack('Service lines linked');
    await _load();
  }

  void _startEndUserEdit() {
    setState(() {
      _euDraft
        ..clear()
        ..addAll({
          for (final s in _subscriptions) _sln(s): _text(s['eu_code']),
        });
      _editingEndUsers = true;
    });
  }

  Future<void> _saveEndUsers() async {
    final changed = _changedEndUsers;
    if (changed.isEmpty) {
      setState(() => _editingEndUsers = false);
      return;
    }
    setState(() => _savingEndUsers = true);
    final res = await ApiService.linkSubscriptions(_code, [
      for (final s in changed)
        {'serviceLineNumber': _sln(s), 'eu_code': _euDraft[_sln(s)] ?? ''},
    ]);
    if (!mounted) return;
    setState(() => _savingEndUsers = false);
    if (res['status'] != 'success') {
      _snack(_failure(res), isError: true);
      return;
    }
    setState(() => _editingEndUsers = false);
    _snack(
      'Updated ${changed.length} service line${changed.length == 1 ? '' : 's'}',
    );
    await _load();
  }

  Future<void> _unlink(Map<String, dynamic> s) async {
    final label =
        _text(s['nickname']).isNotEmpty ? _text(s['nickname']) : _sln(s);
    final ok = await showAppConfirm(context, title: 'Unlink service line?', message: 'Unlink $label from $_name?', confirmLabel: 'Unlink', icon: Icons.link_off_rounded, tone: AppDialogTone.danger);
    if (ok != true || !mounted) return;
    final res = await ApiService.unlinkSubscription(_sln(s));
    if (!mounted) return;
    if (res['status'] != 'success') {
      _snack(_failure(res), isError: true);
      return;
    }
    _snack('Unlinked');
    await _load();
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  Future<void> _openSubscription(Map<String, dynamic> s) async {
    final sln = _sln(s);
    if (sln.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminSubscriptionDetailsPage(
              serviceLineNumber: sln,
              title:
                  _text(s['nickname']).isNotEmpty ? _text(s['nickname']) : sln,
            ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openUser(Map<String, dynamic> u) async {
    final id = _text(u['id']);
    if (id.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminUserDetailPage(userId: id)),
    );
    if (mounted) _load();
  }

  void _addUser() {
    showModalBottomSheet(
      context: context,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder:
          (_) => CreateUserSheet(
            currentUserRole: 'admin',
            prefilledRole: 'customer',
            prefilledCompanyCode: _code,
            prefilledCompanyName: _name,
            onCreated: () {
              _snack('User invited — an email has been sent');
              _load();
            },
            onError: (message) => _snack(message, isError: true),
          ),
    );
  }

  Future<void> _openEndUser(Map<String, dynamic> e) async {
    final code = _text(e['eu_code']);
    if (code.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminEndUserDetailsPage(
              endUserId: code,
              endUserCode: code,
              endUserName: _text(e['eu_name']),
            ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _addEndUser() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCreateEndUserPage(initialCustomerCode: _code),
      ),
    );
    if (created == true && mounted) _load();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _isDirty,
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        appBar: AppBar(title: const Text('Customer')),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildTabs(),
                      const SizedBox(height: 14),
                      if (_tab == 0)
                        _buildSubscriptions()
                      else if (_tab == 1)
                        _buildUsers()
                      else
                        _buildEndUsers(),
                    ],
                  ),
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
            'Customer not found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (_error!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
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
    final inactive = _text(_customer?['inactive']);
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.navy,
            child: Text(
              accountInitials(_name),
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
                  _name.isEmpty ? '—' : _name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.3,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _code,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkFaint,
                      ),
                    ),
                    if (inactive.isNotEmpty)
                      DotBadge(
                        inactive == 'N' ? 'ACTIVE' : 'INACTIVE',
                        color:
                            inactive == 'N'
                                ? AppColors.successInk
                                : AppColors.inkMuted,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() => AccountTabs(
    tabs: [
      ('Subscriptions', _subscriptions.length),
      ('Users', _users.length),
      ('End Users', _endUsers.length),
    ],
    selected: _tab,
    onSelected: (i) => setState(() => _tab = i),
  );

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.navy,
    ),
  );

  List<SelectOption<String>> get _endUserOptions => [
    const SelectOption('', 'No end user'),
    for (final e in _endUsers)
      SelectOption(_text(e['eu_code']), _text(e['eu_name'])),
  ];

  // ── Subscriptions ────────────────────────────────────────────────────────

  Widget _buildSubscriptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Linked service lines'),
        const SizedBox(height: 8),
        if (_editingEndUsers)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _savingEndUsers
                          ? null
                          : () => setState(() => _editingEndUsers = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _savingEndUsers ? null : _saveEndUsers,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_savingEndUsers ? 'Saving…' : 'Save end users'),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openLinkSheet,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 17),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Link service lines'),
                  ),
                ),
              ),
              if (_subscriptions.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _startEndUserEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Edit end users'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 12),
        if (_pending.isNotEmpty) ...[
          _buildPending(),
          const SizedBox(height: 12),
        ],
        if (_subscriptions.isEmpty)
          AccountEmptyCard('No linked service lines.')
        else
          for (final s in _subscriptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSubscriptionCard(s),
            ),
      ],
    );
  }

  Widget _buildPending() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assign end users, then save',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
          for (var i = 0; i < _pending.length; i++) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(_pending[i]['nickname']).isNotEmpty
                            ? _text(_pending[i]['nickname'])
                            : _sln(_pending[i]),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        _sln(_pending[i]),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _pending.removeAt(i)),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            AppSelect<String>(
              dense: true,
              sheetTitle: 'End user',
              value: _text(_pending[i]['eu_code']),
              options: _endUserOptions,
              onChanged: (v) => setState(() => _pending[i]['eu_code'] = v),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _savingLinks ? null : _saveLinks,
              child: Text(_savingLinks ? 'Saving…' : 'Save links'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> s) {
    final sln = _sln(s);
    final nickname = _text(s['nickname']);
    final used = num.tryParse(_text(s['totalPriorityGB']));
    final plan = _text(s['dataplan']);
    final endUser =
        _text(s['eu_name']).isNotEmpty
            ? _text(s['eu_name'])
            : _text(s['end_user_name']);
    final kit = _text(s['kit_number']);
    final status = subscriptionStatusLabel(s['active'] ?? s['status']);
    return AccountRowCard(
      onTap: _editingEndUsers ? null : () => _openSubscription(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  nickname.isNotEmpty ? nickname : sln,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DotBadge(
                status,
                color:
                    status == 'ACTIVE'
                        ? AppColors.successInk
                        : AppColors.inkMuted,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sln,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
          AccountDetailRow(
            'Current plan usage',
            '${(used ?? 0).toStringAsFixed(2)} GB / '
                '${plan.isEmpty ? '—' : plan} GB',
          ),
          if (_editingEndUsers) ...[
            const SizedBox(height: 8),
            AppSelect<String>(
              label: 'End user',
              sheetTitle: 'End user',
              dense: true,
              value: _euDraft[sln] ?? '',
              options: _endUserOptions,
              onChanged: (v) => setState(() => _euDraft[sln] = v),
            ),
          ] else ...[
            const SizedBox(height: 4),
            AccountDetailRow('End user', endUser.isEmpty ? '—' : endUser),
          ],
          const SizedBox(height: 4),
          AccountDetailRow('Kit', kit.isEmpty ? '—' : kit),
          if (!_editingEndUsers)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _unlink(s),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(0, 32),
                ),
                icon: const Icon(Icons.link_off_rounded, size: 16),
                label: const Text('Unlink', style: TextStyle(fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Users ────────────────────────────────────────────────────────────────

  Widget _heading(String title, String action, VoidCallback onTap) => Row(
    children: [
      Expanded(child: _title(title)),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.add_rounded, size: 17),
        label: Text(action, style: const TextStyle(fontSize: 12.5)),
      ),
    ],
  );

  Widget _buildUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Users at this company', 'Add user', _addUser),
        const SizedBox(height: 12),
        AccountLimitCard(key: ValueKey(_limitVersion), code: _code),
        const SizedBox(height: 12),
        if (_users.isEmpty)
          AccountEmptyCard('No users.')
        else
          for (final u in _users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AccountUserCard(user: u, onTap: () => _openUser(u)),
            ),
      ],
    );
  }

  // ── End users ────────────────────────────────────────────────────────────

  Widget _buildEndUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('End users', 'Add end user', _addEndUser),
        const SizedBox(height: 12),
        if (_endUsers.isEmpty)
          AccountEmptyCard('No end users.')
        else
          for (final e in _endUsers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AccountRowCard(
                onTap: () => _openEndUser(e),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(e['eu_code']),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _text(e['eu_name']),
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    DotBadge(
                      _text(e['inactive']) == 'N' ? 'ACTIVE' : 'INACTIVE',
                      color:
                          _text(e['inactive']) == 'N'
                              ? AppColors.successInk
                              : AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Service lines with no customer: search, tick several, add them to assign.
class _UnlinkedSheet extends StatefulWidget {
  const _UnlinkedSheet({required this.exclude});
  final Set<String> exclude;

  @override
  State<_UnlinkedSheet> createState() => _UnlinkedSheetState();
}

class _UnlinkedSheetState extends State<_UnlinkedSheet> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _all = const [];
  final Map<String, Map<String, dynamic>> _picked = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ApiService.getUnlinkedSubscriptions(limit: 1000);
    if (!mounted) return;
    final d = res['data'];
    final list =
        d is List
            ? d
            : (d is Map && d['data'] is List ? d['data'] as List : []);
    setState(() {
      _loading = false;
      if (res['status'] != 'success') {
        _error = _text(res['message']);
        return;
      }
      _all = [
        for (final m in list.whereType<Map>())
          if (!widget.exclude.contains(_sln(Map<String, dynamic>.from(m))))
            Map<String, dynamic>.from(m),
      ];
    });
  }

  List<Map<String, dynamic>> get _matches {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((s) {
      return [
        s['nickname'],
        _sln(s),
        s['kit_number'],
      ].any((v) => _text(v).toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlinked service lines',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search nickname, service line or kit…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : matches.isEmpty
                      ? Center(
                        child: Text(
                          _error?.isNotEmpty == true
                              ? _error!
                              : 'No unlinked service lines.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, i) {
                          final s = matches[i];
                          final sln = _sln(s);
                          final nickname = _text(s['nickname']);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.brand,
                            value: _picked.containsKey(sln),
                            title: Text(
                              nickname.isNotEmpty ? nickname : sln,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            subtitle: Text(
                              sln,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            onChanged:
                                (v) => setState(() {
                                  if (v == true) {
                                    _picked[sln] = s;
                                  } else {
                                    _picked.remove(sln);
                                  }
                                }),
                          );
                        },
                      ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _picked.isEmpty
                        ? null
                        : () => Navigator.pop(context, _picked.values.toList()),
                child: Text(
                  _picked.isEmpty
                      ? 'Add to assign'
                      : 'Add ${_picked.length} to assign',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
