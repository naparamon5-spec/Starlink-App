import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/billing_export.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/features/billing/billing_import.dart';
import 'package:starlink_app/services/api_service.dart';

/// Connects the app bar's billing menu to the list on screen.
class BillingListController extends ListExportController {
  /// Reloads the list after an import.
  VoidCallback? reload;
}

/// Three dots for the app bar: a slide-up sheet with Export, Template and
/// Import Excel. The same roles as the web portal see each; a role with
/// nothing to do here (customers) sees no button.
class BillingActionsButton extends StatefulWidget {
  const BillingActionsButton({super.key, required this.controller});

  final BillingListController controller;

  @override
  State<BillingActionsButton> createState() => _BillingActionsButtonState();
}

class _BillingActionsButtonState extends State<BillingActionsButton> {
  String _role = '';
  bool _busy = false;

  bool get _canExport => const ['admin', 'agent', 'biller'].contains(_role);

  /// Import is limited to these roles on the server.
  bool get _canImport => const ['admin', 'biller'].contains(_role);

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final me = await ApiService.getMe();
    if (!mounted) return;
    final data = me['data'];
    setState(() {
      _role = data is Map ? '${data['role'] ?? ''}'.trim().toLowerCase() : '';
    });
  }

  Future<void> _open() async {
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      'Billing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  if (_canExport)
                    _option(
                      ctx,
                      value: 'export',
                      icon: Icons.file_download_outlined,
                      title: 'Export',
                      subtitle: 'Save the records shown to Excel',
                    ),
                  if (_canImport) ...[
                    _option(
                      ctx,
                      value: 'template',
                      icon: Icons.note_add_outlined,
                      title: 'Template',
                      subtitle: 'Empty file with the columns Import reads',
                    ),
                    _option(
                      ctx,
                      value: 'import',
                      icon: Icons.file_upload_outlined,
                      title: 'Import Excel',
                      subtitle: 'Upload an .xlsx or .csv file',
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'export':
        await _run(
          () => runListExport(
            context,
            controller: widget.controller,
            emptyMessage: 'No billing records match your search',
            filePrefix: 'billing',
            sheetName: 'Billing',
            headers: billingExportHeaders,
            rowsOf: billingExportRows,
          ),
        );
      case 'template':
        await _run(() => downloadBillingTemplate(context));
      case 'import':
        await _upload();
    }
  }

  /// Straight to the file picker; the upload starts once a file is chosen.
  Future<void> _upload() async {
    final toast = AppToast.of(context);
    try {
      final result = await pickAndUploadBilling(
        onPicked: () {
          if (mounted) setState(() => _busy = true);
        },
      );
      if (result == null) return;
      toast.showResult(result.message, ok: result.saved);
      if (result.saved) widget.controller.reload?.call();
    } catch (_) {
      toast.showError("Couldn't upload the file. Nothing was changed.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() => _busy = true);
    await work();
    if (mounted) setState(() => _busy = false);
  }

  Widget _option(
    BuildContext ctx, {
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) => ListTile(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: AppColors.navy),
    ),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
    ),
    onTap: () => Navigator.pop(ctx, value),
  );

  @override
  Widget build(BuildContext context) {
    if (!_canExport && !_canImport) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Billing actions',
      onPressed: _busy ? null : _open,
      icon:
          _busy
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : const Icon(Icons.more_vert_rounded, color: Colors.white),
    );
  }
}
