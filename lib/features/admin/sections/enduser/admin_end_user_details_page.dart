import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/status_labels.dart';
import 'package:starlink_app/features/admin/profile/admin_manage_users_page.dart';
import 'package:starlink_app/features/admin/profile/view-user/admin_view_user_details_page.dart';
import 'package:starlink_app/features/admin/sections/subscription/admin_subscription_details_page.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/account_detail_parts.dart';
import 'package:starlink_app/shared/widgets/account_limit_card.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// One end user: name, codes and status, then subscriptions and users.
class AdminEndUserDetailsPage extends StatefulWidget {
  const AdminEndUserDetailsPage({
    super.key,
    required this.endUserId,
    required this.endUserCode,
    required this.endUserName,
  });

  final String endUserId;
  final String endUserCode;
  final String endUserName;

  @override
  State<AdminEndUserDetailsPage> createState() =>
      _AdminEndUserDetailsPageState();
}

class _AdminEndUserDetailsPageState extends State<AdminEndUserDetailsPage> {
  bool _loading = true;
  String? _error;
  bool _toggling = false;
  int _tab = 0;
  int _limitVersion = 0;

  Map<String, dynamic>? _endUser;
  List<Map<String, dynamic>> _subscriptions = const [];
  List<Map<String, dynamic>> _users = const [];

  String get _code {
    final code = accountText(_endUser?['eu_code']);
    if (code.isNotEmpty) return code;
    return widget.endUserCode.trim().isNotEmpty
        ? widget.endUserCode.trim()
        : widget.endUserId.trim();
  }

  String get _name {
    final name = accountText(_endUser?['eu_name']);
    return name.isNotEmpty ? name : widget.endUserName;
  }

  bool get _active => accountText(_endUser?['inactive']) == 'N';

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
    final code = _code;
    if (code.isEmpty) {
      setState(() {
        _loading = false;
        _error = '';
      });
      return;
    }
    setState(() {
      _loading = _endUser == null;
      _error = null;
    });
    final results = await Future.wait(<Future<Map<String, dynamic>>>[
      ApiService.getEndUserById(code),
      ApiService.getSubscriptionsByEndUserId(code),
      ApiService.getUsersByCompanyCode(code),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0]['status'] != 'success') {
        _error = accountText(results[0]['message']);
        return;
      }
      final d = results[0]['data'];
      _endUser = d is Map ? Map<String, dynamic>.from(d) : const {};
      _subscriptions = _rows(results[1]);
      _users = _rows(results[2]);
      _limitVersion++;
    });
  }

  void _snack(String message, {bool isError = false}) => AppToast.result(context, message, ok: !isError);

  Future<void> _toggleStatus() async {
    final activate = !_active;
    if (!activate) {
      final ok = await showAppConfirm(context, title: 'Deactivate end user?', message: '$_name will be marked inactive. You can activate it again later.', confirmLabel: 'Deactivate', icon: Icons.person_off_outlined, tone: AppDialogTone.danger);
      if (ok != true || !mounted) return;
    }
    setState(() => _toggling = true);
    final res =
        activate
            ? await ApiService.activateEndUser(_code)
            : await ApiService.deactivateEndUser(_code);
    if (!mounted) return;
    final ok = res['status'] == 'success';
    setState(() {
      _toggling = false;
      if (ok) {
        _endUser = {...?_endUser, 'inactive': activate ? 'N' : 'Y'};
      }
    });
    _snack(
      ok
          ? 'Status updated'
          : accountText(res['message']).isNotEmpty
          ? accountText(res['message'])
          : "Couldn't update the status.", isError: !ok);
  }

  Future<void> _rename() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: _name),
    );
    if (name == null || name.isEmpty || name == _name || !mounted) return;
    final res = await ApiService.renameEndUser(_code, name);
    if (!mounted) return;
    final ok = res['status'] == 'success';
    if (ok) setState(() => _endUser = {...?_endUser, 'eu_name': name});
    _snack(
      ok
          ? 'Name updated'
          : accountText(res['message']).isNotEmpty
          ? accountText(res['message'])
          : "Couldn't rename this end user.", isError: !ok);
  }

  Future<void> _openSubscription(Map<String, dynamic> s) async {
    final sln = accountText(s['serviceLineNumber']);
    if (sln.isEmpty) return;
    final nickname = accountText(s['nickname']);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminSubscriptionDetailsPage(
              serviceLineNumber: sln,
              title: nickname.isNotEmpty ? nickname : sln,
            ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openUser(Map<String, dynamic> u) async {
    final id = accountText(u['id']);
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
            prefilledRole: 'end_user',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      appBar: AppBar(title: const Text('End User')),
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
                    AccountTabs(
                      tabs: [
                        ('Subscriptions', _subscriptions.length),
                        ('Users', _users.length),
                      ],
                      selected: _tab,
                      onSelected: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 14),
                    if (_tab == 0) _buildSubscriptions() else _buildUsers(),
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
            'End user not found',
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
    final customer = accountText(_endUser?['customer_code']);
    const compact = Size(0, 34);
    const padding = EdgeInsets.symmetric(horizontal: 14);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const SizedBox(height: 4),
                    Text(
                      '$_code  ·  ${customer.isEmpty ? '—' : customer}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rename',
                visualDensity: VisualDensity.compact,
                onPressed: _rename,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.inkFaint,
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
                  _active ? 'ACTIVE' : 'INACTIVE',
                  color: _active ? AppColors.successInk : AppColors.inkMuted,
                ),
                if (_active)
                  TextButton(
                    onPressed: _toggling ? null : _toggleStatus,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      minimumSize: compact,
                      padding: padding,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Deactivate'),
                  )
                else
                  OutlinedButton(
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

  Widget _buildSubscriptions() {
    if (_subscriptions.isEmpty) {
      return const AccountEmptyCard('No subscriptions.');
    }
    return Column(
      children: [
        for (final s in _subscriptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildSubscriptionCard(s),
          ),
      ],
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> s) {
    final sln = accountText(s['serviceLineNumber']);
    final nickname = accountText(s['nickname']);
    final used = num.tryParse(accountText(s['totalPriorityGB']));
    final plan = accountText(s['dataplan']);
    final kit = accountText(s['kit_number']);
    final status = subscriptionStatusLabel(s['active'] ?? s['status']);
    return AccountRowCard(
      onTap: () => _openSubscription(s),
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
          const SizedBox(height: 4),
          AccountDetailRow('Kit', kit.isEmpty ? '—' : kit),
        ],
      ),
    );
  }

  Widget _buildUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _addUser,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Add user', style: TextStyle(fontSize: 12.5)),
          ),
        ),
        const SizedBox(height: 12),
        AccountLimitCard(key: ValueKey(_limitVersion), code: _code),
        const SizedBox(height: 12),
        if (_users.isEmpty)
          const AccountEmptyCard('No users.')
        else
          for (final u in _users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AccountUserCard(user: u, onTap: () => _openUser(u)),
            ),
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    icon: Icons.edit_outlined,
    title: 'Rename end user',
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(hintText: 'End user name'),
    ),
    confirmLabel: 'Save',
    onConfirm: () => Navigator.pop(context, _ctrl.text.trim()),
    cancelLabel: 'Cancel',
    onCancel: () => Navigator.pop(context),
  );
}
