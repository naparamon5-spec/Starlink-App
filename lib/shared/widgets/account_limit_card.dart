import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';

/// "X of Y user accounts" for a customer company or end user, with
/// "Change limit" (admins and agents). Mirrors the web portal's
/// AccountLimit component: GET/PUT /account-limits/:code. Active accounts
/// and invitations not yet accepted count; deactivated ones don't. Hidden
/// when the code has no limit (Ardent staff) or the lookup fails.
class AccountLimitCard extends StatefulWidget {
  const AccountLimitCard({super.key, required this.code});

  final String code;

  @override
  State<AccountLimitCard> createState() => AccountLimitCardState();
}

class AccountLimitCardState extends State<AccountLimitCard> {
  Map<String, dynamic>? _usage;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(AccountLimitCard old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) reload();
  }

  Future<void> reload() async {
    if (widget.code.trim().isEmpty) return;
    final res = await ApiService.getAccountLimit(widget.code);
    if (!mounted) return;
    final data = res['data'];
    setState(
      () =>
          _usage =
              res['status'] == 'success' && data is Map
                  ? Map<String, dynamic>.from(data)
                  : null,
    );
  }

  int? get _limit {
    final v = _usage?['limit'];
    return v == null ? null : int.tryParse(v.toString());
  }

  int get _used => int.tryParse('${_usage?['used'] ?? 0}') ?? 0;
  bool get _isDefault => _usage?['isDefault'] == true;
  bool get _full => _limit != null && _used >= _limit!;

  Future<void> _edit() async {
    final result = await showDialog<_LimitChoice>(
      context: context,
      builder:
          (ctx) => _LimitDialog(
            initialLimit: _limit ?? 3,
            isDefault: _isDefault,
          ),
    );
    if (result == null || !mounted) return;
    final res = await ApiService.setAccountLimit(widget.code, result.value);
    if (!mounted) return;
    final ok = res['status'] == 'success';
    AppToast.result(context, ok
              ? 'Account limit saved'
              : res['message']?.toString() ?? 'Could not save the limit', ok: ok);
    if (ok) {
      final data = res['data'];
      if (data is Map) {
        setState(() => _usage = Map<String, dynamic>.from(data));
      } else {
        reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_usage == null || _limit == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color:
            _full ? AppColors.warning.withValues(alpha: 0.06) : AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _full
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.lineSoft,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_used of $_limit user accounts',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  _full
                      ? 'Full: deactivate one or raise the limit to add more'
                      : (_isDefault ? 'Default limit' : 'Raised limit'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _full ? AppColors.warningInk : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _edit, child: const Text('Change limit')),
        ],
      ),
    );
  }
}

class _LimitChoice {
  const _LimitChoice(this.value);
  final int? value; // null = back to the default
}

class _LimitDialog extends StatefulWidget {
  const _LimitDialog({required this.initialLimit, required this.isDefault});
  final int initialLimit;
  final bool isDefault;

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  // Owned here so it outlives the dialog's closing animation, which keeps
  // rebuilding the TextField after showDialog has returned.
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initialLimit}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _problem {
    final n = int.tryParse(_controller.text.trim());
    return n != null && n >= 1 && n <= 100
        ? null
        : 'Enter a whole number from 1 to 100';
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: Icons.group_outlined,
      title: 'User account limit',
      message:
          'How many portal accounts this company or end user may have. '
          "Active accounts and invitations not yet accepted count; "
          "deactivated ones don't. The default is 3.",
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Maximum accounts',
          errorText: _problem,
        ),
      ),
      confirmLabel: 'Save',
      onConfirm:
          _problem != null
              ? null
              : () => Navigator.pop(
                context,
                _LimitChoice(int.parse(_controller.text.trim())),
              ),
      cancelLabel: 'Cancel',
      onCancel: () => Navigator.pop(context),
      extraLabel: widget.isDefault ? null : 'Use default (3)',
      onExtra: () => Navigator.pop(context, const _LimitChoice(null)),
    );
  }
}
