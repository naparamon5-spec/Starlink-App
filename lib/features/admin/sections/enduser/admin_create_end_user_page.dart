import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

class _EndUserRow {
  _EndUserRow(this.customerCode);
  final name = TextEditingController();
  String? customerCode;
  String? nameError;
  String? customerError;
}

/// Add one or more end users in one go (POST /end-user/).
class AdminCreateEndUserPage extends StatefulWidget {
  const AdminCreateEndUserPage({super.key, this.initialCustomerCode});

  /// Preselects the customer, e.g. when adding from that customer's page.
  final String? initialCustomerCode;

  @override
  State<AdminCreateEndUserPage> createState() => _AdminCreateEndUserPageState();
}

class _AdminCreateEndUserPageState extends State<AdminCreateEndUserPage> {
  late final List<_EndUserRow> _rows = [_EndUserRow(_preset)];
  List<SelectOption<String>> _customers = const [];
  bool _loadingCustomers = true;
  bool _saving = false;

  String? get _preset => widget.initialCustomerCode;

  /// A row is untouched when it has no name and only the preset customer.
  bool _isBlank(_EndUserRow r) =>
      r.name.text.trim().isEmpty &&
      (r.customerCode == null || r.customerCode == _preset);

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.name.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final res = await ApiService.getCustomersListAll();
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _loadingCustomers = false;
      _customers = [
        for (final m in (data is List ? data : const []).whereType<Map>())
          if ('${m['label'] ?? ''}'.trim().isNotEmpty &&
              '${m['value'] ?? ''}'.trim().isNotEmpty)
            SelectOption('${m['value']}'.trim(), '${m['label']}'.trim()),
      ];
    });
  }

  void _addRow() => setState(() => _rows.add(_EndUserRow(_preset)));

  void _removeRow(int i) {
    final row = _rows[i];
    setState(() => _rows.removeAt(i));
    row.name.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    var incomplete = false;
    setState(() {
      for (final r in _rows) {
        r.nameError = null;
        r.customerError = null;
        if (_isBlank(r)) continue;
        if (r.name.text.trim().isEmpty) {
          r.nameError = 'Enter a name';
          incomplete = true;
        }
        if (r.customerCode == null) {
          r.customerError = 'Select a customer';
          incomplete = true;
        }
      }
    });
    if (incomplete) {
      AppToast.error(context, 'Some rows are incomplete. Fix them or remove them.');
      return;
    }
    final valid = _rows.where((r) => !_isBlank(r)).toList();
    if (valid.isEmpty) {
      AppToast.error(context, 'Add at least one end user with a name and customer.');
      return;
    }
    setState(() => _saving = true);
    final res = await ApiService.createEndUser({
      'formData': [
        for (final r in valid)
          {'eu_name': r.name.text.trim(), 'customer_code': r.customerCode},
      ],
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['status'] != 'success') {
      AppToast.error(
        context,
        res['message']?.toString() ?? "Couldn't create the end users.",
      );
      return;
    }
    final toast = AppToast.of(context);
    Navigator.pop(context, true);
    toast.showSuccess('Created ${valid.length} end user${valid.length == 1 ? '' : 's'}');
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.ink,
      ),
    ),
  );

  Widget _buildRow(int i) {
    final r = _rows[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (i > 0) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
        ],
        if (_rows.length > 1)
          Row(
            children: [
              Expanded(
                child: Text(
                  'End user ${i + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove end user ${i + 1}',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _removeRow(i),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
        _label('End user name'),
        TextField(
          key: ObjectKey(r),
          controller: r.name,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          onChanged:
              (_) => setState(() {
                r.nameError = null;
              }),
          decoration: InputDecoration(
            hintText: 'Full name',
            errorText: r.nameError,
          ),
        ),
        const SizedBox(height: 12),
        _label('Customer'),
        AppSelect<String>(
          sheetTitle: 'Customer',
          value: r.customerCode,
          hint: _loadingCustomers ? 'Loading…' : 'Select customer',
          enabled: !_saving,
          options: _customers,
          onChanged:
              (v) => setState(() {
                r.customerCode = v;
                r.customerError = null;
              }),
        ),
        if (r.customerError != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Text(
              r.customerError!,
              style: const TextStyle(fontSize: 12, color: AppColors.dangerInk),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _rows.length > 1 || _rows.any((r) => !_isBlank(r)),
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        appBar: AppBar(title: const Text('New End Users')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Add one or more end users.',
              style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _rows.length; i++) _buildRow(i),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _saving ? null : _addRow,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add another'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
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
                            : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Create end users'),
                            ),
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
