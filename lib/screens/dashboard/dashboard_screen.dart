import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/privacy_provider.dart';
import '../../repositories/database_repository.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import 'risk_prediction_screen.dart';
import 'explainable_ai_screen.dart';
import '../../models/risk_prediction.dart';
import '../../models/sensor_data.dart';
import '../../services/firebase_sensor_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _selectedIndex == 0
            ? _HomeContent(
                key: const ValueKey('home'),
                onNavigateToTab: (index) {
                  setState(() => _selectedIndex = index);
                },
              )
            : _selectedIndex == 1
                ? const HistoryScreen(key: ValueKey('history'))
                : const ProfileScreen(key: ValueKey('profile')),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.history_rounded, Icons.history_outlined, 'History'),
              _buildNavItem(2, Icons.person_rounded, Icons.person_outlined, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryBlue.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? AppTheme.primaryBlue : AppTheme.textGrey,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? AppTheme.primaryBlue : AppTheme.textGrey,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HealthNotification {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final String time;
  final bool isNew;
  final VoidCallback onTap;
  final String uniqueKey;

  HealthNotification({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.time,
    required this.isNew,
    required this.onTap,
    required this.uniqueKey,
  });
}

class HealthTip {
  final IconData icon;
  final String title;
  final String desc;

  HealthTip({
    required this.icon,
    required this.title,
    required this.desc,
  });
}

class _HomeContent extends StatefulWidget {
  final Function(int) onNavigateToTab;
  const _HomeContent({super.key, required this.onNavigateToTab});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  bool _hasReadNotifications = false;
  final Set<String> _readNotificationIds = {};
  StreamSubscription<DatabaseEvent>? _readNotifSub;
  StreamSubscription<DatabaseEvent>? _hasReadAllSub;
  
  final FirebaseSensorService _sensorService = FirebaseSensorService();
  final DatabaseRepository _dbRepository = DatabaseRepository();
  DateTime? _lastSensorSave;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();

    // Set up Firebase listeners for read notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToReadNotifications();
    });
  }

  @override
  void dispose() {
    _readNotifSub?.cancel();
    _hasReadAllSub?.cancel();
    _sensorService.stopSimulation();
    _animController.dispose();
    super.dispose();
  }

  void _listenToReadNotifications() {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;

    // Listen to read notification IDs
    _readNotifSub?.cancel();
    _readNotifSub = FirebaseDatabase.instance
        .ref('users/$uid/read_notifications')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final value = event.snapshot.value;
      if (value is List) {
        setState(() {
          _readNotificationIds.clear();
          _readNotificationIds.addAll(value.map((e) => e.toString()));
        });
      } else if (value is Map) {
        setState(() {
          _readNotificationIds.clear();
          _readNotificationIds.addAll(value.values.map((e) => e.toString()));
        });
      }
    });

    // Listen to has_read_all_notifications flag
    _hasReadAllSub?.cancel();
    _hasReadAllSub = FirebaseDatabase.instance
        .ref('users/$uid/has_read_all_notifications')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final value = event.snapshot.value;
      if (value is bool) {
        setState(() {
          _hasReadNotifications = value;
        });
      }
    });
  }

  Future<void> _markNotificationAsRead(String key) async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    
    setState(() {
      _readNotificationIds.add(key);
    });

    await FirebaseDatabase.instance
        .ref('users/$uid/read_notifications')
        .set(_readNotificationIds.toList());
  }

  Future<void> _markAllNotificationsAsRead(List<HealthNotification> notificationsList) async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;

    setState(() {
      _hasReadNotifications = true;
      for (var n in notificationsList) {
        _readNotificationIds.add(n.uniqueKey);
      }
    });

    await FirebaseDatabase.instance
        .ref('users/$uid/read_notifications')
        .set(_readNotificationIds.toList());

    await FirebaseDatabase.instance
        .ref('users/$uid/has_read_all_notifications')
        .set(true);
  }

  /// Throttle sensor data saves to once every 5 minutes to avoid RTDB write spam.
  Future<void> _maybeSaveSensorData(SensorData data) async {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastSensorSave != null &&
        now.difference(_lastSensorSave!) < const Duration(minutes: 5)) {
      return;
    }
    _lastSensorSave = now;

    final privacyProvider = context.read<PrivacyProvider>();
    final storeHistory = privacyProvider.settings?.storeHistory ?? true;
    if (!storeHistory) return;

    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;

    try {
      await _dbRepository.saveSensorDataHistory(uid, {
        'temperature': data.temperature,
        'humidity': data.humidity,
        'glucose': data.glucose,
        'timestamp': data.timestamp.isNotEmpty
            ? data.timestamp
            : DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Dashboard: Failed to save sensor history: $e');
    }
  }

  List<HealthNotification> _getDynamicNotifications(HealthProvider provider) {
    final List<HealthNotification> list = [];
    final records = provider.records;
    final predictions = provider.predictions;

    // Helper check for read status using unique key
    bool isUnread(String uniqueKey) {
      return !_hasReadNotifications && !_readNotificationIds.contains(uniqueKey);
    }

    // Helper: format a date relative to now. Falls back to 'Baru saja' for very new dates.
    String _relativeLabel(String isoString) {
      if (isoString.isEmpty) return 'Baru saja';
      try {
        final dt = DateTime.parse(isoString).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) return 'Baru saja';
        if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
        if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
        if (diff.inDays == 1) return '1 hari yang lalu';
        return '${diff.inDays} hari yang lalu';
      } catch (_) {
        return 'Baru saja';
      }
    }

    // Retrieve user registration date to compute relative labels correctly
    final authProvider = context.read<AuthProvider>();
    final registeredAt = authProvider.userProfile?.createdAt ?? '';
    final screeningTime = _relativeLabel(registeredAt);

    // 1. Skrining Diabetes / Health screening reminder
    const titleScreening = 'Skrining Diabetes AI';
    const keyScreening = 'Skrining Diabetes AI';
    list.add(HealthNotification(
      icon: Icons.monitor_heart_rounded,
      color: const Color(0xFF8B5CF6),
      title: titleScreening,
      desc: 'Lakukan pemindaian risiko diabetes secara berkala menggunakan fitur prediksi cerdas AI kami.',
      time: screeningTime,
      isNew: isUnread(keyScreening),
      uniqueKey: keyScreening,
      onTap: () {
        Navigator.pop(context);
        _markNotificationAsRead(keyScreening);
        _showPredictionDialog();
      },
    ));

    // 2. Pembaruan Data Kesehatan / Update health data reminder
    bool shouldShowReminder = true;
    if (records.isNotEmpty) {
      DateTime? latestTime;
      for (var record in records) {
        final parsed = DateTime.tryParse(record.timestamp);
        if (parsed != null) {
          if (latestTime == null || parsed.isAfter(latestTime)) {
            latestTime = parsed;
          }
        }
      }
      if (latestTime != null) {
        final difference = DateTime.now().difference(latestTime);
        if (difference.inHours < 24) {
          shouldShowReminder = false;
        }
      }
    }

    if (shouldShowReminder) {
      const titleUpdateData = 'Pembaruan Metrik Medis';
      // Reappear daily if they still haven't updated
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final keyUpdateData = 'Pembaruan Metrik Medis_$todayStr';
      // For new users (no records), the reminder appeared right at registration
      final reminderTime = records.isEmpty ? screeningTime : '1 hari yang lalu';
      list.add(HealthNotification(
        icon: Icons.edit_note_rounded,
        color: const Color(0xFFEF4444),
        title: titleUpdateData,
        desc: records.isEmpty
            ? 'Belum ada data yang dicatat. Mulai catat gula darah dan aktivitas harian pertama Anda sekarang!'
            : 'Sudah lebih dari 24 jam sejak pencatatan terakhir. Perbarui data gula darah dan aktivitas harian Anda sekarang.',
        time: reminderTime,
        isNew: isUnread(keyUpdateData),
        uniqueKey: keyUpdateData,
        onTap: () {
          Navigator.pop(context);
          _markNotificationAsRead(keyUpdateData);
          widget.onNavigateToTab(1);
        },
      ));
    }

    // 3. Hasil Analisis Risiko Terbaru / Latest Risk analysis (dynamic)
    if (predictions.isNotEmpty) {
      final latestP = predictions.first;
      final titleAnalysis = 'Hasil Analisis AI Baru';
      final keyAnalysis = 'Hasil Analisis AI Baru_${latestP.predictionId}';
      list.add(HealthNotification(
        icon: Icons.psychology_rounded,
        color: AppTheme.primaryBlue,
        title: titleAnalysis,
        desc: 'Risiko diabetes Anda dianalisis sebesar ${latestP.riskPercentage.toStringAsFixed(0)}% (${latestP.riskLevel}).',
        time: _formatNotificationDate(latestP.timestamp),
        isNew: isUnread(keyAnalysis),
        uniqueKey: keyAnalysis,
        onTap: () {
          Navigator.pop(context);
          _markNotificationAsRead(keyAnalysis);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExplainableAiScreen(
                risk: latestP.riskPercentage,
                gender: latestP.gender,
                age: latestP.age,
                hypertension: latestP.hypertension ? 'Ya' : 'Tidak',
                heartDisease: latestP.heartDisease ? 'Ya' : 'Tidak',
                smokingHistory: latestP.smokingHistory,
                bmi: latestP.bmi,
                hba1c: latestP.hba1c,
                glucose: latestP.glucose,
                savedContributions: latestP.contributions,
                savedModelTransparency: latestP.modelTransparency,
              ),
            ),
          );
        },
      ));

      // 4. Informasi Perubahan Tingkat Risiko / Risk level change (dynamic comparison)
      final titleTrend = 'Tren Perubahan Risiko AI';
      final keyTrend = 'Tren Perubahan Risiko AI_${latestP.predictionId}';
      String trendDesc = 'Tingkat risiko diabetes Anda stabil pada kategori ${latestP.riskLevel}. Klik untuk detail prediksi.';
      IconData trendIcon = Icons.trending_flat_rounded;
      Color trendColor = AppTheme.primaryBlue;
      if (predictions.length >= 2) {
        final p1 = predictions[0];
        final p2 = predictions[1];
        final diff = p1.riskPercentage - p2.riskPercentage;
        if (diff < -1) {
          trendDesc = 'Kabar baik! Tren risiko diabetes Anda menurun sebesar ${diff.abs().toStringAsFixed(0)}% dibanding analisis sebelumnya.';
          trendIcon = Icons.trending_down_rounded;
          trendColor = const Color(0xFF22C55E);
        } else if (diff > 1) {
          trendDesc = 'Perhatian: Tren risiko diabetes Anda meningkat sebesar ${diff.toStringAsFixed(0)}%. Tinjau pola makan Anda.';
          trendIcon = Icons.trending_up_rounded;
          trendColor = const Color(0xFFEF4444);
        }
      }
      list.add(HealthNotification(
        icon: trendIcon,
        color: trendColor,
        title: titleTrend,
        desc: trendDesc,
        time: _formatNotificationDate(latestP.timestamp),
        isNew: isUnread(keyTrend),
        uniqueKey: keyTrend,
        onTap: () {
          Navigator.pop(context);
          _markNotificationAsRead(keyTrend);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExplainableAiScreen(
                risk: latestP.riskPercentage,
                gender: latestP.gender,
                age: latestP.age,
                hypertension: latestP.hypertension ? 'Ya' : 'Tidak',
                heartDisease: latestP.heartDisease ? 'Ya' : 'Tidak',
                smokingHistory: latestP.smokingHistory,
                bmi: latestP.bmi,
                hba1c: latestP.hba1c,
                glucose: latestP.glucose,
                savedContributions: latestP.contributions,
                savedModelTransparency: latestP.modelTransparency,
              ),
            ),
          );
        },
      ));
    }

    // 5. Informasi Edukasi Diabetes / Educational article
    const titleEducation = 'Edukasi: Mengenal Glukotoksik';
    const keyEducation = 'Edukasi: Mengenal Glukotoksik';
    list.add(HealthNotification(
      icon: Icons.menu_book_rounded,
      color: const Color(0xFFF59E0B),
      title: titleEducation,
      desc: 'Ketahui bahaya paparan gula darah tinggi secara kronis terhadap sistem syaraf dan pembuluh darah tubuh.',
      time: screeningTime,
      isNew: isUnread(keyEducation),
      uniqueKey: keyEducation,
      onTap: () {
        Navigator.pop(context);
        _markNotificationAsRead(keyEducation);
        _showEducationDialog(
          context,
          'Mengenal Bahaya Glukotoksik',
          'Glukotoksik (glukotoksisitas) terjadi akibat tingginya konsentrasi gula darah secara terus-menerus. Kondisi ini merusak sel beta pankreas sehingga menurunkan produksi insulin secara progresif. Selain itu, kelebihan gula merusak dinding pembuluh darah mikro, memicu komplikasi pada mata (retinopati), saraf (neuropati), dan ginjal (nefropati).\n\nLangkah pencegahan utama meliputi:\n1. Menjaga pola makan rendah karbohidrat sederhana.\n2. Melakukan aktivitas fisik teratur.\n3. Memantau gula darah berkala melalui DiaCare AI.',
        );
      },
    ));

    // Dynamic Glucose Warnings
    if (records.isNotEmpty) {
      final latest = records.first;
      final glucose = latest.glucoseLevel;
      final titleGlucoseAlert = glucose > 140
          ? 'Peringatan Gula Darah Tinggi'
          : (glucose < 70 ? 'Peringatan Gula Darah Rendah' : 'Gula Darah Stabil');
      final keyGlucoseAlert = '${titleGlucoseAlert}_${latest.recordId}';

      list.add(HealthNotification(
        icon: glucose > 140
            ? Icons.warning_amber_rounded
            : (glucose < 70 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded),
        color: glucose > 140
            ? const Color(0xFFEF4444)
            : (glucose < 70 ? const Color(0xFFF59E0B) : const Color(0xFF22C55E)),
        title: titleGlucoseAlert,
        desc: glucose > 140
            ? 'Kadar glukosa Anda terdeteksi tinggi (${glucose.toInt()} mg/dL). Batasi konsumsi karbohidrat dan gula.'
            : (glucose < 70
                ? 'Kadar glukosa Anda terlalu rendah (${glucose.toInt()} mg/dL). Segera konsumsi makanan/minuman manis ringan.'
                : 'Kadar glukosa terakhir Anda normal (${glucose.toInt()} mg/dL). Pertahankan pola hidup sehat ini!'),
        time: _formatNotificationDate(latest.timestamp),
        isNew: isUnread(keyGlucoseAlert),
        uniqueKey: keyGlucoseAlert,
        onTap: () {
          Navigator.pop(context);
          _markNotificationAsRead(keyGlucoseAlert);
          widget.onNavigateToTab(1);
        },
      ));

      if (latest.steps > 0) {
        final titleSteps = latest.steps < 6000 ? 'Aktivitas Langkah Kurang' : 'Target Langkah Tercapai!';
        final keySteps = '${titleSteps}_${latest.recordId}';
        list.add(HealthNotification(
          icon: latest.steps < 6000 ? Icons.directions_run_rounded : Icons.stars_rounded,
          color: latest.steps < 6000 ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
          title: titleSteps,
          desc: latest.steps < 6000
              ? 'Langkah harian terakhir Anda (${latest.steps} langkah) masih di bawah target 6,000 langkah. Yuk jalan kaki!'
              : 'Hebat! Langkah harian terakhir Anda mencapai ${latest.steps} langkah. Terus aktif bergerak!',
          time: _formatNotificationDate(latest.timestamp),
          isNew: isUnread(keySteps),
          uniqueKey: keySteps,
          onTap: () {
            Navigator.pop(context);
            _markNotificationAsRead(keySteps);
            widget.onNavigateToTab(1);
          },
        ));
      }
    }

    return list;
  }

  String _formatNotificationDate(String isoString) {
    if (isoString.isEmpty) return 'Baru saja';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final difference = DateTime.now().difference(dateTime);
      if (difference.inMinutes < 1) return 'Baru saja';
      if (difference.inMinutes < 60) return '${difference.inMinutes} menit yang lalu';
      if (difference.inHours < 24) return '${difference.inHours} jam yang lalu';
      return '${dateTime.day} ${_getMonthName(dateTime.month)}';
    } catch (_) {
      return 'Baru saja';
    }
  }

  String _getMonthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    if (month >= 1 && month <= 12) return names[month - 1];
    return '';
  }

  List<HealthTip> _getDynamicTips(HealthProvider provider) {
    final List<HealthTip> tips = [];
    final records = provider.records;
    final predictions = provider.predictions;
    final avgGlucose = provider.averageGlucose;
    final avgSteps = provider.averageSteps;

    final latestPrediction = predictions.isNotEmpty ? predictions.first : null;
    final latestRecord = records.isNotEmpty ? records.first : null;

    if (latestPrediction != null) {
      // 1. Risk Level Card
      final risk = latestPrediction.riskPercentage;
      Color riskColor;
      IconData riskIcon;
      if (risk < 20) {
        riskColor = const Color(0xFF16A34A);
        riskIcon = Icons.check_circle_rounded;
      } else if (risk < 50) {
        riskColor = const Color(0xFFF59E0B);
        riskIcon = Icons.info_rounded;
      } else {
        riskColor = const Color(0xFFEF4444);
        riskIcon = Icons.warning_rounded;
      }

      tips.add(HealthTip(
        icon: riskIcon,
        title: 'Status Risiko AI: ${latestPrediction.riskLevel}',
        desc: 'Risiko diabetes Anda sebesar ${risk.toStringAsFixed(0)}% (Skor Metabolik: ${latestPrediction.metabolicScore.toStringAsFixed(0)}/100). Data klinis terakhir: HbA1c ${latestPrediction.hba1c}%, Glukosa ${latestPrediction.glucose.toInt()} mg/dL.',
      ));

      // Sort contributions by importance
      final sortedContr = List<FeatureContribution>.from(latestPrediction.contributions)
        ..sort((a, b) => b.contributionPercentage.compareTo(a.contributionPercentage));

      // 2. Identify top 2 driving factors and map to current Health Records
      int addedFactorsCount = 0;
      for (var contr in sortedContr) {
        if (addedFactorsCount >= 2) break;
        if (contr.contributionPercentage <= 0) continue;

        if (contr.name == 'Kadar HbA1c' || contr.name == 'Glukosa Darah') {
          final currentGlucText = latestRecord != null 
              ? 'Catatan gula darah harian terakhir Anda: ${latestRecord.glucoseLevel.toInt()} mg/dL.'
              : 'Gunakan tab Riwayat Medis untuk merekam kadar gula darah harian Anda.';
          tips.add(HealthTip(
            icon: Icons.bloodtype_rounded,
            title: '${contr.name} (Kontribusi ${contr.contributionPercentage.toStringAsFixed(0)}%)',
            desc: '${contr.description} ${contr.impactMessage} $currentGlucText Rekomendasi AI: Utamakan makanan indeks glikemik rendah.',
          ));
          addedFactorsCount++;
        } else if (contr.name == 'Indeks Massa Tubuh') {
          tips.add(HealthTip(
            icon: Icons.monitor_weight_rounded,
            title: 'Indeks Massa Tubuh (Kontribusi ${contr.contributionPercentage.toStringAsFixed(0)}%)',
            desc: 'BMI Anda terdeteksi sebesar ${latestPrediction.bmi.toStringAsFixed(1)}. ${contr.impactMessage} Rekomendasi AI: Jaga keseimbangan energi dengan mengurangi asupan kalori dan meningkatkan aktivitas fisik.',
          ));
          addedFactorsCount++;
        } else if (contr.name == 'Tekanan Darah Tinggi' && latestPrediction.hypertension) {
          tips.add(HealthTip(
            icon: Icons.speed_rounded,
            title: 'Hipertensi Terdeteksi (Kontribusi ${contr.contributionPercentage.toStringAsFixed(0)}%)',
            desc: '${contr.description} Tekanan darah tinggi mempercepat disfungsi endotel. Rekomendasi AI: Batasi garam dapur hingga maksimal 1 sendok teh per hari.',
          ));
          addedFactorsCount++;
        } else if (contr.name == 'Riwayat Merokok' && latestPrediction.smokingHistory == 'Current') {
          tips.add(HealthTip(
            icon: Icons.smoking_rooms_rounded,
            title: 'Riwayat Merokok (Kontribusi ${contr.contributionPercentage.toStringAsFixed(0)}%)',
            desc: 'Status Anda sebagai perokok aktif terdeteksi memicu resistensi insulin. Rekomendasi AI: Upayakan program berhenti merokok guna memulihkan kesehatan paru dan pembuluh darah.',
          ));
          addedFactorsCount++;
        } else if (contr.name == 'Penyakit Jantung' && latestPrediction.heartDisease) {
          tips.add(HealthTip(
            icon: Icons.favorite_rounded,
            title: 'Kondisi Jantung (Kontribusi ${contr.contributionPercentage.toStringAsFixed(0)}%)',
            desc: '${contr.description} Kombinasi penyakit jantung dan risiko diabetes tinggi memerlukan perhatian medis khusus. Lakukan aktivitas fisik ringan teratur.',
          ));
          addedFactorsCount++;
        }
      }

      // 3. Dynamic Activity Tip from Health Records
      if (latestRecord != null && latestRecord.steps > 0) {
        final steps = latestRecord.steps;
        if (steps < 6000) {
          tips.add(HealthTip(
            icon: Icons.directions_run_rounded,
            title: 'Target Aktivitas: ${steps} Langkah/Hari',
            desc: 'Catatan terakhir menunjukkan aktivitas harian Anda baru mencapai ${steps} langkah (target optimal 6,000+ langkah). Tingkatkan dengan jalan cepat setelah makan malam.',
          ));
        } else {
          tips.add(HealthTip(
            icon: Icons.stars_rounded,
            title: 'Aktivitas Harian Baik: ${steps} Langkah',
            desc: 'Langkah harian terakhir Anda (${steps} langkah) sudah memenuhi target optimal. Kebiasaan aktif ini sangat membantu sensitivitas insulin tubuh Anda!',
          ));
        }
      } else {
        tips.add(HealthTip(
          icon: Icons.directions_run_rounded,
          title: 'Aktivitas Langkah Belum Tercatat',
          desc: 'Mulailah mencatat langkah harian Anda di tab Catatan Aktivitas untuk membantu AI memantau pembakaran kalori dan keaktifan tubuh.',
        ));
      }
    } else {
      // FALLBACK IF NO PREDICTIONS YET - Dynamic based on Health Records
      tips.add(HealthTip(
        icon: Icons.analytics_rounded,
        title: 'Mulai Prediksi Risiko AI',
        desc: 'Anda belum melakukan Analisis Risiko AI. Segera lakukan pengisian data klinis pada menu Cek Risiko AI untuk mendapatkan panduan personal.',
      ));

      if (avgGlucose == 0) {
        tips.add(HealthTip(
          icon: Icons.water_drop_rounded,
          title: 'Mulai Pemantauan Glukosa',
          desc: 'Silakan masukkan data kadar gula darah Anda secara teratur di menu Riwayat Medis untuk membantu AI menyusun pola metabolisme Anda.',
        ));
      } else if (avgGlucose > 140) {
        tips.add(HealthTip(
          icon: Icons.warning_amber_rounded,
          title: 'Batasi Konsumsi Karbohidrat & Gula',
          desc: 'Rata-rata glukosa Anda tergolong tinggi (${avgGlucose.toStringAsFixed(0)} mg/dL). Fokus pada makanan berserat tinggi, protein tanpa lemak, dan kurangi camilan manis.',
        ));
      } else if (avgGlucose < 70) {
        tips.add(HealthTip(
          icon: Icons.restaurant_rounded,
          title: 'Pola Makan Terjadwal',
          desc: 'Rata-rata glukosa Anda rendah (${avgGlucose.toStringAsFixed(0)} mg/dL). Hindari melewatkan waktu makan utama dan sediakan camilan sehat seperti kacang-kacangan atau buah.',
        ));
      } else {
        tips.add(HealthTip(
          icon: Icons.check_circle_outline_rounded,
          title: 'Glukosa Sangat Stabil',
          desc: 'Kadar rata-rata glukosa Anda (${avgGlucose.toStringAsFixed(0)} mg/dL) berada dalam batas normal. Pertahankan pola makan seimbang ini.',
        ));
      }

      if (avgSteps == 0) {
        tips.add(HealthTip(
          icon: Icons.directions_run_rounded,
          title: 'Target 6,000 Langkah',
          desc: 'Mulai biasakan berjalan kaki minimal 10 menit setiap pagi atau sore hari untuk menjaga keaktifan otot tubuh Anda.',
        ));
      } else if (avgSteps < 6000) {
        tips.add(HealthTip(
          icon: Icons.directions_run_rounded,
          title: 'Tingkatkan Aktivitas Fisik',
          desc: 'Rata-rata langkah Anda (${avgSteps.toInt()} langkah) masih di bawah target optimal 6,000 langkah. Cobalah berjalan kaki singkat setelah makan malam selama 15 menit.',
        ));
      } else {
        tips.add(HealthTip(
          icon: Icons.stars_rounded,
          title: 'Pertahankan Langkah Aktif',
          desc: 'Hebat! Rata-rata langkah harian Anda (${avgSteps.toInt()} langkah) telah melampaui target. Ini sangat membantu menjaga sensitivitas insulin tubuh Anda.',
        ));
      }
    }

    // Always append sleep quality tip
    tips.add(HealthTip(
      icon: Icons.nightlight_round,
      title: 'Tidur Berkualitas (7-8 Jam)',
      desc: 'Kurang tidur dapat meningkatkan kadar kortisol (hormon stres) yang secara langsung dapat memicu kenaikan kadar gula darah di pagi hari.',
    ));

    return tips;
  }

  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final healthProvider = context.watch<HealthProvider>();
            final notificationsList = _getDynamicNotifications(healthProvider);
            final int unreadCount = notificationsList.where((n) => n.isNew).length;
            final double screenHeight = MediaQuery.of(context).size.height;

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(maxHeight: screenHeight * 0.8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Notifikasi Kesehatan',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _hasReadNotifications = true;
                              for (var n in notificationsList) {
                                _readNotificationIds.add(n.uniqueKey);
                              }
                            });
                            _markAllNotificationsAsRead(notificationsList);
                          },
                          child: Text(
                            'Tandai Terbaca',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (notificationsList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.notifications_off_outlined,
                              size: 48,
                              color: AppTheme.textLight,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada notifikasi baru',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: notificationsList.map((notification) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildNotificationTile(
                                icon: notification.icon,
                                color: notification.color,
                                title: notification.title,
                                desc: notification.desc,
                                time: notification.time,
                                isNew: notification.isNew,
                                onTap: notification.onTap,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required String time,
    required bool isNew,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isNew ? color.withOpacity(0.06) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNew ? color.withOpacity(0.25) : AppTheme.borderColor,
            width: isNew ? 1.5 : 1.0,
          ),
          boxShadow: isNew ? [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isNew ? color.withOpacity(0.15) : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isNew ? color : Colors.grey.shade500, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                            fontSize: 14,
                            fontWeight: isNew ? FontWeight.w800 : FontWeight.w600,
                            color: isNew ? AppTheme.textDark : AppTheme.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isNew ? const Color(0xFFEF4444) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isNew ? 'BARU' : 'DIBACA',
                          style: GoogleFonts.inter(
                            color: isNew ? Colors.white : Colors.grey.shade600,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isNew ? AppTheme.textDark.withOpacity(0.8) : AppTheme.textLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isNew ? FontWeight.w600 : FontWeight.w400,
                      color: isNew ? color : AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEducationDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_rounded, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pencegahan dini adalah kunci utama mengendalikan diabetes melitus.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSystemUpdateDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded, color: AppTheme.primaryBlue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sistem beroperasi normal',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Selesai',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHealthAdviceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final healthProvider = context.read<HealthProvider>();
        final tips = _getDynamicTips(healthProvider);
        final avgGlucose = healthProvider.averageGlucose;

        String adviceSummary = 'Berdasarkan analisis AI terhadap pola kesehatan Anda:';
        if (avgGlucose > 140) {
          adviceSummary = 'Berdasarkan pola glukosa Anda yang cenderung tinggi (${avgGlucose.toStringAsFixed(0)} mg/dL) akhir-akhir ini, AI merekomendasikan langkah intervensi berikut:';
        } else if (avgGlucose < 70) {
          adviceSummary = 'Berdasarkan kecenderungan glukosa yang rendah (${avgGlucose.toStringAsFixed(0)} mg/dL) akhir-akhir ini, AI menyarankan penyesuaian nutrisi berikut:';
        } else if (avgGlucose > 0) {
          adviceSummary = 'Pola kesehatan Anda terpantau sangat stabil (${avgGlucose.toStringAsFixed(0)} mg/dL) dengan tingkat aktivitas yang baik. Berikut tips dari AI untuk memeliharanya:';
        }

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI Health Advisory',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adviceSummary,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textGrey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...tips.map((tip) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTipDetailItem(
                            icon: tip.icon,
                            title: tip.title,
                            desc: tip.desc,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Tutup & Lanjutkan',
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
        );
      },
    );
  }

  Widget _buildTipDetailItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthProvider = context.watch<HealthProvider>();

    return Container(
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
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
                FadeTransition(opacity: _animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(_animation), child: _buildHeroBanner())),
                const SizedBox(height: 24),
                FadeTransition(opacity: _animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_animation), child: _buildQuickActionMenu())),
                const SizedBox(height: 24),
                
                StreamBuilder<SensorData>(
                  stream: _sensorService.getSensorDataStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorState(snapshot.error.toString());
                    }
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }
                    
                    final sensorData = snapshot.data ?? SensorData.initial();

                    // Throttled save of sensor history to RTDB (respects privacy settings)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _maybeSaveSensorData(sensorData);
                    });
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLiveStatusRow(sensorData),
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(_animation),
                            child: _buildRiskCard(sensorData),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(_animation),
                            child: _buildMetricsRow(sensorData),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeTransition(
                          opacity: _animation,
                          child: _buildMedicalSummaryCard(healthProvider),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(opacity: _animation, child: _buildRecentActivitySection(sensorData, healthProvider)),
                        const SizedBox(height: 24),
                        FadeTransition(opacity: _animation, child: _buildAIRecommendationsCard(sensorData, healthProvider)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicalSummaryCard(HealthProvider provider) {
    final records = provider.records.take(5).toList();
    final total = provider.totalRecordsCount;
    final latestLog = provider.latestActivityLog;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
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
              Text(
                'Ringkasan Medis (Manual)',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total Catatan',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada riwayat rekam medis manual. Tambahkan catatan kesehatan di tab Riwayat.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textGrey,
                  height: 1.4,
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 195,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.95),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatNotificationDate(record.timestamp),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: record.glucoseStatus == 'Normal' 
                                    ? const Color(0xFFDCFCE7) 
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                record.glucoseStatus,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: record.glucoseStatus == 'Normal' 
                                      ? const Color(0xFF166534) 
                                      : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSummaryItem('Gula Darah', '${record.glucoseLevel.toInt()} mg/dL', record.glucoseStatus == 'Normal' ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSummaryItem('Tekanan Darah', record.bloodPressure.isNotEmpty ? record.bloodPressure : '--', AppTheme.textDark),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSummaryItem('Denyut Jantung', '${record.heartRate.toInt()} bpm', AppTheme.textDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSummaryItem('Berat Badan', '${record.weight} kg', AppTheme.textDark),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSummaryItem('BMI (Status)', '${record.bmi.toStringAsFixed(1)} (${record.bmiStatus})', record.bmiStatus == 'Normal' ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                            ),
                          ],
                        ),
                        if (record.notes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Catatan: "${record.notes}"',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.textGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Geser horizontal untuk melihat hingga 5 catatan terakhir',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textLight,
                ),
              ),
            ),
          ],
          if (latestLog != null) ...[
            const Divider(color: AppTheme.borderColor, height: 20),
            Row(
              children: [
                const Icon(Icons.history_toggle_off_rounded, color: AppTheme.textLight, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Aktivitas Terakhir: ${latestLog.action} (${latestLog.description})',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textGrey,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLiveStatusRow(SensorData data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const _LivePulseIndicator(),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'PEMANTAUAN HARIAN',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textGrey,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '•',
                style: TextStyle(color: Colors.grey.shade400),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _formatTimestamp(data.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showManualInputDialog(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 14,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  'Catat Data',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showManualInputDialog() {
    final glucoseCtrl = TextEditingController();
    final tempCtrl = TextEditingController();
    final humidityCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Catat Data Kesehatan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                        Text('Input data pengukuran manual Anda', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textGrey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildInputField(
                  controller: glucoseCtrl,
                  label: 'Gula Darah (mg/dL)',
                  hint: 'contoh: 95',
                  icon: Icons.water_drop_outlined,
                  iconColor: const Color(0xFF2563EB),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    final val = double.tryParse(v);
                    if (val == null || val < 30 || val > 600) return 'Masukkan nilai 30–600 mg/dL';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: tempCtrl,
                  label: 'Suhu Tubuh (°C)',
                  hint: 'contoh: 36.5',
                  icon: Icons.thermostat_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    final val = double.tryParse(v);
                    if (val == null || val < 30 || val > 43) return 'Masukkan nilai 30–43 °C';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: humidityCtrl,
                  label: 'Kelembaban Udara (%)',
                  hint: 'contoh: 60',
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    final val = double.tryParse(v);
                    if (val == null || val < 0 || val > 100) return 'Masukkan nilai 0–100%';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text('Simpan Data Kesehatan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      try {
                        await _sensorService.updateSensorData(
                          glucose: double.parse(glucoseCtrl.text),
                          temperature: double.parse(tempCtrl.text),
                          humidity: double.parse(humidityCtrl.text),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Data kesehatan berhasil disimpan!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              backgroundColor: AppTheme.accentGreen,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal menyimpan data: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              backgroundColor: const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textGrey),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textLight),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDC2626))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    if (timestamp.isEmpty) return 'Menunggu data...';
    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final second = dateTime.second.toString().padLeft(2, '0');
      return 'Aktif: $hour:$minute:$second';
    } catch (_) {
      return 'Baru Saja';
    }
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: AppTheme.primaryBlue,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat data kesehatan Anda...',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Menyinkronkan data dengan cloud',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFBBF24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 8),
              Text(
                'Belum Ada Data',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data kesehatan harian Anda belum tersedia. Mulai catat pengukuran pertama Anda hari ini.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF78350F),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Catat Sekarang'),
                onPressed: () => _showManualInputDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Muat Ulang'),
                onPressed: () => setState(() {}),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF92400E),
                  side: const BorderSide(color: Color(0xFFFBBF24)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(HealthProvider healthProvider) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.userProfile;
    final String name = profile?.fullName ?? 'Alex';
    final String initialLetter = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final String subtitle = profile != null 
        ? _formatLastLogin(profile.lastLogin)
        : 'Kondisi metabolisme Anda stabil.';

    final notificationsList = _getDynamicNotifications(healthProvider);
    final int unreadCount = notificationsList.where((n) => n.isNew).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () => widget.onNavigateToTab(2),
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                    gradient: (profile == null || profile.photoUrl.isEmpty)
                        ? const LinearGradient(
                            colors: [Color(0xFF4A90D9), AppTheme.primaryBlue],
                          )
                        : null,
                    image: (profile != null && profile.photoUrl.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(profile.photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (profile == null || profile.photoUrl.isEmpty)
                      ? Center(
                          child: Text(
                            initialLetter,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Halo, $name 👋',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            GestureDetector(
              onTap: _showNotificationBottomSheet,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppTheme.borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
                    child: const Icon(Icons.notifications_outlined, color: AppTheme.textDark, size: 20),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(child: Text('$unreadCount', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Keluar Akun', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    content: Text('Apakah Anda yakin ingin keluar dari akun DiaCareAI Anda?', style: GoogleFonts.inter()),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textGrey, fontWeight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<AuthProvider>().signOut();
                        },
                        child: Text('Keluar', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppTheme.borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatLastLogin(String lastLoginStr) {
    if (lastLoginStr.isEmpty) return 'Kondisi metabolisme Anda stabil.';
    try {
      final dateTime = DateTime.parse(lastLoginStr).toLocal();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return 'Masuk terakhir: $hour:$minute WIB';
    } catch (_) {
      return 'Masuk: Baru saja';
    }
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8), Color(0xFF10B981)], stops: [0.0, 0.7, 1.0]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, bottom: -20, child: Opacity(opacity: 0.1, child: const Icon(Icons.health_and_safety_rounded, size: 160, color: Colors.white))),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text('DiaCare AI Health', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 12),
                      Text('Asisten AI Pintar Untuk Kesehatan Anda', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
                      const SizedBox(height: 6),
                      Text('Dapatkan rekomendasi & prediksi metabolic secara realtime.', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500, height: 1.4)),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showPredictionDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)]),
                          child: Text('Mulai Analisis', style: GoogleFonts.inter(color: AppTheme.primaryBlue, fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)),
                  child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 44),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Menu Akses Cepat', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _buildQuickActionCard(icon: Icons.analytics_rounded, color: AppTheme.primaryBlue, title: 'Cek Risiko AI', subtitle: 'Prediksi diabetes', onTap: _showPredictionDialog),
            _buildQuickActionCard(icon: Icons.bar_chart_rounded, color: const Color(0xFF22C55E), title: 'Riwayat Gula', subtitle: 'Lihat tren grafik', onTap: () => widget.onNavigateToTab(1)),
            _buildQuickActionCard(icon: Icons.contact_page_rounded, color: const Color(0xFFF59E0B), title: 'Profil Medis', subtitle: 'Data kesehatan', onTap: () => widget.onNavigateToTab(2)),
            _buildQuickActionCard(icon: Icons.lightbulb_outline_rounded, color: const Color(0xFFEC4899), title: 'Tips AI', subtitle: 'Rekomendasi harian', onTap: _showHealthAdviceBottomSheet),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withOpacity(0.08),
        highlightColor: color.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
              const SizedBox(height: 8),
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              const SizedBox(height: 1),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textGrey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskCard(SensorData data) {
    double riskProgress = 0.0;
    String riskLabel = 'Tidak Ada Data';
    Color riskColor = AppTheme.textGrey;
    Color badgeBgColor = AppTheme.borderColor;
    Color badgeTextColor = AppTheme.textGrey;
    IconData badgeIcon = Icons.help_outline_rounded;

    if (data.glucose > 0) {
      if (data.glucose <= 100) {
        riskProgress = 0.05 + ((data.glucose / 100) * 0.10); // 5% to 15%
        riskLabel = 'Risiko Rendah';
        riskColor = const Color(0xFF16A34A);
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF166534);
        badgeIcon = Icons.check_circle_rounded;
      } else if (data.glucose <= 140) {
        riskProgress = 0.15 + (((data.glucose - 100) / 40) * 0.10); // 15% to 25%
        riskLabel = 'Risiko Rendah';
        riskColor = const Color(0xFF16A34A);
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF166534);
        badgeIcon = Icons.check_circle_rounded;
      } else if (data.glucose <= 200) {
        riskProgress = 0.30 + (((data.glucose - 140) / 60) * 0.35); // 30% to 65%
        riskLabel = 'Risiko Sedang';
        riskColor = const Color(0xFFD97706);
        badgeBgColor = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFF92400E);
        badgeIcon = Icons.warning_amber_rounded;
      } else {
        riskProgress = 0.70 + (((data.glucose - 200) / 150) * 0.25).clamp(0.0, 0.25); // 70% to 95%
        riskLabel = 'Risiko Tinggi';
        riskColor = const Color(0xFFDC2626);
        badgeBgColor = const Color(0xFFFEE2E2);
        badgeTextColor = const Color(0xFF991B1B);
        badgeIcon = Icons.error_outline_rounded;
      }
    }

    final String desc = data.glucose > 0 
      ? 'Berdasarkan kadar glukosa harian Anda (${data.glucose.toInt()} mg/dL), tingkat risiko metabolik Anda saat ini tergolong $riskLabel.'
      : 'Menghubungkan ke database IoT untuk menganalisis tingkat risiko metabolik harian Anda secara real-time.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 170, height: 170,
            child: CustomPaint(
              painter: _RiskGaugePainter(progress: riskProgress),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.glucose > 0 ? '${(riskProgress * 100).toInt()}%' : '--%', 
                      style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900, color: data.glucose > 0 ? riskColor : AppTheme.textGrey, letterSpacing: -1)
                    ),
                    Text('TINGKAT RISIKO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textGrey, letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: badgeBgColor.withOpacity(0.8))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: riskColor, size: 16),
                const SizedBox(width: 6),
                Text(riskLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: badgeTextColor)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(desc, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textGrey, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(SensorData data) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.water_drop_outlined, 
            iconColor: const Color(0xFF2563EB), 
            label: 'Gula Darah', 
            value: data.glucose > 0 ? data.glucose.toStringAsFixed(0) : '--', 
            unit: 'mg/dL', 
            trend: data.glucose > 0 ? data.glucoseStatus.replaceAll(' (Optimal)', '').replaceAll(' (Hipoglikemia)', '').replaceAll(' (Prediabetes)', '').replaceAll(' (Diabetes)', '') : 'N/A', 
            isPositive: data.glucose >= 70 && data.glucose <= 140
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.thermostat_rounded, 
            iconColor: const Color(0xFFF59E0B), 
            label: 'Suhu Tubuh', 
            value: data.temperature > 0 ? data.temperature.toStringAsFixed(1) : '--', 
            unit: '°C', 
            trend: data.isTemperatureSafe ? 'Normal' : 'Abnormal', 
            isPositive: data.isTemperatureSafe
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.water_drop_rounded, 
            iconColor: const Color(0xFF06B6D4), 
            label: 'Kelembaban', 
            value: data.humidity > 0 ? data.humidity.toStringAsFixed(0) : '--', 
            unit: '%', 
            trend: data.isHumiditySafe ? 'Ideal' : 'Kering', 
            isPositive: data.isHumiditySafe
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({required IconData icon, required Color iconColor, required String label, required String value, required String unit, required String trend, required bool isPositive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: iconColor, size: 14)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label, 
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark, letterSpacing: -0.5)),
              const SizedBox(width: 2),
              Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(unit, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textGrey, fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    trend, 
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: isPositive ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPredictionDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RiskPredictionScreen(),
      ),
    );
  }

  Widget _buildRecentActivitySection(SensorData data, HealthProvider provider) {
    final String liveTime = data.timestamp.isNotEmpty 
      ? _formatTimestamp(data.timestamp).replaceAll('Aktif: ', '') 
      : '--:--';
    final Color liveStatusColor = data.glucose >= 70 && data.glucose <= 140 
      ? const Color(0xFF22C55E) 
      : (data.glucose <= 200 ? AppTheme.primaryBlue : const Color(0xFFEF4444));
    final String liveStatusLabel = data.glucose > 0 
      ? data.glucoseStatus.replaceAll(' (Optimal)', '').replaceAll(' (Hipoglikemia)', '').replaceAll(' (Prediabetes)', '').replaceAll(' (Diabetes)', '') 
      : 'N/A';

    final recentRecords = provider.records.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Aktivitas Terbaru', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
            GestureDetector(onTap: () => widget.onNavigateToTab(1), child: Text('Lihat Semua', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue))),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderColor)),
          child: Column(
            children: [
              _buildTimelineItem(
                time: '$liveTime WIB', 
                glucose: data.glucose > 0 ? '${data.glucose.toInt()} mg/dL' : '-- mg/dL', 
                type: 'Glukosa Real-Time (Sensor IoT)', 
                statusColor: liveStatusColor, 
                statusLabel: liveStatusLabel, 
                isLast: recentRecords.isEmpty
              ),
              ...List.generate(recentRecords.length, (index) {
                final record = recentRecords[index];
                final isLast = index == recentRecords.length - 1;
                
                Color statusColor = record.glucoseStatus == 'Normal' 
                    ? const Color(0xFF22C55E) 
                    : const Color(0xFFEF4444);

                return _buildTimelineItem(
                  time: _formatNotificationDate(record.timestamp), 
                  glucose: '${record.glucoseLevel.toInt()} mg/dL', 
                  type: 'Pencatatan Gula Darah Manual', 
                  statusColor: statusColor, 
                  statusLabel: record.glucoseStatus, 
                  isLast: isLast
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({required String time, required String glucose, required String type, required Color statusColor, required String statusLabel, required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 16),
          Column(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4)])),
            if (!isLast) Expanded(child: Container(width: 2, color: AppTheme.borderColor)),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(glucose, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          statusLabel, 
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(type, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textGrey)),
                Text(time, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textLight)),
                if (!isLast) const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendationsCard(SensorData data, HealthProvider provider) {
    String recommendationText = 'Menunggu data sensor untuk menganalisis metabolisme Anda...';
    
    final latestRecord = provider.latestRecord;
    final avgGlucose = provider.averageGlucose;
    final avgSteps = provider.averageSteps;

    if (data.glucose > 0 && (data.glucose < 70 || data.glucose > 180)) {
      if (data.glucose < 70) {
        recommendationText = 'Peringatan Hipoglikemia Real-Time! Kadar glukosa sensor Anda rendah (${data.glucose.toInt()} mg/dL). Segera konsumsi 15 gram karbohidrat cepat serap (seperti 1/2 gelas jus) dan cek kembali setelah 15 menit.';
      } else {
        recommendationText = 'Peringatan Hiperglikemia Real-Time! Kadar glukosa sensor Anda tinggi (${data.glucose.toInt()} mg/dL). Disarankan minum air putih cukup, batasi karbohidrat olahan, dan hindari olahraga berat jika Anda merasa pusing.';
      }
    } else if (latestRecord != null && (latestRecord.glucoseLevel < 70 || latestRecord.glucoseLevel > 140)) {
      if (latestRecord.glucoseLevel < 70) {
        recommendationText = 'Catatan manual terakhir Anda menunjukkan glukosa rendah (${latestRecord.glucoseLevel.toInt()} mg/dL). AI menganjurkan Anda untuk selalu membawa camilan sehat dan berkonsultasi dengan dokter mengenai pola obat Anda.';
      } else {
        recommendationText = 'Catatan glukosa manual terakhir Anda cukup tinggi (${latestRecord.glucoseLevel.toInt()} mg/dL). AI menyarankan untuk menjaga porsi makan seimbang, memilih serat tinggi, dan melakukan jalan kaki santai setelah makan.';
      }
    } else if (avgGlucose > 130) {
      recommendationText = 'Analisis Tren AI: Rata-rata gula darah Anda cenderung tinggi (${avgGlucose.toStringAsFixed(0)} mg/dL) akhir-akhir ini. Disarankan untuk memantau asupan kalori harian Anda dan meningkatkan intensitas aktivitas fisik harian.';
    } else if (avgSteps > 0 && avgSteps < 6000) {
      recommendationText = 'Analisis Aktivitas AI: Rata-rata langkah harian Anda (${avgSteps.toStringAsFixed(0)} langkah) masih di bawah target optimal. Tingkatkan aktivitas berjalan kaki harian untuk membantu meningkatkan sensitivitas insulin.';
    } else {
      recommendationText = 'Metabolisme Anda terpantau stabil ${avgGlucose > 0 ? '(Rerata: ${avgGlucose.toStringAsFixed(0)} mg/dL)' : ''}. AI merekomendasikan untuk mempertahankan gaya hidup sehat saat ini, konsisten berolahraga, dan menjaga pola makan.';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryBlue, size: 18)),
              const SizedBox(width: 8),
              Text('Rekomendasi AI Hari Ini', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue)),
            ]),
            const SizedBox(height: 10),
            Text(recommendationText, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textDark, height: 1.4)),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _showHealthAdviceBottomSheet,
              child: Row(children: [
                Text('Lihat Tips Selengkapnya', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryBlue, size: 14),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for the risk gauge
class _RiskGaugePainter extends CustomPainter {
  final double progress;

  _RiskGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    const strokeWidth = 12.0;
    const startAngle = -math.pi * 0.8;
    const sweepAngle = math.pi * 1.6;

    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );

    // Dot at end of progress
    final angle = startAngle + sweepAngle * progress;
    final dotX = center.dx + radius * math.cos(angle);
    final dotY = center.dy + radius * math.sin(angle);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(dotX, dotY), 8, dotBorderPaint);
    canvas.drawCircle(Offset(dotX, dotY), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LivePulseIndicator extends StatefulWidget {
  const _LivePulseIndicator();

  @override
  State<_LivePulseIndicator> createState() => _LivePulseIndicatorState();
}

class _LivePulseIndicatorState extends State<_LivePulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(
        Tween<double>(begin: 0.3, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF22C55E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xFF22C55E),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
