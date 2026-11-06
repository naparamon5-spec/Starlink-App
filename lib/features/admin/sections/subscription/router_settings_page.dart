import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';

/// Live Starlink config of one router (GET /starlink/routers/:routerId), as
/// on the web portal's Router config: Wi-Fi names and passwords, the
/// 2.4 GHz / 5 GHz Wi-Fi and bypass-mode switches, and Restart. Staff can
/// change only those; everything else is shown read-only.
class RouterSettingsPage extends StatefulWidget {
  const RouterSettingsPage({super.key, required this.routerId, this.kitNumber});

  final String routerId;
  final String? kitNumber;

  @override
  State<RouterSettingsPage> createState() => _RouterSettingsPageState();
}

const _bands = {
  'RF_2GHZ': '2.4 GHz',
  'RF_5GHZ': '5 GHz',
  'RF_5GHZ_HIGH': '5 GHz (high)',
};

class _WifiRow {
  _WifiRow({
    required this.network,
    required this.bss,
    required this.ssid,
    required this.band,
    required this.bandKey,
    required this.security,
    required this.password,
  });
  final int network, bss;
  final String ssid, band, security;
  final String? bandKey; // band2ghz | band5ghz | null
  final String? password; // null: open network
}

class _Switch {
  const _Switch(
    this.key,
    this.field,
    this.onWhen,
    this.apply,
    this.label,
    this.hint,
  );
  final String key, field, apply, label, hint;
  final bool onWhen;
}

// Same rules as the API (helpers/routerWifi.js): Starlink leaves a false field
// out of the config; the apply* flag must be on for the router to use it.
const _switches = [
  _Switch(
    'band2ghz',
    'disable2ghz',
    false,
    'applyDisable2ghz',
    '2.4 GHz Wi-Fi',
    'Longer range, slower speeds',
  ),
  _Switch(
    'band5ghz',
    'disable5ghz',
    false,
    'applyDisable5ghz',
    '5 GHz Wi-Fi',
    'Faster speeds, shorter range',
  ),
  _Switch(
    'bypassMode',
    'bypassMode',
    true,
    'applyBypassMode',
    'Bypass mode',
    "Turns this router's Wi-Fi off; the site's own router takes over",
  ),
];

