import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/support_provider.dart';
import '../../providers/auth_provider.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _appVersion = '1.0.0';
  String _buildNumber = '1';

  static const String _supportEmail = 'support@diacare.ai';
  static const String _whatsappNumber = '+6281234567890';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {}
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Tanya / Laporan DiaCare AI',
      }),
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw 'Cannot launch mailto';
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: _supportEmail));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email: $_supportEmail (disalin ke clipboard)',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp() async {
    final cleanNumber = _whatsappNumber.replaceAll(RegExp(r'[^\d]'), '');
    final Uri whatsappUri = Uri.parse(
        'https://wa.me/$cleanNumber?text=${Uri.encodeComponent("Halo tim support DiaCare AI, saya membutuhkan bantuan...")}');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Cannot launch wa.me';
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _whatsappNumber));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'WhatsApp: $_whatsappNumber (disalin ke clipboard)',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF25D366),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    final success = await context.read<SupportProvider>().submitTicket(
          userId: uid,
          subject: _subjectController.text,
          message: _messageController.text,
        );

    if (!mounted) return;
    final provider = context.read<SupportProvider>();
    if (success) {
      _subjectController.clear();
      _messageController.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.successMessage ?? provider.errorMessage ?? '',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor:
            success ? AppTheme.accentGreen : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
    provider.clearMessages();
  }

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
          'Bantuan & Dukungan',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), AppTheme.primaryBlue],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.25),
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
                    child: const Icon(Icons.support_agent_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pusat Bantuan DiaCare AI',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Kami siap membantu 24/7',
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

            // Contact Buttons
            _buildSectionTitle('Hubungi Kami'),
            const SizedBox(height: 12),
            _buildContactCard(
              onTap: _sendEmail,
              icon: Icons.alternate_email_rounded,
              title: 'Email Support',
              subtitle: _supportEmail,
              gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              iconColor: const Color(0xFF1D4ED8),
              actionBgColor: const Color(0xFFEFF6FF),
            ),
            _buildContactCard(
              onTap: _openWhatsApp,
              icon: Icons.chat_bubble_outline_rounded,
              title: 'WhatsApp Support',
              subtitle: _whatsappNumber,
              gradientColors: const [Color(0xFF10B981), Color(0xFF047857)],
              iconColor: const Color(0xFF047857),
              actionBgColor: const Color(0xFFECFDF5),
            ),
            const SizedBox(height: 16),

            // FAQ
            _buildSectionTitle('Pertanyaan yang Sering Diajukan'),
            const SizedBox(height: 12),
            Container(
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
                child: Column(
                  children: _faqs.map((faq) => _buildFaqTile(faq)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Report Form
            _buildSectionTitle('Laporkan Masalah'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Consumer<SupportProvider>(
                builder: (context, provider, _) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bug_report_rounded,
                                  color: Color(0xFFEF4444), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text('Laporkan Masalah',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textDark)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Subject Field
                        Text('SUBJEK', style: _labelStyle()),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _subjectController,
                          decoration: InputDecoration(
                            hintText: 'Contoh: Aplikasi crash saat login',
                            prefixIcon: const Icon(Icons.title_rounded,
                                color: AppTheme.primaryBlue, size: 20),
                            fillColor: const Color(0xFFF8FAFC),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppTheme.primaryBlue, width: 2),
                            ),
                          ),
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w500),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Subjek tidak boleh kosong'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Message Field
                        Text('PESAN', style: _labelStyle()),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _messageController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText:
                                'Jelaskan masalah yang Anda temui secara detail...',
                            fillColor: const Color(0xFFF8FAFC),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppTheme.primaryBlue, width: 2),
                            ),
                            alignLabelWithHint: true,
                          ),
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w500),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Pesan tidak boleh kosong'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                provider.isLoading ? null : _submitTicket,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: provider.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Kirim Laporan',
                                          style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // About App
            _buildSectionTitle('Tentang Aplikasi'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                children: [
                  // App logo area
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Image.asset(
                      'assets/images/Logo/Logo1.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFEF4444),
                          size: 64,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Smart Diabetes Care & Monitoring',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppTheme.textGrey)),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.borderColor),
                  const SizedBox(height: 16),
                  _buildAppInfoRow('Versi Aplikasi', 'v$_appVersion'),
                  const SizedBox(height: 8),
                  _buildAppInfoRow('Build Number', _buildNumber),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '© 2026 DiaCare AI. All rights reserved.\nAplikasi ini menggunakan teknologi AI untuk mendukung pemantauan kesehatan diabetes secara personal dan berkelanjutan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textGrey,
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
      ),
    );
  }

  TextStyle _labelStyle() => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppTheme.textLight,
        letterSpacing: 0.8,
      );

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

  Widget _buildContactCard({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required Color iconColor,
    required Color actionBgColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.last.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: iconColor,
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaqTile(Map<String, String> faq) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.only(left: 56, right: 16, bottom: 14),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.question_mark_rounded,
              color: AppTheme.primaryBlue, size: 16),
        ),
        title: Text(
          faq['q']!,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        iconColor: AppTheme.primaryBlue,
        collapsedIconColor: AppTheme.textGrey,
        children: [
          Text(
            faq['a']!,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textGrey,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textGrey,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'Bagaimana cara cek risiko diabetes di DiaCare AI?',
      'a':
          'Buka Dashboard, tap tombol "Cek Risiko AI" atau kartu "Analisis Risiko AI". Isi formulir dengan data biologis Anda (usia, BMI, HbA1c, kadar glukosa), lalu tekan "Mulai Analisis AI".',
    },
    {
      'q': 'Apakah data kesehatan saya aman?',
      'a':
          'Ya. Semua data dienkripsi dan disimpan di Google Firebase dengan keamanan standar industri. Anda dapat mengontrol pembagian data melalui menu Privasi & Data.',
    },
    {
      'q': 'Apa perbedaan sensor IoT dan catatan manual?',
      'a':
          'Sensor IoT membaca data real-time dari perangkat (glukosa, suhu, kelembaban) yang terhubung. Catatan manual memungkinkan Anda memasukkan riwayat kesehatan seperti tekanan darah, berat badan, dan lainnya secara mandiri.',
    },
    {
      'q': 'Bagaimana cara mengunduh data saya?',
      'a':
          'Buka Profil → Privasi & Data → tap "Download Data Saya". Data akan diekspor dalam format JSON yang berisi profil, riwayat sensor, prediksi risiko, dan log aktivitas.',
    },
    {
      'q': 'Apakah prediksi AI DiaCare akurat?',
      'a':
          'Prediksi DiaCare AI menggunakan algoritma heuristik berbasis faktor risiko medis yang telah terbukti. Namun, hasil prediksi bukan pengganti diagnosis dokter. Selalu konsultasikan hasil dengan tenaga medis profesional.',
    },
    {
      'q': 'Bagaimana cara mengatur ulang notifikasi?',
      'a':
          'Buka Profil → Notifikasi. Anda dapat mengaktifkan/menonaktifkan setiap jenis notifikasi dan mengubah jam reminder sesuai kebutuhan Anda.',
    },
  ];
}
