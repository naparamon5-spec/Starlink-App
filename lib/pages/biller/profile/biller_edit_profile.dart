import 'package:flutter/material.dart';

class BillerEditProfilePage extends StatefulWidget {
  const BillerEditProfilePage({super.key});

  @override
  State<BillerEditProfilePage> createState() => _BillerEditProfilePageState();
}

class _BillerEditProfilePageState extends State<BillerEditProfilePage> {
  final _businessNameCtrl = TextEditingController(
    text: 'Davis Utility Services',
  );
  final _ownerNameCtrl = TextEditingController(text: 'James Davis');
  final _emailCtrl = TextEditingController(text: 'billing@davisutil.com');
  final _phoneCtrl = TextEditingController(text: '+1 (555) 012-3456');
  final _addressCtrl = TextEditingController(text: '123 Main St, NY');
  final _descCtrl = TextEditingController(
    text: 'Providing utility billing and payment services.',
  );

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        title: const Text(
          'Edit Biller Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Avatar / Logo ───────────────────────────────
          Center(
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Form Card ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Column(
              children: [
                _Field(label: 'Business Name', controller: _businessNameCtrl),
                const SizedBox(height: 12),
                _Field(label: 'Owner Name', controller: _ownerNameCtrl),
                const SizedBox(height: 12),
                _Field(
                  label: 'Email',
                  controller: _emailCtrl,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Phone',
                  controller: _phoneCtrl,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _Field(label: 'Business Address', controller: _addressCtrl),
                const SizedBox(height: 12),
                _Field(
                  label: 'Description',
                  controller: _descCtrl,
                  maxLines: 3,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Save Button ────────────────────────────────
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Save Changes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Field ───────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboard;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1F2937),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