class _RouterSettingsPageState extends State<RouterSettingsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _config;
  bool _showPasswords = false;
  bool _canBypass = false;

  // Editing
  bool _editing = false;
  bool _saving = false;
  bool _rebooting = false;
  final List<TextEditingController> _ssidCtrls = [];
  final Map<int, TextEditingController> _pwCtrls = {};
  Map<String, bool> _draftSettings = {};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final role =
          (p.getString('role') ?? p.getString('user_role') ?? '').toLowerCase();
      if (mounted)
        setState(() => _canBypass = role == 'admin' || role == 'agent');
    });
    _load();
  }

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  void _disposeDrafts() {
    for (final c in _ssidCtrls) {
      c.dispose();
    }
    for (final c in _pwCtrls.values) {
      c.dispose();
    }
    _ssidCtrls.clear();
    _pwCtrls.clear();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _editing = false;
      _showPasswords = false;
    });
    final res = await ApiService.getRouterConfig(widget.routerId);
    if (!mounted) return;
    final data = res['data'];
    if (res['status'] != 'success' || data is! Map) {
      setState(() {
        _loading = false;
        _error =
            res['message']?.toString() ?? "Couldn't load the router config.";
      });
      return;
    }
    final result = Map<String, dynamic>.from(data);
    Map<String, dynamic>? config;
    final c = result['config'];
    if (c is Map) {
      final rc = c['routerConfig'];
      if (rc is Map) {
        config = Map<String, dynamic>.from(rc);
      } else if (c['routerConfigJson'] is String) {
        try {
          final parsed = json.decode(c['routerConfigJson'] as String);
          if (parsed is Map) config = Map<String, dynamic>.from(parsed);
        } catch (_) {}
      }
    }
    setState(() {
      _loading = false;
      _result = result;
      _config = config;
    });
  }

  // ── Derived ────────────────────────────────────────────────────────────────

  List<_WifiRow> get _wifi {
    final networks = _config?['networks'];
    if (networks is! List) return const [];
    final rows = <_WifiRow>[];
    for (var n = 0; n < networks.length; n++) {
      final sets =
          networks[n] is Map ? (networks[n] as Map)['basicServiceSets'] : null;
      if (sets is! List) continue;
      for (var b = 0; b < sets.length; b++) {
        final bss =
            sets[b] is Map
                ? Map<String, dynamic>.from(sets[b] as Map)
                : <String, dynamic>{};
        final authKey = bss.keys.cast<String?>().firstWhere(
          (k) => k!.startsWith('auth'),
          orElse: () => null,
        );
        final auth = authKey == null ? null : bss[authKey];
        final band = bss['band']?.toString() ?? '';
        rows.add(
          _WifiRow(
            network: n,
            bss: b,
            ssid: bss['ssid']?.toString() ?? '',
            band: _bands[band] ?? (band.isEmpty ? '—' : band),
            bandKey:
                band == 'RF_2GHZ'
                    ? 'band2ghz'
                    : (band == 'RF_5GHZ' ? 'band5ghz' : null),
            security: authKey == null ? 'Open' : _authLabel(authKey),
            password:
                auth is Map && auth['password'] is String
                    ? auth['password'] as String
                    : null,
          ),
        );
      }
    }
    return rows;
  }

  static String _authLabel(String key) {
    final name = key.replaceFirst(RegExp('^auth'), '');
    return name == 'Open'
        ? 'Open'
        : name.toUpperCase().replaceAll('WPA2WPA3', 'WPA2/WPA3');
  }

  Map<String, bool> get _current => {
    for (final s in _switches) s.key: (_config?[s.field] == true) == s.onWhen,
  };

  bool _controllable(_Switch s) => _config?[s.apply] == true;
  bool _locked(_Switch s) =>
      !_controllable(s) || (s.key == 'bypassMode' && !_canBypass);

  String _note(_Switch s) {
    if (!_controllable(s))
      return "This router's config doesn't control this setting";
    if (s.key == 'bypassMode' && !_canBypass)
      return 'Only admins and agents can change bypass mode';
    return s.hint;
  }

  /// Index of the first band of each network that has a password (where that
  /// network's single password box goes).
  List<bool> get _passwordRow {
    final seen = <int>{};
    return _wifi.map((w) {
      if (w.password == null || seen.contains(w.network)) return false;
      seen.add(w.network);
      return true;
    }).toList();
  }

  // ── Editing ────────────────────────────────────────────────────────────────

  void _startEdit() {
    _disposeDrafts();
    for (final w in _wifi) {
      _ssidCtrls.add(TextEditingController(text: w.ssid)..addListener(_redraw));
    }
    final pr = _passwordRow;
    final wifi = _wifi;
    for (var i = 0; i < wifi.length; i++) {
      if (pr[i])
        _pwCtrls[wifi[i].network] =
            TextEditingController()..addListener(_redraw);
    }
    setState(() {
      _draftSettings = Map.of(_current);
      _editing = true;
    });
  }

  void _redraw() => setState(() {});

  static String? _ssidProblem(String s) {
    if (s.trim().isEmpty || utf8.encode(s).length > 32)
      return 'Use 1 to 32 characters';
    if (s != s.trim()) return "Can't start or end with a space";
    return null;
  }

  static String? _passwordProblem(String p) {
    if (p.isEmpty) return null;
    return RegExp(r'^[\x20-\x7E]{8,63}$').hasMatch(p)
        ? null
        : '8 to 63 characters, no accents';
  }

  String? _newPassword(int network) {
    final p = _pwCtrls[network]?.text ?? '';
    if (p.isEmpty) return null;
    return _wifi.any(
          (w) => w.network == network && w.password != null && w.password != p,
        )
        ? p
        : null;
  }

  List<Map<String, dynamic>> get _changes {
    final wifi = _wifi;
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < wifi.length && i < _ssidCtrls.length; i++) {
      final w = wifi[i];
      final change = <String, dynamic>{'network': w.network, 'bss': w.bss};
      if (_ssidCtrls[i].text != w.ssid) change['ssid'] = _ssidCtrls[i].text;
      final pw = w.password != null ? _newPassword(w.network) : null;
      if (pw != null) change['password'] = pw;
      if (change.length > 2) out.add(change);
    }
    return out;
  }

  Map<String, bool> get _settingChanges => {
    for (final s in _switches)
      if (_draftSettings[s.key] != _current[s.key])
        s.key: _draftSettings[s.key]!,
  };

  bool get _bandsOff =>
      _draftSettings['band2ghz'] == false &&
      _draftSettings['band5ghz'] == false;

  bool get _hasErrors =>
      _ssidCtrls.any((c) => _ssidProblem(c.text) != null) ||
      _pwCtrls.values.any((c) => _passwordProblem(c.text) != null);

  bool get _canSave =>
      (_changes.isNotEmpty || _settingChanges.isNotEmpty) &&
      !_hasErrors &&
      !_bandsOff;

  String get _confirmMessage {
    final s = _settingChanges;
    final parts = <String>[];
    if (s['bypassMode'] == true) {
      parts.add(
        "Bypass mode turns off this router's Wi-Fi and hands the connection to the "
        "site's own router, plugged into the Starlink Ethernet adapter. Everyone on "
        "this router's Wi-Fi is disconnected, so only turn it on if the site has its own router.",
      );
    }
    if (s['bypassMode'] == false)
      parts.add("Bypass mode turns off and this router's Wi-Fi comes back on.");
    final bands = _switches.where(
      (w) => w.key != 'bypassMode' && s.containsKey(w.key),
    );
    final off =
        bands.where((w) => s[w.key] == false).map((w) => w.label).toList();
    final on =
        bands.where((w) => s[w.key] == true).map((w) => w.label).toList();
    if (off.isNotEmpty)
      parts.add(
        '${off.join(' and ')} turns off; devices using it are disconnected.',
      );
    if (on.isNotEmpty)
      parts.add('${on.join(' and ')} ${on.length > 1 ? 'turn' : 'turns'} on.');
    if (_changes.isNotEmpty) {
      parts.add(
        "Devices on this router's Wi-Fi will disconnect and must reconnect with the new name or password.",
      );
    }
    parts.add(
      'The router receives the change within 1–2 minutes. If other routers share this '
      "config, this router gets its own copy so they aren't affected.",
    );
    return parts.join('\n\n');
  }

  Future<void> _save() async {
    final ok = await _confirm('Save router settings?', _confirmMessage, 'Save');
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final res = await ApiService.updateRouterWifi(
      widget.routerId,
      _changes,
      _settingChanges,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
      res['message']?.toString() ??
          (res['status'] == 'success'
              ? 'Router settings saved'
              : 'Could not save'), isError: res['status'] != 'success');
    if (res['status'] == 'success') await _load();
  }

  Future<void> _reboot() async {
    final ok = await _confirm(
      'Restart router?',
      'The router restarts and is offline for a few minutes. Everyone on its Wi-Fi is disconnected until it is back.',
      'Restart',
    );
    if (ok != true || !mounted) return;
    setState(() => _rebooting = true);
    final res = await ApiService.rebootRouter(widget.routerId);
    if (!mounted) return;
    setState(() => _rebooting = false);
    _snack(
      res['message']?.toString() ??
          (res['status'] == 'success' ? 'Restart sent' : 'Could not restart'), isError: res['status'] != 'success');
  }

  Future<bool> _confirm(String title, String body, String action) =>
      showAppConfirm(context, title: title, message: body, confirmLabel: action, icon: Icons.router_outlined);

  void _snack(String msg, {bool isError = false}) =>
      AppToast.result(context, msg, ok: !isError);

  // ── UI ─────────────────────────────────────────────────────────────────────

  bool get _hasEditChanges =>
      _editing && (_changes.isNotEmpty || _settingChanges.isNotEmpty);

  Future<void> _cancelEdit() async {
    if (_hasEditChanges && !await confirmDiscardChanges(context)) return;
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _hasEditChanges,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Router settings'),
          actions: [
            if (_result != null && !_editing)
              IconButton(
                tooltip: 'Restart router',
                onPressed: _rebooting ? null : _reboot,
                icon:
                    _rebooting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.power_settings_new_rounded),
              ),
          ],
        ),
        bottomNavigationBar:
            _editing
                ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _cancelEdit,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _canSave && !_saving ? _save : null,
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
                                    : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.inkFaint,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    final router =
        _result?['router'] is Map
            ? Map<String, dynamic>.from(_result!['router'])
            : {};
    final configMeta =
        _result?['config'] is Map
            ? Map<String, dynamic>.from(_result!['config'])
            : {};
    final wifi = _wifi;
    final pr = _passwordRow;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _card(
            children: [
              _kv('Router', (router['nickname'] ?? widget.routerId).toString()),
              if ((widget.kitNumber ?? '').isNotEmpty)
                _kv('Kit', widget.kitNumber!),
              _kv(
                'Service line',
                (_result?['serviceLineNumber'] ?? '—').toString(),
              ),
              _kv('Account', (_result?['account'] ?? '—').toString()),
              _kv(
                'Config',
                (configMeta['nickname'] ?? configMeta['configId'] ?? '—')
                    .toString(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: _SectionLabel('WI-FI NETWORKS')),
              if (!_editing && wifi.any((w) => w.password != null))
                TextButton.icon(
                  onPressed:
                      () => setState(() => _showPasswords = !_showPasswords),
                  icon: Icon(
                    _showPasswords
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _showPasswords ? 'Hide passwords' : 'Show passwords',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_config == null)
            _card(
              children: const [
                Text(
                  "This router has no config yet.",
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ],
            )
          else if (wifi.isEmpty)
            _card(
              children: const [
                Text(
                  'No Wi-Fi networks in this config.',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ],
            )
          else
            _card(
              children: [
                for (var i = 0; i < wifi.length; i++) ...[
                  if (i > 0) const Divider(height: 22),
                  _wifiRow(wifi[i], i, pr[i]),
                ],
              ],
            ),
          const SizedBox(height: 16),
          const _SectionLabel('SETTINGS'),
          const SizedBox(height: 6),
          _card(
            children: [
              for (var i = 0; i < _switches.length; i++) ...[
                if (i > 0) const Divider(height: 18),
                _switchRow(_switches[i]),
              ],
              if (_editing && _bandsOff)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Keep at least one Wi-Fi band on.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.dangerInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (!_editing && _config != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    wifi.isEmpty && _switches.every(_locked)
                        ? null
                        : _startEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Wi-Fi'),
              ),
            ),
            const SizedBox(height: 16),
            _otherSettings(),
          ],
        ],
      ),
    );
  }

  Widget _wifiRow(_WifiRow w, int i, bool passwordBox) {
    final off =
        w.bandKey != null &&
        !((_editing ? _draftSettings[w.bandKey] : _current[w.bandKey]) ?? true);
    return Opacity(
      opacity: off ? 0.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_rounded, size: 16, color: AppColors.navy),
              const SizedBox(width: 6),
              Text(
                '${w.band} · ${w.security}${off ? ' · off' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_editing) ...[
            TextField(
              controller: _ssidCtrls[i],
              decoration: InputDecoration(
                labelText: 'Network name (SSID)',
                errorText: _ssidProblem(_ssidCtrls[i].text),
              ),
            ),
            if (passwordBox) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _pwCtrls[w.network],
                decoration: InputDecoration(
                  labelText: 'New Wi-Fi password',
                  helperText: 'Applies to all bands. Leave empty to keep it.',
                  helperMaxLines: 2,
                  errorText: _passwordProblem(_pwCtrls[w.network]?.text ?? ''),
                ),
              ),
            ],
          ] else ...[
            Text(
              w.ssid.isEmpty ? '—' : w.ssid,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (w.password != null) ...[
              const SizedBox(height: 2),
              SelectableText(
                _showPasswords ? w.password! : '••••••••',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.inkSoft,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _switchRow(_Switch s) {
    final value = (_editing ? _draftSettings[s.key] : _current[s.key]) ?? false;
    final locked = _locked(s);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _note(s),
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged:
              _editing && !locked
                  ? (v) => setState(() => _draftSettings[s.key] = v)
                  : null,
        ),
      ],
    );
  }

  Widget _otherSettings() {
    final plain = <MapEntry<String, String>>[];
    final controlled = <String>[];
    final switchFields = _switches.map((s) => s.field).toSet();
    (_config ?? {}).forEach((k, v) {
      if (k.startsWith('apply')) {
        if (v == true) controlled.add(_label(k));
      } else if (!switchFields.contains(k) &&
          (v == null || v is! Map && v is! List)) {
        plain.add(
          MapEntry(
            _label(k),
            v == true
                ? 'Yes'
                : v == false
                ? 'No'
                : (v == null || v == '' ? '—' : '$v'),
          ),
        );
      }
    });
    if (plain.isEmpty && controlled.isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text(
            'Other settings',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            for (final e in plain) _kv(e.key, e.value),
            if (controlled.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Controlled by this config',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  controlled.join(', '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "applyChannel5ghzHigh" -> "Channel 5 GHz high"
  static String _label(String key) {
    var s =
        key
            .replaceFirst(RegExp('^apply'), '')
            .replaceAllMapped(
              RegExp('2ghz', caseSensitive: false),
              (_) => ' 2.4 GHz ',
            )
            .replaceAllMapped(
              RegExp('5ghz', caseSensitive: false),
              (_) => ' 5 GHz ',
            )
            .replaceAllMapped(
              RegExp('([a-z])([A-Z])'),
              (m) => '${m[1]} ${m[2]}',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (s.isEmpty) return key;
    s =
        s[0].toUpperCase() +
        s
            .substring(1)
            .replaceAllMapped(
              RegExp(r' (\w)'),
              (m) => ' ${m[1]!.toLowerCase()}',
            );
    return s.replaceAll(RegExp('ghz', caseSensitive: false), 'GHz');
  }

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: AppShadows.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: AppColors.inkMuted,
    ),
  );
}
