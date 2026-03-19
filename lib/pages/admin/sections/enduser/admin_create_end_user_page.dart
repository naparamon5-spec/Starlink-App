import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';

class AdminCreateEndUserPage extends StatefulWidget {
  const AdminCreateEndUserPage({super.key});

  @override
  State<AdminCreateEndUserPage> createState() => _AdminCreateEndUserPageState();
}

class _AdminCreateEndUserPageState extends State<AdminCreateEndUserPage> {
  static const _primary = Color(0xFFEB1E23);
  static const _primaryDark = Color(0xFF760F12);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);
  static const _success = Color(0xFF24A148);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  List<Map<String, dynamic>> _agents = [];
  Map<String, dynamic>? _selectedAgent;
  bool _isLoadingAgents = false;
  bool _isSubmitting = false;
  String? _agentLoadError;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _isLoadingAgents = true;
      _agentLoadError = null;
    });
    try {
      final response = await ApiService.getCustomersListAll();
      if (!mounted) return;
      if (response['StatusCode'] == 200 || response['message'] == 'Success') {
        final raw = response['data'] as List<dynamic>? ?? [];
        final agents =
            raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .where(
                  (e) =>
                      (e['label'] as String? ?? '').trim().isNotEmpty &&
                      (e['value'] as String? ?? '').trim().isNotEmpty,
                )
                .toList();
        setState(() => _agents = agents);
      } else {
        setState(() => _agentLoadError = 'Failed to load agents.');
      }
    } catch (e) {
      if (mounted) setState(() => _agentLoadError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAgents = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedAgent == null) {
      _showSnack('Please select an agent.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'customer_code': (_selectedAgent!['value'] ?? '').toString(),
        'customer_name': (_selectedAgent!['label'] ?? '').toString(),
      };
      final response = await ApiService.createEndUser(payload);
      if (!mounted) return;
      final isSuccess =
          response['status'] == 'success' ||
          response['StatusCode'] == 200 ||
          (response['message']?.toString().toLowerCase().contains('success') ??
              false);
      if (isSuccess) {
        _showSnack('End user created successfully!', isError: false);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, true);
      } else {
        final msg =
            response['message']?.toString() ??
            response['Message']?.toString() ??
            'Failed to create end user.';
        _showSnack(msg, isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _primaryDark : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _label(String text, {bool req = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        if (req)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
      ],
    ),
  );

  InputDecoration _dec({String? hint, IconData? icon}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: _inkTertiary),
    prefixIcon: icon != null ? Icon(icon, size: 18, color: _inkTertiary) : null,
    filled: true,
    fillColor: _surfaceSubtle,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
    errorStyle: const TextStyle(fontSize: 11, color: _primary),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Create End User',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
              icon: Icons.person_outline_rounded,
              title: 'End User Information',
            ),
            const SizedBox(height: 16),

            _label('End User Name', req: true),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 13, color: _ink),
              textCapitalization: TextCapitalization.words,
              decoration: _dec(
                hint: 'Enter end user name',
                icon: Icons.badge_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'End user name is required';
                }
                if (v.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            _SectionHeader(
              icon: Icons.business_outlined,
              title: 'Agent / Customer',
            ),
            const SizedBox(height: 16),

            _label('Select Agent', req: true),

            if (_isLoadingAgents)
              _LoadingBox()
            else if (_agentLoadError != null)
              _ErrorBox(message: _agentLoadError!, onRetry: _loadAgents)
            else
              _AgentDropdown(
                agents: _agents,
                selected: _selectedAgent,
                onChanged: (a) => setState(() => _selectedAgent = a),
              ),

            const SizedBox(height: 32),

            _SubmitBtn(isSubmitting: _isSubmitting, onTap: _submit),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  static const _primary = Color(0xFFEB1E23);
  static const _ink = Color(0xFF000000);
  static const _border = Color(0xFFE0E0E0);

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: _primary),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: -0.2,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: _border, height: 1)),
    ],
  );
}

