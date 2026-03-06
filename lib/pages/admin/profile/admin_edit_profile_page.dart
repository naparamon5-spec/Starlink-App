import 'package:flutter/material.dart';

// ── Design Tokens ─────────────────────────────────────────
const _primary = Color(0xFF0F62FE);
const _success = Color(0xFF24A148);
const _ink = Color(0xFF161616);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class AdminEditProfilePage extends StatefulWidget {
  const AdminEditProfilePage({super.key});

  @override
  State<AdminEditProfilePage> createState() => _AdminEditProfilePageState();
}

class _AdminEditProfilePageState extends State<AdminEditProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animController;

  final _nameController = TextEditingController(text: "Michael Scott");
  final _emailController = TextEditingController(text: "michael@company.com");
  final _phoneController = TextEditingController(text: "+1 555-0100");
  final _titleController = TextEditingController(text: "System Administrator");

  bool _notificationsEnabled = true;
  bool _twoFactorEnabled = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _success,
          content: Text("Profile updated successfully"),
        ),
      );

      Navigator.pop(context);
    }
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Change Password",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _DialogField(label: "Current Password", hint: "Enter password"),
              SizedBox(height: 12),
              _DialogField(label: "New Password", hint: "Enter new password"),
              SizedBox(height: 12),
              _DialogField(
                label: "Confirm Password",
                hint: "Confirm new password",
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _inkSecondary,
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: _inkTertiary),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(.03),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _heroBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F62FE), Color(0xFF0043CE)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: const [
          Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
          SizedBox(width: 10),
          Text(
            "Admin Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _primary.withOpacity(.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                "MS",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, size: 18, color: _primary),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _heroBanner()),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _animController.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _animController.value)),
                      child: child,
                    ),
                  );
                },
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _avatar(),

                      const SizedBox(height: 30),

                      _sectionTitle("PERSONAL INFORMATION"),

                      _card(
                        child: Column(
                          children: [
                            _inputField(
                              _nameController,
                              "Full Name",
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _inputField(
                              _emailController,
                              "Email Address",
                              Icons.email_outlined,
                            ),
                            const SizedBox(height: 12),
                            _inputField(
                              _phoneController,
                              "Phone",
                              Icons.phone_outlined,
                            ),
                            const SizedBox(height: 12),
                            _inputField(
                              _titleController,
                              "Job Title",
                              Icons.work_outline,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _sectionTitle("SECURITY"),

                      _card(
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: _twoFactorEnabled,
                              activeColor: _primary,
                              title: const Text("Two-Factor Authentication"),
                              subtitle: const Text(
                                "Add extra security to your account",
                              ),
                              onChanged:
                                  (v) => setState(() => _twoFactorEnabled = v),
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.lock_outline),
                              title: const Text("Change Password"),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _changePassword,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _sectionTitle("PREFERENCES"),

                      _card(
                        child: SwitchListTile(
                          value: _notificationsEnabled,
                          activeColor: _primary,
                          title: const Text("Email Notifications"),
                          subtitle: const Text("Receive updates via email"),
                          onChanged:
                              (v) => setState(() => _notificationsEnabled = v),
                        ),
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Save Changes",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final String hint;

  const _DialogField({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _inkSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: TextField(
            obscureText: true,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
