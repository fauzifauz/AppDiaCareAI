import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/health_provider.dart';
import '../../models/health_record.dart';
import '../../models/risk_prediction.dart';
import '../dashboard/explainable_ai_screen.dart';
import 'report_preview_screen.dart';


class HistoryEntry {
  final String title;
  final String time;
  final String value;
  final String type; // 'glucose', 'activity', 'risk_prediction'
  final String status; // 'Normal', 'Tinggi', 'Optimal', 'Bagus', 'Rendah', 'Sedang'
  final Color statusColor;
  final IconData icon;
  final Color iconColor;
  final String timestamp;
  final HealthRecord? record;
  final RiskPredictionModel? predictionModel;

  HistoryEntry({
    required this.title,
    required this.time,
    required this.value,
    required this.type,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.iconColor,
    required this.timestamp,
    this.record,
    this.predictionModel,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'Semua';

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return 'Baru saja';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final dayName = days[dateTime.weekday - 1];
      final monthName = months[dateTime.month - 1];
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$dayName, ${dateTime.day} $monthName ${dateTime.year} - $hour:$minute WIB';
    } catch (_) {
      return isoString;
    }
  }

  List<HistoryEntry> _getCombinedEntries(BuildContext context, List<HealthRecord> dbRecords) {
    final List<HistoryEntry> list = [];
    final healthProvider = context.read<HealthProvider>();
    
    // Map DB records with de-duplication
    final Set<String> seenRecordIds = {};
    for (var r in dbRecords) {
      if (r.recordId.isNotEmpty) {
        if (seenRecordIds.contains(r.recordId)) {
          continue;
        }
        seenRecordIds.add(r.recordId);
      }
      list.add(HistoryEntry(
        title: 'Glukosa & Metrik Kesehatan',
        time: _formatDate(r.timestamp),
        value: '${r.glucoseLevel.toInt()} mg/dL',
        type: 'glucose',
        status: r.glucoseStatus,
        statusColor: r.glucoseStatus == 'Normal' ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
        icon: Icons.water_drop_rounded,
        iconColor: r.glucoseStatus == 'Normal' ? AppTheme.primaryBlue : const Color(0xFFEF4444),
        timestamp: r.timestamp,
        record: r,
      ));

      if (r.steps > 0) {
        list.add(HistoryEntry(
          title: 'Aktivitas Langkah Harian',
          time: _formatDate(r.timestamp),
          value: '${r.steps} langkah',
          type: 'activity',
          status: r.steps >= 6000 ? 'Target Tercapai' : 'Target Kurang',
          statusColor: r.steps >= 6000 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
          icon: Icons.directions_run_rounded,
          iconColor: r.steps >= 6000 ? AppTheme.primaryBlue : const Color(0xFFEF4444),
          timestamp: r.timestamp,
          record: r,
        ));
      }
    }

    // Map DB risk predictions with de-duplication
    final Set<String> seenPredictionIds = {};
    for (var p in healthProvider.predictions) {
      if (p.predictionId.isNotEmpty) {
        if (seenPredictionIds.contains(p.predictionId)) {
          continue;
        }
        seenPredictionIds.add(p.predictionId);
      }
      list.add(HistoryEntry(
        title: 'Analisis Risiko Diabetes AI',
        time: _formatDate(p.timestamp),
        value: 'Risiko: ${p.riskPercentage.toStringAsFixed(0)}%',
        type: 'risk_prediction',
        status: p.riskLevel,
        statusColor: p.riskLevel == 'Risiko Rendah'
            ? const Color(0xFF16A34A)
            : (p.riskLevel == 'Risiko Sedang' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
        icon: Icons.psychology_rounded,
        iconColor: p.riskLevel == 'Risiko Rendah'
            ? const Color(0xFF16A34A)
            : (p.riskLevel == 'Risiko Sedang' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
        timestamp: p.timestamp,
        predictionModel: p,
      ));
    }

    // Sort list by timestamp descending (newest first)
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (_selectedFilter == 'Semua') {
      return list;
    } else if (_selectedFilter == 'Glukosa') {
      return list.where((e) => e.type == 'glucose').toList();
    } else if (_selectedFilter == 'Aktivitas') {
      return list.where((e) => e.type == 'activity').toList();
    } else if (_selectedFilter == 'Risiko AI') {
      return list.where((e) => e.type == 'risk_prediction').toList();
    }
    return list;
  }


  @override
  Widget build(BuildContext context) {
    final healthProvider = context.watch<HealthProvider>();
    final dbRecords = healthProvider.records;
    final entries = _getCombinedEntries(context, dbRecords);


    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(healthProvider),
                const SizedBox(height: 24),
                _buildStatsSummary(healthProvider),
                const SizedBox(height: 20),
                _buildWarningBanner(healthProvider),
                const SizedBox(height: 24),
                _buildFilterChips(),
                const SizedBox(height: 20),
                _buildChartSection(healthProvider),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Catatan Aktivitas',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showHealthRecordDialog(),
                      icon: const Icon(Icons.add_rounded, size: 16, color: AppTheme.primaryBlue),
                      label: Text(
                        'Tambah Data',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHistoryList(entries, healthProvider),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(HealthProvider provider) {
    final authProvider = context.read<AuthProvider>();
    final name = authProvider.userProfile?.fullName ?? 'Alex';
    final avgGlucose = provider.averageGlucose;
    final warningCount = provider.records.where((r) => r.glucoseLevel > 140).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Medis',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pantau glukosa, aktivitas, & prediksi AI',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            final latestPrediction = provider.predictions.isNotEmpty ? provider.predictions.first : null;
            final riskLevelVal = latestPrediction != null ? latestPrediction.riskLevel : (avgGlucose > 140 ? 'Risiko Tinggi' : (avgGlucose > 110 ? 'Risiko Sedang' : 'Risiko Rendah'));
            final riskPercentageVal = latestPrediction != null ? latestPrediction.riskPercentage : (avgGlucose > 140 ? 55.0 : (avgGlucose > 110 ? 30.0 : 12.0));
            final metabolicScoreVal = latestPrediction != null ? latestPrediction.metabolicScore : (avgGlucose > 140 ? 65.0 : (avgGlucose > 110 ? 78.0 : 88.0));

            String formatSteps(double steps) {
              final intVal = steps.toInt();
              if (intVal >= 1000) {
                final str = intVal.toString();
                final len = str.length;
                return '${str.substring(0, len - 3)},${str.substring(len - 3)}';
              }
              return intVal.toString();
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportPreviewScreen(
                  name: name,
                  riskLevel: riskLevelVal,
                  riskPercentage: riskPercentageVal,
                  metabolicScore: metabolicScoreVal,
                  averageGlucose: avgGlucose > 0 ? avgGlucose.toStringAsFixed(0) : '0',
                  averageSteps: formatSteps(provider.averageSteps),
                  warningCount: warningCount,
                  historyEntries: [
                    ...provider.records.map((r) => {
                      'title': 'Gula Darah: ${r.glucoseLevel.toInt()} mg/dL (${r.bmiStatus})',
                      'time': r.timestamp.isNotEmpty ? r.timestamp.substring(0, 10) : 'Baru saja',
                      'value': '${r.glucoseLevel.toInt()} mg/dL',
                      'status': r.glucoseStatus,
                    }),
                    ...provider.predictions.map((p) => {
                      'title': 'Analisis Risiko Diabetes AI (${p.riskLevel})',
                      'time': p.timestamp.isNotEmpty ? p.timestamp.substring(0, 10) : 'Baru saja',
                      'value': 'Risiko: ${p.riskPercentage.toStringAsFixed(0)}%',
                      'status': p.riskLevel,
                    }),
                  ],
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.file_download_outlined,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary(HealthProvider provider) {
    final avgGlucose = provider.averageGlucose;
    final avgSteps = provider.averageSteps;
    final warningCount = provider.records.where((r) => r.glucoseLevel > 140).length;

    String glucoseBadgeText = 'Normal';
    Color glucoseBadgeColor = const Color(0xFF16A34A);
    if (avgGlucose > 140) {
      glucoseBadgeText = 'Tinggi';
      glucoseBadgeColor = const Color(0xFFEF4444);
    } else if (avgGlucose > 110) {
      glucoseBadgeText = 'Pre-D';
      glucoseBadgeColor = const Color(0xFFF59E0B);
    } else if (avgGlucose == 0) {
      glucoseBadgeText = 'N/A';
      glucoseBadgeColor = AppTheme.textGrey;
    }

    String stepsValue = '--';
    String stepsBadgeText = 'Pasif';
    Color stepsBadgeColor = const Color(0xFFF59E0B);
    if (avgSteps > 0) {
      if (avgSteps >= 1000) {
        stepsValue = '${(avgSteps / 1000).toStringAsFixed(1)}k';
      } else {
        stepsValue = avgSteps.toStringAsFixed(0);
      }
      if (avgSteps >= 8000) {
        stepsBadgeText = 'Aktif+';
        stepsBadgeColor = const Color(0xFF16A34A);
      } else if (avgSteps >= 6000) {
        stepsBadgeText = 'Aktif';
        stepsBadgeColor = AppTheme.primaryBlue;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.water_drop_rounded,
            iconColor: AppTheme.primaryBlue,
            value: avgGlucose > 0 ? avgGlucose.toStringAsFixed(0) : '--',
            unit: 'mg/dL',
            label: 'Gula Rata',
            badgeText: glucoseBadgeText,
            badgeColor: glucoseBadgeColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.directions_run_rounded,
            iconColor: AppTheme.primaryBlue,
            value: stepsValue,
            unit: 'step',
            label: 'Langkah',
            badgeText: stepsBadgeText,
            badgeColor: stepsBadgeColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.warning_rounded,
            iconColor: warningCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
            value: warningCount.toString(),
            unit: 'Alert',
            label: 'Glukosa',
            badgeText: warningCount > 0 ? 'Alert' : 'Aman',
            badgeColor: warningCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    unit,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      color: AppTheme.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  Widget _buildWarningBanner(HealthProvider provider) {
    final warningCount = provider.records.where((r) => r.glucoseLevel > 140).length;

    if (warningCount > 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peringatan Glukosa Tinggi!',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Terdeteksi $warningCount kadar gula darah tinggi setelah makan minggu ini. Disarankan untuk membatasi asupan gula sederhana dan berolahraga ringan selama 15 menit setelah makan.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF7F1D1D),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kondisi Sangat Baik!',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tidak terdeteksi kadar gula darah tinggi minggu ini. Pertahankan pola makan sehat, hidrasi optimal, dan aktivitas fisik rutin Anda!',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF047857),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'Semua', 'icon': Icons.grid_view_rounded},
      {'label': 'Glukosa', 'icon': Icons.water_drop_rounded},
      {'label': 'Aktivitas', 'icon': Icons.directions_run_rounded},
      {'label': 'Risiko AI', 'icon': Icons.psychology_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final label = f['label'] as String;
          final icon = f['icon'] as IconData;
          final isSelected = _selectedFilter == label;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = label),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : AppTheme.textGrey,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSingleChartCard({
    required double width,
    required String title,
    required String averageLabel,
    required Widget chart,
    required Widget legend,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  averageLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: chart,
          ),
          const SizedBox(height: 12),
          Center(child: legend),
        ],
      ),
    );
  }

  Widget _buildChartSection(HealthProvider provider) {
    List<double> glucoseData = [];
    if (provider.records.isNotEmpty) {
      final records = provider.records.take(7).toList();
      if (records.length >= 2) {
        glucoseData = records.reversed.map((r) => r.glucoseLevel).toList();
      } else if (records.length == 1) {
        glucoseData = [records[0].glucoseLevel, records[0].glucoseLevel];
      }
    }
    final double averageVal = glucoseData.isNotEmpty
        ? glucoseData.reduce((a, b) => a + b) / glucoseData.length
        : 0.0;

    List<double> activityData = [];
    if (provider.records.isNotEmpty) {
      final records = provider.records.take(7).toList();
      if (records.length >= 2) {
        activityData = records.reversed.map((r) => r.steps.toDouble()).toList();
      } else if (records.length == 1) {
        activityData = [records[0].steps.toDouble(), records[0].steps.toDouble()];
      }
    }

    List<double> riskData = [];
    if (provider.predictions.isNotEmpty) {
      final sortedPredictions = List<RiskPredictionModel>.from(provider.predictions)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final lastPredictions = sortedPredictions.length > 7
          ? sortedPredictions.sublist(sortedPredictions.length - 7)
          : sortedPredictions;
      if (lastPredictions.isNotEmpty) {
        riskData = lastPredictions.map((p) => p.riskPercentage).toList();
        if (riskData.length == 1) {
          riskData = [riskData[0], riskData[0]];
        }
      }
    }
    final double averageRisk = riskData.isNotEmpty
        ? riskData.reduce((a, b) => a + b) / riskData.length
        : 0.0;

    final bool hasRecords = provider.records.isNotEmpty;
    final bool hasPredictions = provider.predictions.isNotEmpty;

    final double screenWidth = MediaQuery.of(context).size.width;
    final List<String> activeFiltersForCharts = [];
    if (_selectedFilter == 'Semua') {
      activeFiltersForCharts.addAll(['Glukosa', 'Aktivitas', 'Risiko AI']);
    } else if (_selectedFilter == 'Glukosa') {
      activeFiltersForCharts.add('Glukosa');
    } else if (_selectedFilter == 'Aktivitas') {
      activeFiltersForCharts.addAll(['Aktivitas', 'Risiko AI']);
    } else if (_selectedFilter == 'Risiko AI') {
      activeFiltersForCharts.add('Risiko AI');
    }

    final double cardWidth = activeFiltersForCharts.length > 1 ? screenWidth - 60 : screenWidth - 40;

    final List<Widget> chartWidgets = [];
    for (int i = 0; i < activeFiltersForCharts.length; i++) {
      final f = activeFiltersForCharts[i];
      final isLast = i == activeFiltersForCharts.length - 1;
      
      Widget card;
      if (f == 'Glukosa') {
        card = !hasRecords
            ? _buildChartEmptyState(cardWidth, 'Grafik Tren Glukosa Darah', Icons.water_drop_rounded, 'Belum ada data gula darah.\nTambahkan catatan pertama Anda!')
            : _buildSingleChartCard(
                width: cardWidth,
                title: 'Grafik Tren Glukosa Darah (7 Hari)',
                averageLabel: 'Rerata: ${averageVal.toStringAsFixed(0)} mg/dL',
                chart: CustomPaint(
                  painter: _GlucoseChartPainter(glucoseData),
                  size: Size.infinite,
                ),
                legend: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildLegendItem(AppTheme.primaryBlue, 'Normal (70-130)'),
                    _buildLegendItem(const Color(0xFFEF4444), 'Tinggi (>130)'),
                  ],
                ),
              );
      } else if (f == 'Aktivitas') {
        card = !hasRecords
            ? _buildChartEmptyState(cardWidth, 'Grafik Langkah Harian', Icons.directions_run_rounded, 'Belum ada data aktivitas.\nMulai catat langkah harian Anda!')
            : _buildSingleChartCard(
                width: cardWidth,
                title: 'Grafik Langkah Harian (7 Hari)',
                averageLabel: 'Rerata: ${provider.averageSteps > 0 ? (provider.averageSteps >= 1000 ? (provider.averageSteps / 1000).toStringAsFixed(1) + "k" : provider.averageSteps.toStringAsFixed(0)) : "--"}',
                chart: CustomPaint(
                  painter: _ActivityChartPainter(activityData),
                  size: Size.infinite,
                ),
                legend: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildLegendItem(AppTheme.primaryBlue, 'Tercapai (>= 8k)'),
                    _buildLegendItem(const Color(0xFFEF4444), 'Kurang (< 8k)'),
                  ],
                ),
              );
      } else {
        card = !hasPredictions
            ? _buildChartEmptyState(cardWidth, 'Grafik Tren Risiko Diabetes AI', Icons.psychology_rounded, 'Belum ada analisis AI.\nJalankan prediksi risiko pertama Anda!')
            : _buildSingleChartCard(
                width: cardWidth,
                title: 'Grafik Tren Risiko Diabetes AI',
                averageLabel: 'Rerata: ${averageRisk.toStringAsFixed(1)}%',
                chart: CustomPaint(
                  painter: _RiskChartPainter(riskData),
                  size: Size.infinite,
                ),
                legend: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildLegendItem(const Color(0xFF16A34A), 'Rendah (<20%)'),
                    _buildLegendItem(const Color(0xFFF59E0B), 'Sedang (20%-49%)'),
                    _buildLegendItem(const Color(0xFFEF4444), 'Tinggi (>=50%)'),
                  ],
                ),
              );
      }

      chartWidgets.add(
        Padding(
          padding: EdgeInsets.only(right: isLast ? 0 : 16),
          child: card,
        ),
      );
    }

    if (chartWidgets.length == 1) {
      return chartWidgets[0];
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: chartWidgets,
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppTheme.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildChartEmptyState(double width, String title, IconData icon, String message) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppTheme.primaryBlue.withOpacity(0.4), size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<HistoryEntry> entries, HealthProvider provider) {
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 40,
              color: AppTheme.textLight,
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada riwayat untuk kategori ini',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: entries.map((entry) {
        final isDbRecord = entry.record != null;

        return GestureDetector(
          onTap: () {
            if (entry.type == 'risk_prediction' && entry.predictionModel != null) {
              final p = entry.predictionModel!;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExplainableAiScreen(
                    risk: p.riskPercentage,
                    gender: p.gender,
                    age: p.age,
                    hypertension: p.hypertension ? 'Ya' : 'Tidak',
                    heartDisease: p.heartDisease ? 'Ya' : 'Tidak',
                    smokingHistory: p.smokingHistory,
                    bmi: p.bmi,
                    hba1c: p.hba1c,
                    glucose: p.glucose,
                    savedContributions: p.contributions,
                    savedModelTransparency: p.modelTransparency,
                  ),
                ),
              );
            }
          },
          child: Container(

          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: entry.iconColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        entry.icon,
                        color: entry.iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: AppTheme.textLight,
                                ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.time,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textGrey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              entry.value,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: entry.statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                entry.status,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: entry.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (entry.type == 'risk_prediction') ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.textLight,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                  if (isDbRecord) ...[
                    const Divider(color: AppTheme.borderColor, height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'METRIK DETAIL',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textLight,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'TD: ${entry.record!.bloodPressure.isNotEmpty ? entry.record!.bloodPressure : '--'} mmHg  •  DJ: ${entry.record!.heartRate.toInt()} bpm  •  BMI: ${entry.record!.bmi.toStringAsFixed(1)} (${entry.record!.bmiStatus})',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textGrey,
                                ),
                              ),
                              if (entry.record!.notes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Catatan: "${entry.record!.notes}"',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.textGrey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showHealthRecordDialog(record: entry.record),
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryBlue),
                              tooltip: 'Ubah Data',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Hapus Catatan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                    content: Text('Apakah Anda yakin ingin menghapus catatan kesehatan ini?', style: GoogleFonts.inter()),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textGrey, fontWeight: FontWeight.w600)),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final success = await provider.removeHealthRecord(entry.record!.recordId);
                                          if (success) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Catatan kesehatan berhasil dihapus!',
                                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                                  ),
                                                  backgroundColor: const Color(0xFF22C55E),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: Text('Hapus', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              tooltip: 'Hapus Data',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }


  void _showHealthRecordDialog({HealthRecord? record}) {
    final isEditing = record != null;
    
    final glucoseController = TextEditingController(
      text: isEditing ? record.glucoseLevel.toInt().toString() : '',
    );
    final bpController = TextEditingController(
      text: isEditing ? record.bloodPressure : '',
    );
    final heartRateController = TextEditingController(
      text: isEditing ? record.heartRate.toInt().toString() : '',
    );
    final weightController = TextEditingController(
      text: isEditing ? record.weight.toString() : '',
    );
    final stepsController = TextEditingController(
      text: isEditing ? record.steps.toString() : '',
    );
    
    double prefilledHeight = 170.0;
    if (isEditing && record.bmi > 0 && record.weight > 0) {
      prefilledHeight = math.sqrt(record.weight / record.bmi) * 100;
    }
    final heightController = TextEditingController(
      text: isEditing ? prefilledHeight.toStringAsFixed(1) : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? record.notes : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditing ? 'Ubah Catatan Kesehatan' : 'Tambah Catatan Kesehatan',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              label: 'Gula Darah (mg/dL)',
                              controller: glucoseController,
                              icon: Icons.water_drop_rounded,
                              hint: 'Contoh: 120',
                              inputType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDialogField(
                              label: 'Tekanan Darah (mmHg)',
                              controller: bpController,
                              icon: Icons.favorite_rounded,
                              hint: 'Contoh: 120/80',
                              inputType: TextInputType.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              label: 'Denyut Jantung (bpm)',
                              controller: heartRateController,
                              icon: Icons.heart_broken_rounded,
                              hint: 'Contoh: 80',
                              inputType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDialogField(
                              label: 'Tinggi Badan (cm)',
                              controller: heightController,
                              icon: Icons.height_rounded,
                              hint: 'Contoh: 170',
                              inputType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              label: 'Berat Badan (kg)',
                              controller: weightController,
                              icon: Icons.monitor_weight_rounded,
                              hint: 'Contoh: 65',
                              inputType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDialogField(
                              label: 'Langkah Harian',
                              controller: stepsController,
                              icon: Icons.directions_run_rounded,
                              hint: 'Contoh: 8000',
                              inputType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDialogField(
                        label: 'Catatan tambahan',
                        controller: notesController,
                        icon: Icons.notes_rounded,
                        hint: 'Tulis gejala atau catatan makanan...',
                        inputType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 28),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                           onPressed: () async {
                            final gLevel = double.tryParse(glucoseController.text.trim()) ?? 0.0;
                            final bp = bpController.text.trim();
                            final hRate = double.tryParse(heartRateController.text.trim()) ?? 0.0;
                            final wt = double.tryParse(weightController.text.trim()) ?? 0.0;
                            final ht = double.tryParse(heightController.text.trim()) ?? 0.0;
                            final notes = notesController.text.trim();
                            final stepsStr = stepsController.text.trim();
                            
                            if (gLevel <= 0 || wt <= 0 || ht <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Harap lengkapi metrik wajib (Gula Darah, Berat Badan, Tinggi Badan) dengan nilai valid.',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                              return;
                            }

                            if (stepsStr.isNotEmpty && int.tryParse(stepsStr) == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Jumlah langkah harian harus berupa angka bulat yang valid.',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                              return;
                            }
                            
                            final steps = stepsStr.isEmpty ? 0 : (int.tryParse(stepsStr) ?? 0);
                            final bmi = HealthRecord.calculateBMI(wt, ht);
                            
                            final newRecord = HealthRecord(
                              recordId: isEditing ? record.recordId : '',
                              glucoseLevel: gLevel,
                              bloodPressure: bp,
                              heartRate: hRate,
                              weight: wt,
                              bmi: bmi,
                              steps: steps,
                              notes: notes,
                              timestamp: isEditing ? record.timestamp : DateTime.now().toIso8601String(),
                            );
                            
                            final provider = context.read<HealthProvider>();
                            bool success;
                            if (isEditing) {
                              success = await provider.editHealthRecord(newRecord);
                            } else {
                              success = await provider.addHealthRecord(newRecord);
                            }
                            
                            if (success) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEditing 
                                        ? 'Catatan kesehatan berhasil diperbarui!'
                                        : 'Catatan kesehatan berhasil ditambahkan!',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: const Color(0xFF22C55E),
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      provider.errorMessage ?? 'Gagal menyimpan data.',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: const Color(0xFFEF4444),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'Simpan Perubahan' : 'Tambah Catatan',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required TextInputType inputType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textLight,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: inputType,
          maxLines: inputType == TextInputType.multiline ? 3 : 1,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 18),
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _GlucoseChartPainter extends CustomPainter {
  final List<double> values;
  _GlucoseChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    const minVal = 60.0;
    const maxVal = 170.0;

    final gridPaint = Paint()
      ..color = AppTheme.borderColor.withOpacity(0.5)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final double yRange = size.height - 30;
    final double xRange = size.width - 40;
    final double startX = 30;
    final double startY = 15;

    final yLabels = [70, 100, 130, 160];
    for (var label in yLabels) {
      final y = startY + yRange * (1.0 - (label - minVal) / (maxVal - minVal));
      canvas.drawLine(Offset(startX, y), Offset(size.width - 10, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$label',
        style: GoogleFonts.inter(
          fontSize: 9,
          color: AppTheme.textLight,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(startX - 24, y - 6));
    }

    final y70 = startY + yRange * (1.0 - (70 - minVal) / (maxVal - minVal));
    final y130 = startY + yRange * (1.0 - (130 - minVal) / (maxVal - minVal));

    final normalBandPaint = Paint()
      ..color = AppTheme.primaryBlue.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(startX, y130, size.width - 10, y70),
      normalBandPaint,
    );

    final targetLinePaint = Paint()
      ..color = AppTheme.primaryBlue.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(startX, y70), Offset(size.width - 10, y70), targetLinePaint);
    canvas.drawLine(Offset(startX, y130), Offset(size.width - 10, y130), targetLinePaint);

    final linePaint = Paint()
      ..color = AppTheme.primaryBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.primaryBlue.withOpacity(0.2),
          AppTheme.primaryBlue.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(startX, startY, xRange, yRange))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    List<Offset> points = [];
    for (int i = 0; i < values.length; i++) {
      final x = startX + xRange * i / (values.length - 1);
      final y = startY + yRange * (1.0 - (values[i] - minVal) / (maxVal - minVal));
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, startY + yRange);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
      fillPath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    fillPath.lineTo(points.last.dx, startY + yRange);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final normalDotPaint = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.fill;
    final warningDotPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    final dotBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      final p = points[i];
      final val = values[i];
      final isHigh = val > 130;

      canvas.drawCircle(p, 6, isHigh ? warningDotPaint : normalDotPaint);
      canvas.drawCircle(p, 3.5, dotBgPaint);
    }

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int i = 0; i < days.length; i++) {
      final x = startX + xRange * i / (days.length - 1);
      textPainter.text = TextSpan(
        text: days[i],
        style: GoogleFonts.inter(
          fontSize: 9,
          color: AppTheme.textGrey,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, startY + yRange + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ActivityChartPainter extends CustomPainter {
  final List<double> steps;
  final double target = 6000;

  _ActivityChartPainter(this.steps);

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Belum ada data langkah',
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textGrey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    double maxSteps = steps.reduce(math.max);
    if (maxSteps < 6000) maxSteps = 6000;
    final maxVal = maxSteps * 1.2;

    final gridPaint = Paint()
      ..color = AppTheme.borderColor.withOpacity(0.5)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final double yRange = size.height - 30;
    final double xRange = size.width - 40;
    final double startX = 30;
    final double startY = 15;

    final yLabels = [2000, 4000, 6000];
    for (var label in yLabels) {
      if (label > maxVal) continue;
      final y = startY + yRange * (1.0 - label / maxVal);
      canvas.drawLine(Offset(startX, y), Offset(size.width - 10, y), gridPaint);

      textPainter.text = TextSpan(
        text: '${(label / 1000).toStringAsFixed(0)}k',
        style: GoogleFonts.inter(
          fontSize: 9,
          color: AppTheme.textLight,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(startX - 22, y - 6));
    }

    final targetY = startY + yRange * (1.0 - target / maxVal);
    final targetLinePaint = Paint()
      ..color = AppTheme.primaryBlue.withOpacity(0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double currentX = startX;
    while (currentX < size.width - 10) {
      canvas.drawLine(
        Offset(currentX, targetY),
        Offset(currentX + dashWidth, targetY),
        targetLinePaint,
      );
      currentX += dashWidth + dashSpace;
    }

    textPainter.text = TextSpan(
      text: 'Target 6k',
      style: GoogleFonts.inter(
        fontSize: 8,
        color: AppTheme.primaryBlue,
        fontWeight: FontWeight.w800,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 12, targetY - 12));

    final barBluePaint = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.fill;

    final barRedPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    const barWidth = 14.0;

    for (int i = 0; i < steps.length; i++) {
      final double x = steps.length > 1
          ? startX + xRange * i / (steps.length - 1)
          : startX + xRange / 2;
      final y = startY + yRange * (1.0 - steps[i] / maxVal);
      final isTargetMet = steps[i] >= target;

      final rect = Rect.fromLTRB(x - barWidth / 2, y, x + barWidth / 2, startY + yRange);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

      canvas.drawRRect(rrect, isTargetMet ? barBluePaint : barRedPaint);
    }

    final days = ['H-6', 'H-5', 'H-4', 'H-3', 'H-2', 'H-1', 'Hari ini'];
    final int showDays = steps.length;
    for (int i = 0; i < showDays; i++) {
      final double x = showDays > 1
          ? startX + xRange * i / (showDays - 1)
          : startX + xRange / 2;
      
      final labelIndex = days.length - showDays + i;
      final dayLabel = labelIndex >= 0 && labelIndex < days.length ? days[labelIndex] : '';
      
      textPainter.text = TextSpan(
        text: dayLabel,
        style: GoogleFonts.inter(
          fontSize: 8,
          color: AppTheme.textGrey,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, startY + yRange + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RiskChartPainter extends CustomPainter {
  final List<double> values;
  _RiskChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Belum ada data analisis risiko',
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textGrey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    const minVal = 0.0;
    const maxVal = 100.0;

    final gridPaint = Paint()
      ..color = AppTheme.borderColor.withOpacity(0.5)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final double yRange = size.height - 30;
    final double xRange = size.width - 40;
    final double startX = 30;
    final double startY = 15;

    final yLabels = [0, 20, 50, 80, 100];
    for (var label in yLabels) {
      final y = startY + yRange * (1.0 - (label - minVal) / (maxVal - minVal));
      canvas.drawLine(Offset(startX, y), Offset(size.width - 10, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$label%',
        style: GoogleFonts.inter(
          fontSize: 8,
          color: AppTheme.textLight,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(startX - 28, y - 6));
    }

    // Low risk band (< 20%)
    final lowRiskY = startY + yRange * (1.0 - (20.0 - minVal) / (maxVal - minVal));
    final lowBandPaint = Paint()
      ..color = const Color(0xFF16A34A).withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(startX, lowRiskY, size.width - 10, startY + yRange),
      lowBandPaint,
    );

    // Medium risk band (20% - 50%)
    final medRiskY = startY + yRange * (1.0 - (50.0 - minVal) / (maxVal - minVal));
    final medBandPaint = Paint()
      ..color = const Color(0xFFF59E0B).withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(startX, medRiskY, size.width - 10, lowRiskY),
      medBandPaint,
    );

    // High risk band (>= 50%)
    final highBandPaint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(startX, startY, size.width - 10, medRiskY),
      highBandPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFF8B5CF6) // Purple for AI risk
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8B5CF6).withOpacity(0.2),
          const Color(0xFF8B5CF6).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(startX, startY, xRange, yRange))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    List<Offset> points = [];
    for (int i = 0; i < values.length; i++) {
      final x = values.length > 1
          ? startX + xRange * i / (values.length - 1)
          : startX + xRange / 2;
      final y = startY + yRange * (1.0 - (values[i] - minVal) / (maxVal - minVal));
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, startY + yRange);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
      fillPath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    fillPath.lineTo(points.last.dx, startY + yRange);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final lowDotPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.fill;
    final medDotPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;
    final highDotPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    final dotBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      final p = points[i];
      final val = values[i];
      
      Paint dotPaint = lowDotPaint;
      if (val >= 50.0) {
        dotPaint = highDotPaint;
      } else if (val >= 20.0) {
        dotPaint = medDotPaint;
      }

      canvas.drawCircle(p, 6, dotPaint);
      canvas.drawCircle(p, 3.5, dotBgPaint);
    }

    final days = ['Data 1', 'Data 2', 'Data 3', 'Data 4', 'Data 5', 'Data 6', 'Terbaru'];
    final int showDays = values.length;
    for (int i = 0; i < showDays; i++) {
      final double x = showDays > 1
          ? startX + xRange * i / (showDays - 1)
          : startX + xRange / 2;
      
      final labelIndex = days.length - showDays + i;
      final dayLabel = labelIndex >= 0 && labelIndex < days.length ? days[labelIndex] : '';

      textPainter.text = TextSpan(
        text: dayLabel,
        style: GoogleFonts.inter(
          fontSize: 8,
          color: AppTheme.textGrey,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, startY + yRange + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
