import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';

/// Shared building blocks styled after the web portal (components/ui):
/// Select, horizontally scrolling chip rows with fading edges, section
/// labels and cards.

// ─── Select ──────────────────────────────────────────────────────────────────

class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.subtitle, this.icon});
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// Web-style select: a bordered box with the chosen label and a chevron.
/// Tapping opens a bottom sheet (with search when the list is long) instead
/// of Material's floating menu, which is cramped on phones.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint = 'Select…',
    this.dense = false,
    this.enabled = true,
    this.sheetTitle,
  });

  final List<SelectOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String hint;
  final bool dense;
  final bool enabled;
  final String? sheetTitle;

  SelectOption<T>? get _selected {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<SelectOption<T>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => _SelectSheet<T>(
            title: sheetTitle ?? label ?? hint,
            options: options,
            selected: value,
          ),
    );
    if (picked != null) onChanged?.call(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    final active = enabled && onChanged != null;
    final box = Material(
      color: active ? AppColors.paper : AppColors.paperSubtle,
      borderRadius: BorderRadius.circular(AppRadius.md + 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        onTap: active ? () => _open(context) : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 9 : 13,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            border: Border.all(color: AppColors.line, width: 1.5),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final bounded = c.hasBoundedWidth;
              return Row(
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (sel?.icon != null) ...[
                    Icon(sel!.icon, size: 18, color: AppColors.navy),
                    const SizedBox(width: 8),
                  ],
                  // Fills the width when it has one; sizes to its text when
                  // placed in an unbounded row (e.g. next to other controls).
                  if (bounded)
                    Expanded(
                      child: Text(
                        sel?.label ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: dense ? 13 : 14,
                          fontWeight:
                              sel == null ? FontWeight.w400 : FontWeight.w500,
                          color:
                              sel == null ? AppColors.inkFaint : AppColors.ink,
                        ),
                      ),
                    )
                  else
                    Text(
                      sel?.label ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: dense ? 13 : 14,
                        fontWeight:
                            sel == null ? FontWeight.w400 : FontWeight.w500,
                        color: sel == null ? AppColors.inkFaint : AppColors.ink,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: active ? AppColors.inkMuted : AppColors.lineStrong,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (label == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [FieldLabel(label!), const SizedBox(height: 6), box],
    );
  }
}

class _SelectSheet<T> extends StatefulWidget {
  const _SelectSheet({
    required this.title,
    required this.options,
    required this.selected,
  });
  final String title;
  final List<SelectOption<T>> options;
  final T? selected;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final searchable = widget.options.length > 8;
    final q = _q.trim().toLowerCase();
    final shown =
        q.isEmpty
            ? widget.options
            : widget.options
                .where(
                  (o) =>
                      o.label.toLowerCase().contains(q) ||
                      (o.subtitle ?? '').toLowerCase().contains(q),
                )
                .toList();
    final maxH = MediaQuery.of(context).size.height * 0.7;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            if (searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search…',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
            Flexible(
              child:
                  shown.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(color: AppColors.inkFaint),
                          ),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final o = shown[i];
                          final sel = o.value == widget.selected;
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            selected: sel,
                            selectedTileColor: AppColors.brand.withValues(
                              alpha: 0.06,
                            ),
                            leading:
                                o.icon == null
                                    ? null
                                    : Icon(
                                      o.icon,
                                      size: 20,
                                      color:
                                          sel
                                              ? AppColors.brand
                                              : AppColors.inkMuted,
                                    ),
                            title: Text(
                              o.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? AppColors.brand : AppColors.ink,
                              ),
                            ),
                            subtitle:
                                o.subtitle == null
                                    ? null
                                    : Text(
                                      o.subtitle!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                            trailing:
                                sel
                                    ? const Icon(
                                      Icons.check_rounded,
                                      color: AppColors.brand,
                                      size: 20,
                                    )
                                    : null,
                            onTap: () => Navigator.pop(context, o),
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

// ─── Horizontal scrolling with fading edges ──────────────────────────────────

/// Fades the left/right edge of any horizontal scrollable [child] while
/// there is more content that way, so people can tell the row continues.
class EdgeFade extends StatefulWidget {
  const EdgeFade({super.key, required this.child, this.fadeWidth = 24});
  final Widget child;
  final double fadeWidth;

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> {
  bool _left = false;
  bool _right = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitial());
  }

  /// Scroll notifications only arrive once something scrolls, so read the
  /// first layout's metrics from the scrollable below.
  void _checkInitial() {
    if (!mounted) return;
    ScrollableState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is ScrollableState) {
        found = e.state as ScrollableState;
        return;
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    final pos = found?.position;
    if (pos != null && pos.hasContentDimensions) {
      setState(() {
        _left = pos.pixels > pos.minScrollExtent + 1;
        _right = pos.pixels < pos.maxScrollExtent - 1;
      });
    }
  }

  bool _onMetrics(ScrollMetrics m) {
    if (m.axis != Axis.horizontal) return false;
    final l = m.pixels > m.minScrollExtent + 1;
    final r = m.pixels < m.maxScrollExtent - 1;
    if (l != _left || r != _right) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _left = l;
            _right = r;
          });
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final listened = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: widget.child,
      ),
    );
    if (!_left && !_right) return listened;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final f = (widget.fadeWidth / rect.width).clamp(0.0, 0.3);
        return LinearGradient(
          colors: [
            _left ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _right ? Colors.transparent : Colors.black,
          ],
          stops: [0, f, 1 - f, 1],
        ).createShader(rect);
      },
      child: listened,
    );
  }
}

