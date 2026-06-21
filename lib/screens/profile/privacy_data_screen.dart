import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../theme/app_theme.dart';
import '../../providers/privacy_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/privacy_settings.dart';

class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Privasi & Data',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      body: Consumer2<PrivacyProvider, AuthProvider>(
        builder: (context, privacyProvider, authProvider, _) {
          if (privacyProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            );
          }

          final settings = privacyProvider.settings ?? PrivacySettingsModel.defaultSettings();
          final userProfile = authProvider.userProfile;
          final createdAt = userProfile?.createdAt ?? '';

          // Format registration date
          String registrationDate = 'Belum diketahui';
          if (createdAt.isNotEmpty) {
            try {
              final dt = DateTime.parse(createdAt);
              registrationDate =
                  '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
            } catch (_) {
              registrationDate = createdAt.substring(0, 10);
            }
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.privacy_tip_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Privasi & Kontrol Data',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('Kelola bagaimana data Anda digunakan',
                                style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Card
                _buildSectionTitle('Statistik Data Anda'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildStatChip(
                        label: 'Total Prediksi',
                        value: '${privacyProvider.riskPredictionsCount}',
                        icon: Icons.analytics_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 10),
                      _buildStatChip(
                        label: 'Data Sensor',
                        value: '${privacyProvider.sensorDataCount}',
                        icon: Icons.sensors_rounded,
                        color: const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 10),
                      _buildStatChip(
                        label: 'Terdaftar',
                        value: registrationDate,
                        icon: Icons.calendar_today_outlined,
                        color: const Color(0xFFEF4444),
                        isSmallValue: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Privacy Switches
                _buildSectionTitle('Pengaturan Privasi'),
                const SizedBox(height: 12),
                _buildSettingsCard([
                  _buildSwitch(
                    context: context,
                    icon: Icons.bar_chart_rounded,
                    iconColor: AppTheme.primaryBlue,
                    title: 'Bagikan Data untuk Analitik',
                    subtitle: 'Bantu kami tingkatkan kualitas layanan',
                    value: settings.shareAnalytics,
                    onChanged: (v) => privacyProvider.saveSettings(
                        settings.copyWith(shareAnalytics: v)),
                  ),
                  const Divider(height: 1, indent: 68, color: AppTheme.borderColor),
                  _buildSwitch(
                    context: context,
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Simpan Riwayat Kesehatan',
                    subtitle: 'Sensor data & prediksi akan direkam',
                    value: settings.storeHistory,
                    onChanged: (v) => privacyProvider.saveSettings(
                        settings.copyWith(storeHistory: v)),
                  ),
                ]),
                const SizedBox(height: 24),



                // Action Buttons
                _buildSectionTitle('Kelola Data Saya'),
                const SizedBox(height: 12),

                // Download Data Button
                _buildActionButton(
                  onTap: privacyProvider.isSavingData
                      ? null
                      : () => _downloadData(context, privacyProvider),
                  icon: Icons.download_rounded,
                  iconColor: AppTheme.primaryBlue,
                  bgColor: const Color(0xFFEEF3FF),
                  borderColor: AppTheme.primaryBlue.withOpacity(0.2),
                  title: 'Download Data Saya',
                  subtitle: 'Ekspor semua data Anda dalam format JSON',
                  isLoading: privacyProvider.isSavingData,
                ),
                const SizedBox(height: 12),

                // Delete History Button
                _buildActionButton(
                  onTap: privacyProvider.isSavingData
                      ? null
                      : () => _showDeleteConfirmation(context, privacyProvider),
                  icon: Icons.delete_sweep_rounded,
                  iconColor: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                  borderColor: const Color(0xFFEF4444).withOpacity(0.2),
                  title: 'Hapus Semua Riwayat',
                  subtitle: 'Hapus sensor data, prediksi & log aktivitas',
                  isLoading: false,
                ),
                const SizedBox(height: 24),

                // Info box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data yang dihapus tidak dapat dipulihkan kembali. Unduh data Anda terlebih dahulu sebelum menghapus riwayat.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF92400E),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _downloadData(
      BuildContext context, PrivacyProvider provider) async {
    await provider.downloadUserData();
    if (!context.mounted) return;
    final msg = provider.successMessage ?? provider.errorMessage;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: provider.successMessage != null
              ? AppTheme.accentGreen
              : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
      provider.clearMessages();
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, PrivacyProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Hapus Semua Riwayat',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Text(
          'Tindakan ini akan menghapus secara permanen:\n\n• Data sensor IoT\n• Riwayat prediksi risiko\n• Log aktivitas\n\nApakah Anda yakin?',
          style:
              GoogleFonts.inter(color: AppTheme.textGrey, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.inter(
                    color: AppTheme.textGrey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Hapus',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await provider.clearAllHistory();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Semua riwayat berhasil dihapus.'
                : (provider.errorMessage ?? 'Gagal menghapus riwayat.'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor:
              success ? AppTheme.accentGreen : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      provider.clearMessages();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textLight,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitch({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textGrey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryBlue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isSmallValue = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: isSmallValue ? 11 : 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildActionButton({
    required VoidCallback? onTap,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: iconColor),
                    )
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: iconColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.textGrey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: iconColor.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

