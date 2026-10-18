import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../notifications/notifications_screen.dart';
import '../support/help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.onLogout});
  final ApiClient api;
  final VoidCallback onLogout;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  String _addressLine(Object? address) {
    if (address is String) return address;
    if (address is! Map) return '';

    return (address['addressLine'] ?? address['address_line'])?.toString() ??
        '';
  }

  String _addressText(Object? address) {
    if (address is String) return address;
    if (address is! Map) return '';

    return [
      address['addressLine'] ?? address['address_line'],
      address['city'],
      address['state'],
      address['pincode'],
    ]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .map((part) => part.toString().trim())
        .join(', ');
  }

  @override
  void initState() {
    super.initState();
    _future = widget.api.getProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _startEdit(Map<String, dynamic> p) {
    _nameCtrl.text = p['name']?.toString() ?? '';
    _phoneCtrl.text = (p['phone'] ?? p['mobile'])?.toString() ?? '';
    // Clear "Not provided" placeholder so user sees empty field
    final addr = _addressLine(p['address']);
    _addressCtrl.text = (addr == 'Not provided' || addr == 'not provided') ? '' : addr;
    setState(() => _editing = true);
  }

  Future<void> _pickProfilePhoto(Map<String, dynamic> p) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.navyLight,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Update Profile Photo',
              style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.gold)),
            title: const Text('Take Photo',
                style: TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppColors.info)),
            title: const Text('Choose from Gallery',
                style: TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (p['profilePhotoPath'] != null &&
              (p['profilePhotoPath'] as String).isNotEmpty)
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.danger)),
              title: const Text('Remove Photo',
                  style: TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, null),
            ),
        ]),
      ),
    );
    if (source == null && p['profilePhotoPath'] != null) {
      // Remove photo
      await widget.api.updateProfile({'profilePhotoPath': null});
      if (mounted) setState(() => _future = widget.api.getProfile());
      return;
    }
    if (source == null) return;
    final img = await picker.pickImage(source: source, imageQuality: 80);
    if (img == null || !mounted) return;
    await widget.api.updateProfile({'profilePhotoPath': img.path});
    if (mounted) setState(() => _future = widget.api.getProfile());
  }

  Future<void> _saveEdit() async {
    setState(() => _saving = true);
    try {
      await widget.api.updateProfile({
        'name': _nameCtrl.text.trim(),
        'mobile': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      });
      if (mounted) {
        setState(() {
          _editing = false;
          _future = widget.api.getProfile();
        });
      }
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyDark,
        title: const Text('Sign out', style: TextStyle(color: AppColors.white)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.logout();
      widget.onLogout(); // main.dart _logout() → popUntil + setState
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.navyDeep,
        appBar: AppBar(
          backgroundColor: AppColors.navyDark,
          title: const Text('My Account',
              style: TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios_rounded, color: AppColors.gold),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snap.hasError) {
              final errMsg = snap.error.toString();
              final isAuthError = errMsg.toLowerCase().contains('authentication') ||
                  errMsg.toLowerCase().contains('unauthorized') ||
                  errMsg.toLowerCase().contains('401');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isAuthError
                            ? AppColors.warning.withValues(alpha: .1)
                            : AppColors.danger.withValues(alpha: .1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isAuthError ? AppColors.warning : AppColors.danger,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isAuthError ? Icons.lock_outline_rounded : Icons.error_outline_rounded,
                        color: isAuthError ? AppColors.warning : AppColors.danger,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isAuthError ? 'Session Expired' : 'Could Not Load Profile',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAuthError
                          ? 'Your session has expired. Please sign in again to continue.'
                          : 'Unable to load your profile. Please try again.',
                      style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (isAuthError)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await widget.api.logout();
                            widget.onLogout();
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Sign In Again'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _future = widget.api.getProfile()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                        ),
                      ),
                  ]),
                ),
              );
            }
            final p = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // ── Avatar + Name ────────────────────────────────────────────
                Center(
                    child: Column(children: [
                  GestureDetector(
                    onTap: () => _pickProfilePhoto(p),
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold.withValues(alpha: .15),
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: .5),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.gold.withValues(alpha: .2),
                                  blurRadius: 16)
                            ],
                          ),
                          child: ClipOval(
                            child: p['profilePhotoPath'] != null &&
                                    (p['profilePhotoPath'] as String).isNotEmpty
                                ? Image.file(File(p['profilePhotoPath']),
                                    fit: BoxFit.cover, width: 88, height: 88)
                                : Center(
                                    child: Text(
                                    (p['name'] as String? ?? 'C')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.gold),
                                  )),
                          ),
                        ),
                        // Camera icon overlay
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 14, color: AppColors.navyDeep),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(p['name']?.toString() ?? 'Customer',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white)),
                  const SizedBox(height: 4),
                  Text(p['email']?.toString() ?? '',
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Member since ${p['memberSince'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ])),
                const SizedBox(height: 20),

                // ── Stats ────────────────────────────────────────────────────
                Row(children: [
                  _StatCard('${p['totalOrders'] ?? 0}', 'Orders',
                      Icons.shopping_bag_outlined, AppColors.gold),
                  const SizedBox(width: 12),
                  _StatCard('${p['totalServices'] ?? 0}', 'Services',
                      Icons.build_outlined, AppColors.info),
                ]),
                const SizedBox(height: 20),

                // ── Personal Info ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.navyDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.navyLight),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('Personal Information',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white)),
                          const Spacer(),
                          if (!_editing)
                            GestureDetector(
                              onTap: () => _startEdit(p),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          AppColors.gold.withValues(alpha: .3)),
                                ),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          size: 14, color: AppColors.gold),
                                      SizedBox(width: 4),
                                      Text('Edit',
                                          style: TextStyle(
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12)),
                                    ]),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 14),
                        if (_editing) ...[
                          TextField(
                            controller: _nameCtrl,
                            style: const TextStyle(color: AppColors.white),
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: AppColors.white),
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _addressCtrl,
                            maxLines: 2,
                            style: const TextStyle(color: AppColors.white),
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              hintText: 'Enter your full address',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                                child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _editing = false),
                                    child: const Text('Cancel'))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: LoadingButton(
                                    loading: _saving,
                                    onPressed: _saveEdit,
                                    child: const Text('Save'))),
                          ]),
                        ] else ...[
                          _InfoRow(
                              Icons.phone_outlined,
                              'Phone',
                              (p['phone'] ?? p['mobile'])?.toString() ??
                                  'Not set'),
                          const SizedBox(height: 10),
                          if (p['emergencyContact'] != null &&
                              p['emergencyContact'].toString().isNotEmpty) ...[
                            _InfoRow(
                                Icons.emergency_outlined,
                                'Emergency Contact',
                                p['emergencyContact'].toString()),
                            const SizedBox(height: 10),
                          ],
                          _InfoRow(
                              Icons.location_on_outlined,
                              'Address',
                              _addressText(p['address']).isEmpty ||
                                      _addressText(p['address'])
                                          .toLowerCase()
                                          .contains('not provided')
                                  ? 'Not set — tap Edit to add'
                                  : _addressText(p['address'])),
                        ],
                      ]),
                ),
                const SizedBox(height: 14),

                // ── Menu options ──────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.navyDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.navyLight),
                  ),
                  child: Column(children: [
                    // Notifications
                    _MenuTile(
                      icon: Icons.notifications_outlined,
                      iconColor: AppColors.gold,
                      title: 'Notifications',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NotificationsScreen(api: widget.api),
                          )),
                    ),
                    const Divider(height: 0, color: AppColors.navyLight),

                    // Help & Support
                    _MenuTile(
                      icon: Icons.help_outline_rounded,
                      iconColor: AppColors.info,
                      title: 'Help & Support',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen(),
                          )),
                    ),
                    const Divider(height: 0, color: AppColors.navyLight),

                    // About SignFix
                    _MenuTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.success,
                      title: 'About SignFix',
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppColors.navyDark,
                          title: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset('assets/images/logo.jpeg',
                                  width: 32, height: 32, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 10),
                            RichText(
                                text: const TextSpan(children: [
                              TextSpan(
                                  text: 'Sign',
                                  style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              TextSpan(
                                  text: 'Fix',
                                  style: TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                            ])),
                          ]),
                          content: const Text(
                            'Version 1.0.0\n\nSign Board Sales, Service & Maintenance Management Platform.\n\nREPAIR  •  MANUFACTURE  •  INSTALL\n\nDeveloped by DL SSR INFOTECH',
                            style: TextStyle(
                                color: AppColors.textLight, height: 1.5),
                          ),
                          actions: [
                            FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Sign out ──────────────────────────────────────────────────
                GestureDetector(
                  onTap: _confirmLogout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: .4)),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: AppColors.danger, size: 20),
                          SizedBox(width: 8),
                          Text('Sign Out',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              )),
                        ]),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      );
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard(this.value, this.label, this.icon, this.color);
  final String value, label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navyDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
          ]),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white)),
              ])),
        ],
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.onTap});
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14))),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textMuted),
          ]),
        ),
      );
}
