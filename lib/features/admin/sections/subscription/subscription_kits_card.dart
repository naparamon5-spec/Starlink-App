import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/admin/sections/subscription/router_settings_page.dart';
import 'package:starlink_app/services/api_service.dart';

/// Kits on a service line (routerTerminalMap) with the web portal's staff
/// tools: router settings, move a kit to another line, remove a kit.
/// Moving or removing changes the portal's record only; the terminal itself
/// is moved in Starlink's dashboard.
class SubscriptionKitsCard extends StatelessWidget {
  const SubscriptionKitsCard({
    super.key,
    required this.serviceLineNumber,
    required this.terminals,
    required this.onChanged,
    this.canManage = true,
    this.canViewRouter = true,
  });

  final String serviceLineNumber;
  final dynamic terminals;
  final Future<void> Function() onChanged;

  /// Move and remove (admin, agent).
  final bool canManage;

  /// Router settings (staff).
  final bool canViewRouter;

  List<Map<String, dynamic>> get _rows =>
      terminals is List
          ? (terminals as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : const [];

  static String _s(dynamic v) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty || t == 'null' ? '' : t;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: Text(
                  'No terminal mapped.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkFaint),
                ),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              _KitRow(
                row: rows[i],
                serviceLineNumber: serviceLineNumber,
                onChanged: onChanged,
                canManage: canManage,
                canViewRouter: canViewRouter,
              ),
            ],
        ],
      ),
    );
  }
}

class _KitRow extends StatelessWidget {
  const _KitRow({
    required this.row,
    required this.serviceLineNumber,
    required this.onChanged,
    required this.canManage,
    required this.canViewRouter,
  });

  final bool canManage;
  final bool canViewRouter;

  final Map<String, dynamic> row;
  final String serviceLineNumber;
  final Future<void> Function() onChanged;

  String get _kit =>
      SubscriptionKitsCard._s(row['kit_number'] ?? row['kitNumber']);
  String get _routerId =>
      SubscriptionKitsCard._s(row['router_id'] ?? row['routerId']);

  void _snack(BuildContext context, String msg, {bool isError = false}) =>
      AppToast.result(context, msg, ok: !isError);

  Future<void> _remove(BuildContext context) async {
    final ok = await showAppConfirm(context, title: 'Remove kit $_kit?', message: 'The kit is removed from $serviceLineNumber in the portal. '
"This doesn't change anything in Starlink.", confirmLabel: 'Remove', icon: Icons.link_off_rounded, tone: AppDialogTone.danger);
    if (ok != true || !context.mounted) return;
    final res = await ApiService.removeKit(serviceLineNumber, _kit);
    if (!context.mounted) return;
    _snack(
      context,
      res['message']?.toString() ??
          (res['status'] == 'success'
              ? 'Kit removed'
              : 'Could not remove the kit'), isError: res['status'] != 'success');
    if (res['status'] == 'success') await onChanged();
  }

