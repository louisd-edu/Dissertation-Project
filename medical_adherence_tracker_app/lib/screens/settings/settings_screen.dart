import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'info_medication_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final profile = state.profile;
        return Scaffold(
          backgroundColor: AppTheme.surface,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Settings',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),

                  // Profile card
                  _ProfileCard(
                    name: profile?.fullName ?? 'User',
                    role: profile?.role ?? ProfileRole.patient,
                    avatarUrl: profile?.avatarUrl,
                  ),
                  const SizedBox(height: 16),

                  // Medical Contact
                  _SectionCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.local_hospital_outlined,
                        iconColor: AppTheme.missedRed,
                        title: 'Medical Contact',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section General
                  _SectionCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.palette_outlined,
                        iconColor: AppTheme.primary,
                        title: 'Appearance',
                        onTap: () {},
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        iconColor: const Color(0xFFFF9500),
                        title: 'Notifications',
                        onTap: () async {
                          final scheduled = await NotificationService.instance
                              .scheduleTestNotification();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                scheduled
                                    ? 'Test notification sent now and another is scheduled in 10 seconds.'
                                    : 'Notifications are disabled. Please allow notification permission in system settings.',
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _SettingsTile(
                        icon: Icons.language_outlined,
                        iconColor: const Color(0xFF34C759),
                        title: 'Language',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  //Section Support
                  _SectionCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.medication_outlined,
                        iconColor: AppTheme.textSecondary,
                        title: 'Medication Overview',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const InfoMedicationScreen()),
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _SettingsTile(
                        icon: Icons.help_outline_rounded,
                        iconColor: AppTheme.textSecondary,
                        title: 'FAQ',
                        onTap: () {},
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _SettingsTile(
                        icon: Icons.mail_outline_rounded,
                        iconColor: AppTheme.textSecondary,
                        title: 'Contact',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sign out
                  _SectionCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        iconColor: AppTheme.missedRed,
                        title: 'Sign Out',
                        titleColor: AppTheme.missedRed,
                        onTap: () async {
                          await SupabaseService().signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (_) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final ProfileRole role;
  final String? avatarUrl;

  const _ProfileCard({
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withOpacity(0.15),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  role.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: titleColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: AppTheme.textLight, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      visualDensity: VisualDensity.compact,
    );
  }
}
