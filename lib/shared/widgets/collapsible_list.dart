import 'package:flutter/material.dart';

/// How many items a long list shows before "View all".
const collapsedPreviewCount = 3;

/// Newest first; only the latest [collapsedPreviewCount] unless [showAll].
List<T> visibleNewestFirst<T>(List<T> items, bool showAll) {
  final newestFirst = items.reversed.toList();
  if (showAll || newestFirst.length <= collapsedPreviewCount) {
    return newestFirst;
  }
  return newestFirst.sublist(0, collapsedPreviewCount);
}

/// How many of [total] items to show (from the top) unless [showAll].
int visibleCount(int total, bool showAll) =>
    showAll || total <= collapsedPreviewCount ? total : collapsedPreviewCount;

/// Fold / unfold icon button for a section header.
class CollapseArrow extends StatelessWidget {
  final bool collapsed;

  const CollapseArrow({super.key, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color:
              collapsed
                  ? const Color(0xFF133341)
                  : const Color(0xFF133341).withOpacity(0.07),
          shape: BoxShape.circle,
        ),
        child: Icon(
          collapsed ? Icons.add_rounded : Icons.remove_rounded,
          size: 17,
          color: collapsed ? Colors.white : const Color(0xFF133341),
        ),
      ),
    );
  }
}

/// "View all N …" / "Show less" toggle under a shortened list.
class ViewAllButton extends StatelessWidget {
  final int total;
  final bool showAll;
  final String noun;
  final VoidCallback onTap;

  const ViewAllButton({
    super.key,
    required this.total,
    required this.showAll,
    required this.noun,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= collapsedPreviewCount) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                showAll ? 'Show less' : 'View all $total $noun',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF133341),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                showAll
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: const Color(0xFF133341),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