// ── Searchable agent dropdown ────────────────────────────────────────────────
class _AgentDropdown extends StatefulWidget {
  final List<Map<String, dynamic>> agents;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const _AgentDropdown({
    required this.agents,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_AgentDropdown> createState() => _AgentDropdownState();
}

class _AgentDropdownState extends State<_AgentDropdown> {
  static const _primary = Color(0xFFEB1E23);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  final _searchCtrl = TextEditingController();
  final _overlayCtrl = OverlayPortalController();
  final _layerLink = LayerLink();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.agents;
  }

  @override
  void didUpdateWidget(_AgentDropdown old) {
    super.didUpdateWidget(old);
    if (old.agents != widget.agents) _filtered = widget.agents;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered =
          q.trim().isEmpty
              ? widget.agents
              : widget.agents.where((a) {
                return (a['label'] as String? ?? '').toLowerCase().contains(
                      lower,
                    ) ||
                    (a['value'] as String? ?? '').toLowerCase().contains(lower);
              }).toList();
    });
  }

  void _pick(Map<String, dynamic> agent) {
    widget.onChanged(agent);
    _overlayCtrl.hide();
    _searchCtrl.clear();
    setState(() => _filtered = widget.agents);
  }

  void _toggle() {
    setState(() {
      _overlayCtrl.isShowing ? _overlayCtrl.hide() : _overlayCtrl.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.selected?['label'] as String?;
    final code = widget.selected?['value'] as String?;
    final open = _overlayCtrl.isShowing;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayCtrl,
        overlayChildBuilder:
            (_) => CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 54),
              child: Align(
                alignment: Alignment.topLeft,
                child: _Panel(
                  searchCtrl: _searchCtrl,
                  filtered: _filtered,
                  onSearch: _search,
                  onSelect: _pick,
                ),
              ),
            ),
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: _surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: open ? _primary : _border,
                width: open ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.business_outlined, size: 18, color: _inkTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      label != null
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Code: $code',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _inkSecondary,
                                ),
                              ),
                            ],
                          )
                          : const Text(
                            'Select an agent…',
                            style: TextStyle(fontSize: 13, color: _inkTertiary),
                          ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: _inkTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating panel ────────────────────────────────────────────────────────────
class _Panel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final List<Map<String, dynamic>> filtered;
  final ValueChanged<String> onSearch;
  final ValueChanged<Map<String, dynamic>> onSelect;

  static const _primary = Color(0xFFEB1E23);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _Panel({
    required this.searchCtrl,
    required this.filtered,
    required this.onSearch,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: MediaQuery.of(context).size.width - 40,
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearch,
                autofocus: true,
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: InputDecoration(
                  hintText: 'Search agents…',
                  hintStyle: const TextStyle(fontSize: 13, color: _inkTertiary),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: _inkTertiary,
                  ),
                  filled: true,
                  fillColor: _surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: _border),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No agents found',
                  style: TextStyle(fontSize: 13, color: _inkSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    final lbl = (a['label'] as String? ?? '').trim();
                    final val = (a['value'] as String? ?? '').trim();
                    final parts =
                        lbl
                            .split(RegExp(r'\s+'))
                            .where((p) => p.isNotEmpty)
                            .toList();
                    final ini =
                        parts.length >= 2
                            ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
                            : lbl.isNotEmpty
                            ? lbl[0].toUpperCase()
                            : '?';

                    return InkWell(
                      onTap: () => onSelect(a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  ini,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lbl,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _ink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    val,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Loading / Error / Submit helpers ─────────────────────────────────────────
class _LoadingBox extends StatelessWidget {
  static const _primary = Color(0xFFEB1E23);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);
  static const _inkTertiary = Color(0xFFA8A8A8);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    decoration: BoxDecoration(
      color: _surfaceSubtle,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text(
          'Loading agents…',
          style: TextStyle(fontSize: 13, color: _inkTertiary),
        ),
      ],
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  static const _primary = Color(0xFFEB1E23);

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _primary.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _primary.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 16, color: _primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: _primary),
          ),
        ),
        GestureDetector(
          onTap: onRetry,
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SubmitBtn extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onTap;
  static const _primary = Color(0xFFEB1E23);

  const _SubmitBtn({required this.isSubmitting, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isSubmitting ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: isSubmitting ? _primary.withOpacity(0.6) : _primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow:
            isSubmitting
                ? []
                : [
                  BoxShadow(
                    color: _primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Center(
        child:
            isSubmitting
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Create End User',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
      ),
    ),
  );
}
