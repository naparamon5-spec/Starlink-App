import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/account_detail_parts.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';
import 'package:url_launcher/url_launcher.dart';

/// Announcements (admins, agents): what's being shown (GET /announcements/feed)
/// and every announcement to manage (GET /announcements), including scheduled
/// and expired ones.
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
  'staff': 'Staff only',
  'customers': 'Customers & end users',
};

Color _categoryColor(dynamic c) => switch ('$c') {
  'feature' => AppColors.successInk,
  'improvement' => AppColors.info,
  'maintenance' => AppColors.warningInk,
  _ => AppColors.navy,
};

Color _statusColor(String s) => switch (s) {
  'live' => AppColors.successInk,
  'scheduled' => AppColors.info,
  _ => AppColors.inkMuted,
};

String _dateTime(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? '' : DateFormat('MMM dd, y, h:mm a').format(d.toLocal());
}

String announcementDate(Map<String, dynamic> a) {
  final d = DateTime.tryParse('${a['starts_at'] ?? a['created_at'] ?? ''}');
  return d == null ? '' : DateFormat('MMM dd, y').format(d.toLocal());
}

/// When an announcement shows, for the Manage tab.
String announcementRange(Map<String, dynamic> a) {
  final from = _dateTime(a['starts_at']);
  final until = _dateTime(a['ends_at']);
  return '${from.isEmpty ? 'Right away' : from} → '
      '${until.isEmpty ? 'no end date' : until}';
}

class _AnnouncementsAdminPageState extends State<AnnouncementsAdminPage> {
  bool _loading = true;
  String? _error;
  int _tab = 0;
  List<Map<String, dynamic>> _feed = const [];
  List<Map<String, dynamic>> _all = const [];

  @override
  void initState() {
    super.initState();
    _load(markRead: true);
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> res) {
    final data = res['data'];
    return data is List
        ? data
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : const [];
  }

  Future<void> _load({bool markRead = false}) async {
    setState(() {
      _loading = _all.isEmpty && _feed.isEmpty;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.getAnnouncementFeed(),
      ApiService.getAnnouncements(),
    ]);
    if (!mounted) return;
    final failed = results.firstWhere(
      (r) => r['status'] != 'success',
      orElse: () => const {},
    );
    setState(() {
      _loading = false;
      if (failed.isNotEmpty) {
        _error =
            failed['message']?.toString() ?? "Couldn't load announcements.";
      } else {
        _feed = _rows(results[0]);
        _all = _rows(results[1]);
      }
    });
    if (markRead) {
      // Seeing them here counts as seen; "New" stays until the next visit.
      final unread =
          [
            for (final a in _feed)
              if (a['read'] == false) int.tryParse('${a['id']}'),
          ].whereType<int>().toList();
      if (unread.isNotEmpty) ApiService.markAnnouncementsRead(unread);
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementEditorPage(existing: existing),
      ),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showAppConfirm(context, title: 'Delete this announcement?', message: '“${a['title']}” will disappear for everyone.', confirmLabel: 'Delete', icon: Icons.delete_outline_rounded, tone: AppDialogTone.danger);
    if (ok != true || !mounted) return;
    final res = await ApiService.deleteAnnouncement(int.parse('${a['id']}'));
    if (!mounted) return;
    AppToast.result(context, res['status'] == 'success'
              ? 'Announcement deleted'
              : res['message']?.toString() ?? "Couldn't delete it.", ok: res['status'] == 'success');
    if (res['status'] == 'success') _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('New announcement'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                  children: [
                    AccountTabs(
                      tabs: [
                        ('Announcements', _feed.length),
                        ('Manage', _all.length),
                      ],
                      selected: _tab,
                      onSelected: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 14),
                    if (_tab == 0) ..._buildFeed() else ..._buildManage(),
                  ],
                ),
              ),
    );
  }

  List<Widget> _buildFeed() {
    if (_feed.isEmpty) {
      return const [AccountEmptyCard('No announcements.')];
    }
    return [
      for (final a in _feed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnnouncementCard(announcement: a),
        ),
    ];
  }

  List<Widget> _buildManage() {
    if (_all.isEmpty) {
      return const [AccountEmptyCard('No announcements yet.')];
    }
    return [
      for (final a in _all)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ManageCard(
            announcement: a,
            onEdit: () => _openEditor(a),
            onDelete: () => _delete(a),
          ),
        ),
    ];
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: color,
      ),
    ),
  );
}