/// Horizontal row that scrolls when it doesn't fit, with fading edges.
class FadingHScroll extends StatelessWidget {
  const FadingHScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Align(
    // When everything fits, on a wide screen, it starts at the left.
    alignment: Alignment.centerLeft,
    child: EdgeFade(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        child: child,
      ),
    ),
  );
}

// ─── Pill chips ──────────────────────────────────────────────────────────────

class PillOption<T> {
  const PillOption(this.value, this.label, {this.count, this.dotColor});
  final T value;
  final String label;
  final int? count;
  final Color? dotColor;
}

/// A row of single-choice pills (web Tabs/filters): navy when selected,
/// white with a border otherwise; counts in a small badge. Scrolls
/// sideways with fading edges when it doesn't fit.
class PillChips<T> extends StatelessWidget {
  const PillChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  final List<PillOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return FadingHScroll(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _Pill(
              option: options[i],
              selected: options[i].value == selected,
              onTap: () => onSelected(options[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill<T> extends StatelessWidget {
  const _Pill({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final PillOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.navy : AppColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? AppColors.navy : AppColors.line,
          width: 1.5,
        ),
        boxShadow:
            selected
                ? [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
                : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : option.dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Capped so a very long label can't run off the screen.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
                if (option.count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.paperMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${option.count}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill that toggles on/off (multi-select), same look as [PillChips].
class TogglePill extends StatelessWidget {
  const TogglePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _Pill<bool>(
    option: PillOption(true, label),
    selected: selected,
    onTap: () => onChanged(!selected),
  );
}

/// A small on/off switch with its label beside it; the label is tappable too.
class LabeledSwitch extends StatelessWidget {
  const LabeledSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 26,
            child: FittedBox(
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.brand,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Labels and cards ────────────────────────────────────────────────────────

/// Small uppercase label above a field (web Input/Select label).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: AppColors.inkSoft,
    ),
  );
}

/// Section heading with a red accent bar and an optional trailing action.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.navy,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

/// White rounded card with the portal's soft navy shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.lineSoft),
      boxShadow: AppShadows.sm,
    ),
    child: child,
  );
}

/// Pill with a status dot, like the web portal's status badges.
class DotBadge extends StatelessWidget {
  const DotBadge(this.label, {super.key, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Text with the search term marked.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    required this.style,
    this.maxLines,
  });
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    final at =
        query.isEmpty ? -1 : text.toLowerCase().indexOf(query.toLowerCase());
    if (at < 0) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: text.substring(at, at + query.length),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              backgroundColor: AppColors.warning.withValues(alpha: 0.25),
            ),
          ),
          TextSpan(text: text.substring(at + query.length)),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
