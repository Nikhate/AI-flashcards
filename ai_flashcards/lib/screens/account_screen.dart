import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() { _error = 'Please fill in all fields.'; _success = null; });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() { _error = 'Passwords do not match.'; _success = null; });
      return;
    }

    if (newPassword.length < 6) {
      setState(() { _error = 'Password must be at least 6 characters.'; _success = null; });
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });

    final error = await AuthService.changePassword(newPassword);

    setState(() {
      _loading = false;
      if (error != null) {
        _error = error;
      } else {
        _success = 'Password changed successfully!';
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    });
  }

  Future<void> _logout() async {
  await AuthService.logout();
  if (mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Text('← Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 14),
              const Text('My Account', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // User info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: AppColors.gradient,
                      ),
                      child: const Center(child: Text('👤', style: TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Logged in as', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      Text(user?.email ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                ),
                const SizedBox(height: 24),

                // Change password
                const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 12),

                TextField(
                  controller: _newPasswordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'New password',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted),
                    filled: true, fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _confirmPasswordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Confirm new password',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted),
                    filled: true, fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.dangerBorder)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),

                if (_success != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.successBorder)),
                    child: Text(_success!, style: const TextStyle(color: AppColors.success, fontSize: 13)),
                  ),

                GestureDetector(
                  onTap: _loading ? null : _changePassword,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: AppColors.gradient,
                    ),
                    child: Center(
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Update Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Logout
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.dangerBorder),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('🚪', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text('Log Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger)),
                    ]),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}