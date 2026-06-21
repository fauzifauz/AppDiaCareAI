import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class HealthReportService {
  static Future<Uint8List> generateReport({
    required String name,
    required String riskLevel,
    required double riskPercentage,
    required double metabolicScore,
    required String averageGlucose,
    required String averageSteps,
    required int warningCount,
    required List<Map<String, String>> historyEntries,
  }) async {
    final now = DateTime.now();
    const indonesianMonths = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final String generatedDate = '${now.day} ${indonesianMonths[now.month - 1]} ${now.year}';
    final String generatedId = 'DC-${now.millisecondsSinceEpoch.toString().substring(8)}';
    final String metabolicCondition = riskPercentage >= 50.0 ? 'Perlu Perhatian' : (riskPercentage >= 20.0 ? 'Waspada' : 'Stabil');

    final pdf = pw.Document();

    final themeColor = PdfColor.fromHex('#1A56DB'); // Blue
    final darkNavy = PdfColor.fromHex('#0F2167'); // Dark Navy
    final warningColor = PdfColor.fromHex('#EF4444'); // Red
    final successColor = PdfColor.fromHex('#16A34A'); // Green
    final lightBlue = PdfColor.fromHex('#EEF3FF'); // Light Blue
    final lightRed = PdfColor.fromHex('#FEF2F2'); // Light Red
    final greyColor = PdfColor.fromHex('#64748B');
    final borderColor = PdfColor.fromHex('#E2E8F0');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
          boldItalic: pw.Font.helveticaBoldOblique(),
        ),
        build: (pw.Context context) {
          return [
            // PAGE 1 CONTENT
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DiaCare AI Health Report',
                      style: pw.TextStyle(
                        color: themeColor,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Laporan Analisis Metabolik & Pemantauan Diabetes',
                      style: pw.TextStyle(
                        color: greyColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: $generatedDate',
                      style: pw.TextStyle(color: greyColor, fontSize: 9),
                    ),
                    pw.Text(
                      'ID: $generatedId',
                      style: pw.TextStyle(color: greyColor, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: borderColor),
            pw.SizedBox(height: 16),

            // Patient Info Section
            pw.Text(
              '1. Informasi Pengguna',
              style: pw.TextStyle(
                color: darkNavy,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBlue,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Nama Pasien: $name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Kondisi Metabolik: $metabolicCondition', style: pw.TextStyle(fontSize: 9, color: greyColor)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Periode Laporan: 7 Hari Terakhir', style: pw.TextStyle(fontSize: 9, color: greyColor)),
                      pw.Text('Rata-rata Gula Darah: $averageGlucose mg/dL', style: pw.TextStyle(fontSize: 9, color: greyColor)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // AI Risk Assessment Section
            pw.Text(
              '2. Hasil Analisis Risiko Diabetes AI',
              style: pw.TextStyle(
                color: darkNavy,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Tingkat Risiko',
                          style: pw.TextStyle(color: greyColor, fontSize: 9),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${riskPercentage.toStringAsFixed(0)}%',
                          style: pw.TextStyle(
                            color: riskPercentage >= 50 ? warningColor : (riskPercentage >= 20 ? PdfColor.fromHex('#F59E0B') : successColor),
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          riskLevel,
                          style: pw.TextStyle(
                            color: riskPercentage >= 50 ? warningColor : (riskPercentage >= 20 ? PdfColor.fromHex('#F59E0B') : successColor),
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Skor Metabolik',
                          style: pw.TextStyle(color: greyColor, fontSize: 9),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${metabolicScore.toStringAsFixed(0)}/100',
                          style: pw.TextStyle(
                            color: themeColor,
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          metabolicScore >= 80 ? 'Kondisi Bagus' : (metabolicScore >= 60 ? 'Kondisi Cukup' : 'Kondisi Lemah'),
                          style: pw.TextStyle(
                            color: metabolicScore >= 80 ? successColor : (metabolicScore >= 60 ? PdfColor.fromHex('#F59E0B') : warningColor),
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Health Warnings / High Glucose Alert (Red & White highlights)
            pw.Text(
              '3. Catatan Penting & Peringatan Medis',
              style: pw.TextStyle(
                color: darkNavy,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: warningCount > 0 ? lightRed : lightBlue,
                border: pw.Border.all(color: warningCount > 0 ? warningColor : themeColor, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    margin: const pw.EdgeInsets.only(top: 4, right: 8),
                    decoration: pw.BoxDecoration(
                      color: warningCount > 0 ? warningColor : themeColor,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          warningCount > 0 ? 'Peringatan Glukosa Tinggi Terdeteksi!' : 'Kadar Gula Darah Terkendali',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: warningCount > 0 ? warningColor : themeColor,
                            fontSize: 10,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          warningCount > 0
                              ? 'Terdeteksi $warningCount kejadian glukosa di atas 140 mg/dL setelah makan minggu ini. Kami menyarankan pembatasan karbohidrat olahan dan melakukan jalan cepat minimal 15 menit setelah makan malam.'
                              : 'Seluruh indikator gula darah berada dalam batas wajar. Pertahankan gaya hidup sehat dan aktivitas fisik secara konsisten.',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: warningCount > 0 ? PdfColor.fromHex('#7F1D1D') : darkNavy,
                            lineSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Rata-rata Statistik
            pw.Text(
              '4. Rata-rata Mingguan',
              style: pw.TextStyle(
                color: darkNavy,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBlue),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Parameter Kesehatan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Rata-rata Nilai', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Keterangan / Batas Aman', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Gula Darah Harian', style: pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('$averageGlucose mg/dL', style: pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Normal: 70 - 130 mg/dL', style: pw.TextStyle(fontSize: 9, color: successColor)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Aktivitas Langkah', style: pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('$averageSteps langkah/hari', style: pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Target: >= 8,000 langkah/hari', style: pw.TextStyle(fontSize: 9, color: successColor)),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: borderColor),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Halaman 1 dari 2', style: pw.TextStyle(color: greyColor, fontSize: 8)),
                pw.Text('DiaCare-AI - Didukung oleh Teknologi Kecerdasan Buatan', style: pw.TextStyle(color: greyColor, fontSize: 8)),
              ],
            ),

            pw.NewPage(), // FORCE PAGE BREAK

            // PAGE 2 CONTENT
            pw.Text(
              '5. Riwayat Catatan Aktivitas Lengkap',
              style: pw.TextStyle(
                color: darkNavy,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBlue),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Aktivitas / Pengukuran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Waktu Catatan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Nilai', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    ),
                  ],
                ),
                ...historyEntries.map((e) {
                  final status = e['status'] ?? 'Normal';
                  final isHigh = status == 'Tinggi' || status == 'Target Kurang' || status == 'Risiko Sedang' || status == 'Risiko Tinggi';
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(e['title'] ?? '', style: pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(e['time'] ?? '', style: pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(e['value'] ?? '', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          status,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: isHigh ? warningColor : successColor,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            // Recommendations section
            pw.Text(
              '6. Rekomendasi Gaya Hidup & Nutrisi AI',
              style: pw.TextStyle(
                color: darkNavy,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildBulletRecommendation('Latihan Jasmani:', 'Targetkan jalan kaki 8,000-10,000 langkah harian secara konsisten. Aktivitas berjalan kaki ringan setelah makan sangat berkontribusi menurunkan glukosa darah postprandial.'),
                  pw.SizedBox(height: 6),
                  _buildBulletRecommendation('Diet & Nutrisi:', 'Batasi asupan nasi putih berlebihan, roti tawar, dan minuman manis. Ganti dengan karbohidrat kompleks seperti nasi merah, oat, atau sayuran berserat tinggi.'),
                  pw.SizedBox(height: 6),
                  _buildBulletRecommendation('Hidrasi Tubuh:', 'Konsumsi minimal 2-2.5 liter air putih setiap hari untuk membantu ginjal membuang kelebihan sisa glukosa tubuh secara alami.'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Disclaimer
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: borderColor, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DISCLAIMER MEDIS:',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: warningColor),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Laporan kesehatan ini sepenuhnya dihitung secara komputasi berdasarkan algoritma kecerdasan buatan (AI) DiaCare-AI. Dokumen ini bertujuan untuk edukasi dan pemantauan mandiri, bukan pengganti diagnosa medis, saran klinis, perawatan, atau resep dokter resmi. Konsultasikan hasil pemantauan ini dengan dokter spesialis atau dokter keluarga Anda untuk penanganan klinis lebih lanjut.',
                    style: pw.TextStyle(fontSize: 7, color: greyColor, lineSpacing: 1.2),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),
            pw.Divider(color: borderColor),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Halaman 2 dari 2', style: pw.TextStyle(color: greyColor, fontSize: 8)),
                pw.Text('DiaCare-AI - Menuju Masyarakat Sehat Bebas Diabetes', style: pw.TextStyle(color: greyColor, fontSize: 8)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildBulletRecommendation(String title, String desc) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 3,
          height: 3,
          margin: const pw.EdgeInsets.only(top: 4, right: 6),
          decoration: const pw.BoxDecoration(
            color: PdfColors.blue,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
              children: [
                pw.TextSpan(text: '$title ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
