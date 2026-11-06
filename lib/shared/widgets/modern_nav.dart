import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';

const _navPrimary = Color(0xFF133341);
const _navPrimaryLight = Color(0xFF1E4D62);
const _navPrimaryDark = Color(0xFF0C2029);
const _navSurface = Color(0xFFFFFFFF);

/// White, square-edged bottom bar shared by the home screens.
class ModernNavBar extends StatelessWidget {
  final List<Widget> children;

  const ModernNavBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: _navSurface,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: _navPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 10,
        bottom: bottomInset > 0 ? bottomInset : 12,
      ),
      child: SizedBox(
        height: 54,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

/// Nav tab with an animated pill behind the icon when selected.
class ModernNavItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ModernNavItem({
    super.key,
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? _navPrimary : const Color(0xFF94A3B8);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color:
                    selected
                        ? _navPrimary.withOpacity(0.10)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? (activeIcon ?? icon) : icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: 0.1,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raised gradient center button that turns into a close button when open.
class ModernCenterButton extends StatelessWidget {
  final bool open;
  final Widget child;
  final VoidCallback onTap;

  const ModernCenterButton({
    super.key,
    required this.open,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient:
                    open
                        ? null
                        : const LinearGradient(
                          colors: [_navPrimaryLight, _navPrimaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                color: open ? _navSurface : null,
                borderRadius: BorderRadius.circular(open ? 29 : 20),
                border: Border.all(
                  color: open ? _navPrimary : Colors.white,
                  width: open ? 2 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _navPrimary.withOpacity(open ? 0.15 : 0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder:
                    (c, a) => RotationTransition(
                      turns: Tween(begin: 0.75, end: 1.0).animate(a),
                      child: FadeTransition(opacity: a, child: c),
                    ),
                child:
                    open
                        ? const Icon(
                          Icons.close_rounded,
                          key: ValueKey('close'),
                          color: _navPrimary,
                          size: 26,
                        )
                        : KeyedSubtree(
                          key: const ValueKey('open'),
                          child: child,
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuickMenuItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  const QuickMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });
}

/// Blurred backdrop with a card of quick actions that slides up above the
/// bottom bar.
class ModernQuickMenu<T> extends StatefulWidget {
  final List<QuickMenuItem<T>> items;
  final T? active;
  final VoidCallback onDismiss;
  final ValueChanged<T> onSelect;

  const ModernQuickMenu({
    super.key,
    required this.items,
    required this.active,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  State<ModernQuickMenu<T>> createState() => _ModernQuickMenuState<T>();
}

class _ModernQuickMenuState<T> extends State<ModernQuickMenu<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navHeight = 64 + (bottomInset > 0 ? bottomInset : 12);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: AnimatedBuilder(
                animation: _controller,
                builder:
                    (_, __) => BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 6 * _controller.value,
                        sigmaY: 6 * _controller.value,
                      ),
                      child: Container(
                        color: _navPrimaryDark.withOpacity(
                          0.45 * _controller.value,
                        ),
                      ),
                    ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: navHeight + 28,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, child) {
                final t = Curves.easeOutCubic.transform(_controller.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 40 * (1 - t)),
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * t,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                );
              },
              child: _buildCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: _navSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _navPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          for (var i = 0; i < widget.items.length; i++)
            _buildTile(widget.items[i], i),
        ],
      ),
    );
  }

  Widget _buildTile(QuickMenuItem<T> item, int index) {
    final active = widget.active == item.value;
    final start = (index * 0.08).clamp(0.0, 0.5);
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        start,
        (start + 0.6).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      builder:
          (_, child) => Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - anim.value)),
              child: child,
            ),
          ),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onSelect(item.value),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  active
                      ? item.color.withOpacity(0.08)
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    active
                        ? item.color.withOpacity(0.45)
                        : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [item.color, item.color.withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  active
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: active ? item.color : const Color(0xFF94A3B8),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
