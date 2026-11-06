// Shared status label helpers.

/// Normalizes a subscription's `active` value ("Y", "1", true, "Active"...)
/// to ACTIVE / INACTIVE for badges.
String subscriptionStatusLabel(dynamic v) {
  final t = '${v ?? ''}'.trim().toLowerCase();
  if (t.isEmpty || t == 'null' || t == '—') return '—';
  if (const ['true', 'y', 'yes', '1', 'active'].contains(t)) return 'ACTIVE';
  if (const ['false', 'n', 'no', '0', 'inactive'].contains(t)) {
    return 'INACTIVE';
  }
  return t.toUpperCase();
}