  Future<void> _move(BuildContext context) async {
    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LinePicker(exclude: serviceLineNumber),
    );
    if (target == null || !context.mounted) return;
    final ok = await showAppConfirm(context, title: 'Move kit $_kit?', message: 'From $serviceLineNumber to $target. This changes the portal '
'record only; move the terminal in Starlink too.', confirmLabel: 'Move', icon: Icons.swap_horiz_rounded);
    if (ok != true || !context.mounted) return;
    final res = await ApiService.moveKit(serviceLineNumber, _kit, target);
    if (!context.mounted) return;
    _snack(
      context,
      res['message']?.toString() ??
          (res['status'] == 'success' ? 'Kit moved' : 'Could not move the kit'), isError: res['status'] != 'success');
    if (res['status'] == 'success') await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final serial = SubscriptionKitsCard._s(
      row['serial_number'] ?? row['serialNumber'],
    );
    final starlinkId = SubscriptionKitsCard._s(
      row['starlink_id'] ?? row['starlinkId'],
    );
    final inactive = SubscriptionKitsCard._s(row['inactive']) == 'Y';
    final statusColor = inactive ? AppColors.inkMuted : AppColors.successInk;
    final hasRouter = _routerId.isNotEmpty;
    final hasKit = _kit.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasKit ? _kit : 'Kit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  inactive ? 'INACTIVE' : 'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: statusColor,
                  ),
                ),
              ),
              if (hasKit && (canManage || (canViewRouter && hasRouter)))
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: 'Kit actions',
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
                    onPressed: () => _openActions(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (serial.isNotEmpty) _meta('Serial', serial),
          if (starlinkId.isNotEmpty) _meta('Starlink ID', starlinkId),
          if (hasRouter) _meta('Router', _routerId),
        ],
      ),
    );
  }

  /// Slide-up sheet with what can be done to this kit.
  Future<void> _openActions(BuildContext context) async {
    final hasRouter = _routerId.isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      _kit,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  if (hasRouter && canViewRouter)
                    _sheetOption(
                      ctx,
                      value: 'router',
                      icon: Icons.settings_outlined,
                      title: 'Router settings',
                      subtitle: 'Wi-Fi names and passwords, bands, restart',
                    ),
                  if (canManage) ...[
                    _sheetOption(
                      ctx,
                      value: 'move',
                      icon: Icons.swap_horiz_rounded,
                      title: 'Move to another line',
                      subtitle: 'Changes the portal record only',
                    ),
                    _sheetOption(
                      ctx,
                      value: 'remove',
                      icon: Icons.delete_outline_rounded,
                      title: 'Remove from this line',
                      subtitle: 'Asks you to confirm first',
                      color: AppColors.dangerInk,
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'router':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => RouterSettingsPage(routerId: _routerId, kitNumber: _kit),
          ),
        );
      case 'move':
        _move(context);
      case 'remove':
        _remove(context);
    }
  }

  Widget _sheetOption(
    BuildContext ctx, {
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = AppColors.navy,
  }) => ListTile(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color == AppColors.navy ? AppColors.ink : color,
      ),
    ),
    subtitle: Text(subtitle),
    onTap: () => Navigator.pop(ctx, value),
  );

  /// Label on the left, value on the right, like the Hardware rows above.
  Widget _meta(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A3)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Bottom sheet: search service lines and pick one.
class _LinePicker extends StatefulWidget {
  const _LinePicker({required this.exclude});
  final String exclude;

  @override
  State<_LinePicker> createState() => _LinePickerState();
}

class _LinePickerState extends State<_LinePicker> {
  final _q = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(v));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    final seq = ++_seq;
    setState(() => _loading = true);
    final res = await ApiService.searchSubscriptions(query);
    if (!mounted || seq != _seq) return;
    final data = res['data'];
    final list =
        data is List
            ? data
            : (data is Map && data['data'] is List
                ? data['data'] as List
                : const []);
    setState(() {
      _loading = false;
      _results =
          list
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .where(
                (m) => m['serviceLineNumber']?.toString() != widget.exclude,
              )
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Move kit to…',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search service line, nickname, kit…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child:
                    _results.isEmpty
                        ? Center(
                          child: Text(
                            _q.text.trim().length < 2
                                ? 'Type at least 2 characters'
                                : (_loading ? '' : 'No service lines found'),
                            style: const TextStyle(color: AppColors.inkFaint),
                          ),
                        )
                        : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = _results[i];
                            final sln =
                                r['serviceLineNumber']?.toString() ?? '';
                            return ListTile(
                              title: Text(
                                (r['nickname']?.toString().trim().isNotEmpty ??
                                        false)
                                    ? r['nickname'].toString()
                                    : sln,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                [
                                      sln,
                                      r['company_name'] ??
                                          r['end_user_name'] ??
                                          '',
                                    ]
                                    .where((e) => e.toString().isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.pop(context, sln),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
