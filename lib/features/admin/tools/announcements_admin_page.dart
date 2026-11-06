import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// Announcements management (admins, agents) — the web portal's
/// Announcements page: list with status and author (GET /announcements),
/// create, edit (optionally show it again to everyone) and delete.
class AnnouncementsAdminPage extends StatefulWidget {
  const AnnouncementsAdminPage({super.key});

  @override
  State<AnnouncementsAdminPage> createState() => _AnnouncementsAdminPageState();
}

const _categories = {
  'feature': 'New feature',
  'improvement': 'Improvement',
  'maintenance': 'Maintenance',
  'notice': 'Notice',
};
const _audiences = {
  'all': 'Everyone',
  'staff': 'Staff (admins, agents, engineers, billers)',
  'customers': 'Customers and end users',
};

Color _statusColor(String s) => switch (s) {
  'live' => AppColors.success,
  'scheduled' => AppColors.info,
  _ => AppColors.inkFaint,
};

String _fmtDate(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? '' : DateFormat('MMM d, yyyy h:mm a').format(d.toLocal());
}

class _AnnouncementsAdminPageState extends State<AnnouncementsAdminPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    final res = await ApiService.getAnnouncements();
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _loading = false;
      if (res['status'] == 'success' && data is List) {
        _items =
            data
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
      } else {
        _error = res['message']?.toString() ?? 'Could not load announcements';
      }
    });
  }

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementEditorPage(existing: existing),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete announcement?'),
            content: Text('"${a['title']}" is removed for everyone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    final res = await ApiService.deleteAnnouncement(int.parse('${a['id']}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['status'] == 'success'
              ? 'Announcement deleted'
              : res['message']?.toString() ?? 'Could not delete',
        ),
      ),
    );
    if (res['status'] == 'success') _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('New'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child:
                    _items.isEmpty
                        ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'No announcements yet',
                                style: TextStyle(color: AppColors.inkFaint),
                              ),
                            ),
                          ],
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: _items.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _tile(_items[i]),
                        ),
              ),
    );
  }

  Widget _tile(Map<String, dynamic> a) {
    final status = '${a['status'] ?? 'live'}';
    final color = _statusColor(status);
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _openEditor(a),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _badge(status.toUpperCase(), color),
                        _badge(
                          (_categories[a['category']] ?? '${a['category']}')
                              .toUpperCase(),
                          AppColors.navy,
                        ),
                        if (a['pinned'] == true)
                          _badge('PINNED', AppColors.brand),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${a['title'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${a['body'] ?? ''}'
                          .replaceAll(RegExp(r'[*_`#>]+'), '')
                          .trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        _audiences[a['audience']]?.split(' (').first ??
                            '${a['audience']}',
                        if ('${a['author'] ?? ''}'.isNotEmpty)
                          'by ${a['author']}',
                        _fmtDate(a['created_at']),
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: AppColors.inkMuted,
                ),
                onSelected: (v) => v == 'edit' ? _openEditor(a) : _delete(a),
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: color,
      ),
    ),
  );
}

/// Create or edit an announcement.
class AnnouncementEditorPage extends StatefulWidget {
  const AnnouncementEditorPage({super.key, this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<AnnouncementEditorPage> createState() => _AnnouncementEditorPageState();
}

class _AnnouncementEditorPageState extends State<AnnouncementEditorPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _category;
  late String _audience;
  late bool _pinned;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _showAgain = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing ?? const {};
    _title = TextEditingController(text: '${a['title'] ?? ''}');
    _body = TextEditingController(text: '${a['body'] ?? ''}');
    _category =
        _categories.containsKey(a['category']) ? a['category'] : 'notice';
    _audience = _audiences.containsKey(a['audience']) ? a['audience'] : 'all';
    _pinned = a['pinned'] == true;
    _startsAt = DateTime.tryParse('${a['starts_at'] ?? ''}')?.toLocal();
    _endsAt = DateTime.tryParse('${a['ends_at'] ?? ''}')?.toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Show until must be after show from')),
      );
      return;
    }
    setState(() => _saving = true);
    final body = {
      'title': _title.text.trim(),
      'body': _body.text.trim(),
      'category': _category,
      'audience': _audience,
      'pinned': _pinned,
      'starts_at': _startsAt?.toUtc().toIso8601String(),
      'ends_at': _endsAt?.toUtc().toIso8601String(),
      if (_isEdit) 'showAgain': _showAgain,
    };
    final res =
        _isEdit
            ? await ApiService.updateAnnouncement(
              int.parse('${widget.existing!['id']}'),
              body,
            )
            : await ApiService.createAnnouncement(body);
    if (!mounted) return;
    setState(() => _saving = false);
    final ok = res['status'] == 'success';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (_isEdit ? 'Announcement updated' : 'Announcement published')
              : res['message']?.toString() ?? 'Could not save',
        ),
      ),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit announcement' : 'New announcement'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
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
                    : Text(_isEdit ? 'Save changes' : 'Publish'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Title'),
              validator:
                  (v) => (v ?? '').trim().isEmpty ? 'Enter a title.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _body,
              maxLength: 5000,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                helperText: 'Markdown is supported on the web portal.',
              ),
              validator:
                  (v) => (v ?? '').trim().isEmpty ? 'Enter a message.' : null,
            ),
            const SizedBox(height: 12),
            AppSelect<String>(
              value: _category,
              label: 'Type',
              options: [
                for (final e in _categories.entries)
                  SelectOption(e.key, e.value),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 14),
            AppSelect<String>(
              value: _audience,
              label: 'Who sees it',
              options: [
                for (final e in _audiences.entries)
                  SelectOption(e.key, e.value),
              ],
              onChanged: (v) => setState(() => _audience = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pin to the top'),
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
            ),
            _dateRow(
              'Show from',
              _startsAt,
              'Now',
              (d) => setState(() => _startsAt = d),
            ),
            _dateRow(
              'Show until',
              _endsAt,
              'No end',
              (d) => setState(() => _endsAt = d),
            ),
            if (_isEdit)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Show it again to everyone'),
                subtitle: const Text(
                  'People who already saw it get the pop-up again.',
                ),
                value: _showAgain,
                onChanged: (v) => setState(() => _showAgain = v ?? false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(
    String label,
    DateTime? value,
    String empty,
    ValueChanged<DateTime?> onSet,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        value == null ? empty : DateFormat('MMM d, yyyy h:mm a').format(value),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onSet(null),
            ),
          IconButton(
            icon: const Icon(Icons.event_outlined, size: 20),
            onPressed: () async {
              final d = await _pickDateTime(value);
              if (d != null) onSet(d);
            },
          ),
        ],
      ),
    );
  }
}