class _Pinned extends StatelessWidget {
  const _Pinned();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.push_pin_outlined, size: 13, color: AppColors.navy),
      SizedBox(width: 3),
      Text(
        'Pinned',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
    ],
  );
}

/// Plain text with its line breaks kept; web links can be tapped.
class _BodyText extends StatelessWidget {
  const _BodyText(this.text);
  final String text;

  static final _link = RegExp(r'https?://[^\s]+');
  static const _style = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _link.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(at, m.start)));
      final url = m.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap:
                () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
            child: Text(
              url,
              style: _style.copyWith(
                color: AppColors.brand,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.brand,
              ),
            ),
          ),
        ),
      );
      at = m.end;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(children: spans), style: _style);
  }
}

/// One announcement; [compact] clamps long messages for the dashboard.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.compact = false,
  });
  final Map<String, dynamic> announcement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final date = announcementDate(a);
    return AccountRowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tag(
                      _categories[a['category']] ?? 'Notice',
                      _categoryColor(a['category']),
                    ),
                    if (a['pinned'] == true) const _Pinned(),
                    if (a['read'] == false) const _Tag('New', AppColors.brand),
                  ],
                ),
              ),
              if (date.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${a['title'] ?? ''}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          if (compact)
            Text(
              '${a['body'] ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            )
          else
            _BodyText('${a['body'] ?? ''}'),
        ],
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final status = '${a['status'] ?? 'live'}';
    final author = accountText(a['author']);
    return AccountRowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DotBadge(status.toUpperCase(), color: _statusColor(status)),
              _Tag(
                _categories[a['category']] ?? 'Notice',
                _categoryColor(a['category']),
              ),
              Text(
                _audiences[a['audience']] ?? '${a['audience'] ?? ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
              if (a['pinned'] == true) const _Pinned(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${a['title'] ?? ''}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${a['body'] ?? ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${announcementRange(a)} · by ${author.isEmpty ? 'unknown' : author}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Create or edit an announcement, with a live preview.
class AnnouncementEditorPage extends StatefulWidget {
  const AnnouncementEditorPage({super.key, this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<AnnouncementEditorPage> createState() => _AnnouncementEditorPageState();
}

class _AnnouncementEditorPageState extends State<AnnouncementEditorPage> {
  static const _titleMax = 150;
  static const _bodyMax = 5000;

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
  String? _datesError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing ?? const {};
    _title = TextEditingController(text: '${a['title'] ?? ''}');
    _body = TextEditingController(text: '${a['body'] ?? ''}');
    _category =
        _categories.containsKey(a['category']) ? a['category'] : 'feature';
    _audience = _audiences.containsKey(a['audience']) ? a['audience'] : 'all';
    _pinned = a['pinned'] == true;
    _startsAt = DateTime.tryParse('${a['starts_at'] ?? ''}')?.toLocal();
    _endsAt = DateTime.tryParse('${a['ends_at'] ?? ''}')?.toLocal();
    // Keeps the preview and the character count current.
    _title.addListener(_refresh);
    _body.addListener(_refresh);
  }

  void _refresh() => setState(() {});

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
    final fieldsOk = _form.currentState!.validate();
    final datesBad =
        _startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!);
    setState(() {
      _datesError = datesBad ? 'Show until must be after show from' : null;
    });
    if (!fieldsOk || datesBad) return;
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
    if (res['status'] != 'success') {
      AppToast.error(
        context,
        res['message']?.toString() ?? "Couldn't save it.",
      );
      return;
    }
    AppToast.success(context, _isEdit ? 'Announcement updated' : 'Announcement published');
    Navigator.pop(context, true);
  }

  final _baseline = FormBaseline();
  bool get _hasChanges => _baseline.changed(
    ready: true,
    values: [
      _title.text,
      _body.text,
      _category,
      _audience,
      _pinned,
      _startsAt,
      _endsAt,
      _showAgain,
    ],
  );

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

  @override
  Widget build(BuildContext context) {
    final count = _body.text.trim().length;
    return UnsavedChangesGuard(
      isDirty: () => _hasChanges,
      listenTo: Listenable.merge([_title, _body]),
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit announcement' : 'New announcement'),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Title', required: true),
                    TextFormField(
                      controller: _title,
                      maxLength: _titleMax,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(counterText: ''),
                      validator:
                          (v) =>
                              (v ?? '').trim().isEmpty ? 'Enter a title' : null,
                    ),
                    const SizedBox(height: 14),
                    AppSelect<String>(
                      label: 'Type',
                      sheetTitle: 'Type',
                      value: _category,
                      options: [
                        for (final e in _categories.entries)
                          SelectOption(e.key, e.value),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 14),
                    AppSelect<String>(
                      label: 'Who sees it',
                      sheetTitle: 'Who sees it',
                      value: _audience,
                      options: [
                        for (final e in _audiences.entries)
                          SelectOption(e.key, e.value),
                      ],
                      onChanged: (v) => setState(() => _audience = v),
                    ),
                    const SizedBox(height: 14),
                    _label('Announcement', required: true),
                    TextFormField(
                      controller: _body,
                      maxLength: _bodyMax,
                      minLines: 6,
                      maxLines: 12,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(counterText: ''),
                      validator:
                          (v) =>
                              (v ?? '').trim().isEmpty
                                  ? 'Write the announcement'
                                  : null,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Plain text. Line breaks are kept and web links '
                      '(https://…) become clickable.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${NumberFormat('#,##0').format(count)} / '
                        '${NumberFormat('#,##0').format(_bodyMax)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _dateField(
                      'Show from',
                      _startsAt,
                      'Leave empty to show it right away.',
                      (d) => setState(() {
                        _startsAt = d;
                        _datesError = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    _dateField(
                      'Show until',
                      _endsAt,
                      'Leave empty to keep showing it.',
                      (d) => setState(() {
                        _endsAt = d;
                        _datesError = null;
                      }),
                    ),
                    if (_datesError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _datesError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.dangerInk,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    // A ListTile needs a Material of its own inside a card.
                    Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.brand,
                            title: const Text(
                              'Pin to the top',
                              style: TextStyle(fontSize: 13),
                            ),
                            value: _pinned,
                            onChanged:
                                (v) => setState(() => _pinned = v ?? false),
                          ),
                          if (_isEdit)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppColors.brand,
                              title: const Text(
                                'Show it again to people who already saw it',
                                style: TextStyle(fontSize: 13),
                              ),
                              value: _showAgain,
                              onChanged:
                                  (v) =>
                                      setState(() => _showAgain = v ?? false),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 6),
              AnnouncementCard(
                announcement: {
                  'title':
                      _title.text.trim().isEmpty ? 'Title' : _title.text.trim(),
                  'body':
                      _body.text.trim().isEmpty
                          ? 'Your announcement appears here.'
                          : _body.text.trim(),
                  'category': _category,
                  'pinned': _pinned,
                  'starts_at': _startsAt?.toIso8601String(),
                  'created_at': DateTime.now().toIso8601String(),
                },
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    String hint,
    ValueChanged<DateTime?> onSet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Material(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            onTap: () async {
              final d = await _pickDateTime(value);
              if (d != null) onSet(d);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
                border: Border.all(color: AppColors.line, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value == null
                          ? 'Select date and time'
                          : DateFormat('MMM dd, y, h:mm a').format(value),
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            value == null ? AppColors.inkFaint : AppColors.ink,
                      ),
                    ),
                  ),
                  if (value != null)
                    IconButton(
                      tooltip: 'Clear $label',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onSet(null),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.inkFaint,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.event_outlined,
                        size: 20,
                        color: AppColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
        ),
      ],
    );
  }
}
