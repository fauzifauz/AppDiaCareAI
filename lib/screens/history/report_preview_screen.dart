import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/health_report_service.dart';
import '../../theme/app_theme.dart';

class ReportPreviewScreen extends StatefulWidget {
  final String name;
  final String riskLevel;
  final double riskPercentage;
  final double metabolicScore;
  final String averageGlucose;
  final String averageSteps;
  final int warningCount;
  final List<Map<String, String>> historyEntries;
  final String avatarUrl;
  final XFile? pickedImage;

  const ReportPreviewScreen({
    super.key,
    this.name = 'Alex',
    this.riskLevel = 'Risiko Rendah',
    this.riskPercentage = 12.0,
    this.metabolicScore = 88.0,
    this.averageGlucose = '104',
    this.averageSteps = '8,100',
    this.warningCount = 2,
    this.historyEntries = const [
      {
        'title': 'Glukosa Setelah Makan',
        'time': 'Hari ini, 13:15 WIB',
        'value': '148 mg/dL',
        'status': 'Tinggi',
      },
      {
        'title': 'Aktivitas Langkah Harian',
        'time': 'Hari ini, 10:00 WIB',
        'value': '9,420 langkah',
        'status': 'Target Tercapai',
      },
      {
        'title': 'Analisis Risiko Diabetes AI',
        'time': 'Kemarin, 16:30 WIB',
        'value': 'Tingkat Risiko: 12%',
        'status': 'Risiko Rendah',
      },
      {
        'title': 'Glukosa Sebelum Makan',
        'time': 'Kemarin, 08:00 WIB',
        'value': '94 mg/dL',
        'status': 'Normal',
      },
    ],
    this.avatarUrl = '',
    this.pickedImage,
  });

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  bool _isDownloading = false;

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final pdfBytes = await HealthReportService.generateReport(
        name: widget.name,
        riskLevel: widget.riskLevel,
        riskPercentage: widget.riskPercentage,
        metabolicScore: widget.metabolicScore,
        averageGlucose: widget.averageGlucose,
        averageSteps: widget.averageSteps,
        warningCount: widget.warningCount,
        historyEntries: widget.historyEntries,
      );

      final now = DateTime.now();
      final formattedDate = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final fileName = "DiaCareAI_Laporan_Kesehatan_$formattedDate.pdf";

      List<String> pathsToTry = [];

      // 1. Try public Download directories on Android
      if (!kIsWeb && Platform.isAndroid) {
        pathsToTry.addAll([
          '/storage/emulated/0/Download/$fileName',
          '/sdcard/Download/$fileName',
        ]);
      }

      // 2. Try external storage directories
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          pathsToTry.add('${extDir.path}/$fileName');
          pathsToTry.add('${extDir.path}/Download/$fileName');
        }
      } catch (_) {}

      // 3. Try app documents directory as fallback
      try {
        final docDir = await getApplicationDocumentsDirectory();
        pathsToTry.add('${docDir.path}/$fileName');
      } catch (_) {}

      File? savedFile;
      String? lastError;

      for (final path in pathsToTry) {
        try {
          final file = File(path);
          final parentDir = file.parent;
          if (!await parentDir.exists()) {
            await parentDir.create(recursive: true);
          }
          await file.writeAsBytes(pdfBytes);
          savedFile = file;
          break; // Successfully saved!
        } catch (e) {
          lastError = e.toString();
          debugPrint('Failed to save to $path: $e');
        }
      }

      // Fallback if local direct save completely failed but we still have pdfBytes
      if (savedFile == null) {
        debugPrint('Direct file saving failed: $lastError. Falling back to native system print/save dialog.');
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: fileName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Laporan PDF siap diunduh/dicetak dengan nama: $fileName'),
              backgroundColor: AppTheme.primaryBlue,
            ),
          );
        }
        return;
      }

      // Show beautiful success dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 28),
                const SizedBox(width: 10),
                Text('Unduh Berhasil', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan PDF telah berhasil diunduh dan disimpan langsung ke penyimpanan perangkat Anda:',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    savedFile!.path,
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Anda dapat membuka, membagikan, memindahkan, atau mencetak file laporan ini menggunakan aplikasi lain.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textGrey),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Tutup', style: GoogleFonts.inter(color: AppTheme.textGrey, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await Printing.sharePdf(
                    bytes: pdfBytes,
                    filename: fileName,
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                label: Text('Buka / Bagikan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 10),
                Text('Unduh Gagal', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Gagal mengunduh atau menyimpan laporan PDF: $e\n\nPastikan aplikasi memiliki izin penyimpanan yang memadai dan coba lagi.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic calculation of HbA1c based on glucose average
    final double glucoseVal = double.tryParse(widget.averageGlucose) ?? 104.0;
    final double hba1cEst = (glucoseVal + 46.7) / 28.7;
    final String hba1cText = hba1cEst.toStringAsFixed(1);

    // Dynamic color setup based on risk level
    Color riskColor;
    String riskTitle;
    String riskDesc;
    if (widget.riskPercentage >= 50.0) {
      riskColor = const Color(0xFFEF4444);
      riskTitle = 'Risiko Tinggi';
      riskDesc = 'Tingkat risiko diabetes Anda tinggi. Sangat disarankan untuk berkonsultasi dengan dokter Anda.';
    } else if (widget.riskPercentage >= 20.0) {
      riskColor = const Color(0xFFF59E0B);
      riskTitle = 'Risiko Sedang';
      riskDesc = 'Tingkat risiko diabetes Anda sedang. Harap jaga pola makan Anda dan pertahankan aktivitas fisik.';
    } else {
      riskColor = const Color(0xFF16A34A);
      riskTitle = 'Risiko Rendah';
      riskDesc = 'Kadar glukosa Anda menunjukkan stabilitas tinggi selama 30 hari terakhir. Tidak ada anomali kritis.';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textDark, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'DiaCare AI',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (widget.pickedImage == null && widget.avatarUrl.isEmpty)
                    ? const LinearGradient(
                        colors: [Color(0xFF4A90D9), AppTheme.primaryBlue],
                      )
                    : null,
                image: widget.pickedImage != null
                    ? DecorationImage(
                        image: kIsWeb
                            ? NetworkImage(widget.pickedImage!.path)
                            : FileImage(File(widget.pickedImage!.path)) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : widget.avatarUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(widget.avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: (widget.pickedImage == null && widget.avatarUrl.isEmpty)
                  ? Center(
                      child: Text(
                        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'U',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
        shape: const Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF3FF), Color(0xFFF8FAFC)],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Success Checkmark with glowing ring
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7).withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Color(0xFF16A34A),
                            size: 38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Laporan Siap',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Laporan kesehatan Anda untuk bulan ini telah berhasil dibuat dan dianalisis secara akurat.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textGrey,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),

                // Card 1: Current Risk Level
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TINGKAT RISIKO SAAT INI',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    riskTitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: riskColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: riskColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Stabil',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: riskColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: AppTheme.borderColor, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.bar_chart_rounded,
                                color: Color(0xFF94A3B8),
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress Bar Visualizer
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: (widget.riskPercentage / 100).clamp(0.0, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: riskColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        riskDesc,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textGrey,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Grid/Row: Avg Glucose and HbA1c
                Row(
                  children: [
                    // Avg Glucose Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.borderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.02),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.opacity_rounded,
                                    color: AppTheme.primaryBlue,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'RERATA GULA',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textLight,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  widget.averageGlucose,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textDark,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  ' mg/dL',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: glucoseVal <= 140.0
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  glucoseVal <= 140.0 ? 'Batas Normal' : 'Gula Tinggi',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppTheme.textGrey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // HbA1c Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.borderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.02),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3C4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.trending_up_rounded,
                                    color: Color(0xFFD97706),
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ESTIMASI HbA1c',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textLight,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  hba1cText,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textDark,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  ' %',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: hba1cEst < 5.7
                                        ? const Color(0xFF16A34A)
                                        : hba1cEst < 6.5
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hba1cEst < 5.7
                                      ? 'Rentang Normal'
                                      : hba1cEst < 6.5
                                          ? 'Prediabetes'
                                          : 'Diabetes',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppTheme.textGrey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Card 3: Report Summary Preview
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Card Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PRATINJAU RINGKASAN LAPORAN',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'PDF • 1.2 MB',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // File Row
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DiaCare_Laporan_Kesehatan_${widget.name.replaceAll(' ', '_')}.pdf',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Dibuat secara akurat dari data rekam medis Anda',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppTheme.textGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Actions / Download Button
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _isDownloading ? null : _handleDownload,
                            icon: _isDownloading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 20, color: Colors.white),
                            label: Text(
                              _isDownloading ? 'Membuat Laporan PDF...' : 'Unduh Laporan PDF',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                // AI Note / Disclaimer Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF64748B),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan: Laporan PDF yang diunduh berisi rangkuman rekam medis terperinci, termasuk grafik mingguan, saran personal, serta anjuran nutrisi AI. Harap konsultasikan dengan dokter Anda.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
