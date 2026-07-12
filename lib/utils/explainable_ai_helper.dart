import 'package:flutter/material.dart';
import '../models/risk_prediction.dart';

class ExplainableAiHelper {
  /// Memetakan SHAP values mentah dari model TFLite (urutan indeks 0-7) ke dalam representasi UI
  static List<FeatureContribution> mapRawShapToContributions({
    required List<double> rawShapValues,
    required double risk,
    required String? gender,
    required double age,
    required String? hypertension,
    required String? heartDisease,
    required String? smokingHistory,
    required double bmi,
    required double hba1c,
    required double glucose,
  }) {
    if (rawShapValues.length < 8) {
      // Fallback jika panjang array tidak sesuai
      return calculateContributions(
        risk: risk,
        gender: gender,
        age: age,
        hypertension: hypertension,
        heartDisease: heartDisease,
        smokingHistory: smokingHistory,
        bmi: bmi,
        hba1c: hba1c,
        glucose: glucose,
      );
    }

    // Definisi metadata untuk ke-8 fitur berdasarkan urutan kolom input model
    final List<Map<String, dynamic>> featuresMeta = [
      {
        'name': 'Jenis Kelamin',
        'valueText': gender ?? 'Female',
        'icon': Icons.person_rounded,
        'desc': 'Pengaruh biologis hormonal terhadap metabolisme tubuh.',
        'highDesc': 'Faktor biologis gender memberikan pengaruh minor pendorong risiko.',
        'lowDesc': 'Faktor biologis gender memberikan pengaruh protektif alami.',
      },
      {
        'name': 'Faktor Usia',
        'valueText': '${age.toStringAsFixed(0)} Tahun',
        'icon': Icons.calendar_month_rounded,
        'desc': 'Usia kronologis pasien.',
        'highDesc': 'Pertambahan usia secara alami menurunkan efisiensi sekresi insulin.',
        'lowDesc': 'Usia muda diasosiasikan dengan metabolisme aktif & fungsi sel beta sehat.',
      },
      {
        'name': 'Tekanan Darah Tinggi',
        'valueText': hypertension ?? 'Tidak',
        'icon': Icons.speed_rounded,
        'desc': 'Riwayat hipertensi medis.',
        'highDesc': 'Hipertensi merusak pembuluh darah mikro dan mempercepat resistensi insulin.',
        'lowDesc': 'Tekanan darah normal membantu regulasi pembuluh darah tetap optimal.',
      },
      {
        'name': 'Penyakit Jantung',
        'valueText': heartDisease ?? 'Tidak',
        'icon': Icons.favorite_rounded,
        'desc': 'Riwayat gangguan kardiovaskular.',
        'highDesc': 'Kerusakan pembuluh koroner memperburuk respon glukosa metabolik.',
        'lowDesc': 'Ketiadaan riwayat penyakit jantung mengurangi risiko komplikasi sistemik.',
      },
      {
        'name': 'Riwayat Merokok',
        'valueText': smokingHistory ?? 'No Info',
        'icon': Icons.smoking_rooms_rounded,
        'desc': 'Status konsumsi nikotin.',
        'highDesc': 'Toksin rokok meningkatkan stres oksidatif sel tubuh dan merusak pankreas.',
        'lowDesc': 'Bebas dari paparan asap rokok melindungi sel beta dari kerusakan radikal bebas.',
      },
      {
        'name': 'Indeks Massa Tubuh',
        'valueText': '${bmi.toStringAsFixed(1)} BMI',
        'icon': Icons.monitor_weight_rounded,
        'desc': 'Rasio berat badan terhadap tinggi.',
        'highDesc': 'Penumpukan lemak viseral menghambat penyerapan glukosa oleh insulin.',
        'lowDesc': 'BMI ideal menjaga sensitivitas reseptor insulin sel tubuh.',
      },
      {
        'name': 'Kadar HbA1c',
        'valueText': '${hba1c.toStringAsFixed(1)}%',
        'icon': Icons.water_drop_rounded,
        'desc': 'Rata-rata glukosa darah 3 bulan terakhir.',
        'highDesc': 'Kadar HbA1c tinggi menunjukkan paparan hiperglikemia kronis jangka panjang.',
        'lowDesc': 'HbA1c dalam rentang normal adalah indikator utama regulasi gula darah terkendali.',
      },
      {
        'name': 'Glukosa Darah',
        'valueText': '${glucose.toStringAsFixed(0)} mg/dL',
        'icon': Icons.bloodtype_rounded,
        'desc': 'Kadar glukosa darah saat pengujian.',
        'highDesc': 'Lonjakan glukosa akut menunjukkan kegagalan respon insulin segera.',
        'lowDesc': 'Kadar glukosa darah terkontrol melindungi sel dari efek glukotoksisitas.',
      },
    ];

    double sumPositive = 0;
    double sumNegative = 0;
    for (double w in rawShapValues) {
      if (w > 0) {
        sumPositive += w;
      } else {
        sumNegative += w.abs();
      }
    }

    const double baseValue = 10.0;
    double targetDiff = risk - baseValue;

    List<FeatureContribution> contributions = [];

    for (int i = 0; i < 8; i++) {
      double w = rawShapValues[i];
      double scaledPercentage = 0;
      if (targetDiff >= 0) {
        final factorNegative = (100.0 - risk) / (100.0 - baseValue);
        if (w > 0) {
          final sumNegativeNew = -sumNegative * factorNegative;
          final sumPositiveNew = targetDiff - sumNegativeNew;
          scaledPercentage = sumPositive > 0 ? w * sumPositiveNew / sumPositive : 0;
        } else {
          scaledPercentage = w * factorNegative;
        }
      } else {
        final factorPositive = risk / baseValue;
        if (w < 0) {
          final sumPositiveNew = sumPositive * factorPositive;
          final sumNegativeNew = targetDiff - sumPositiveNew;
          scaledPercentage = sumNegative > 0 ? w * sumNegativeNew / (-sumNegative) : 0;
        } else {
          scaledPercentage = w * factorPositive;
        }
      }

      if (scaledPercentage > 45.0) scaledPercentage = 45.0;
      if (scaledPercentage < -25.0) scaledPercentage = -25.0;

      contributions.add(
        FeatureContribution(
          name: featuresMeta[i]['name'] as String,
          valueText: featuresMeta[i]['valueText'] as String,
          contributionPercentage: scaledPercentage,
          icon: featuresMeta[i]['icon'] as IconData,
          description: featuresMeta[i]['desc'] as String,
          impactMessage: scaledPercentage >= 0 
              ? featuresMeta[i]['highDesc'] as String 
              : featuresMeta[i]['lowDesc'] as String,
        ),
      );
    }

    contributions.sort((a, b) => b.contributionPercentage.compareTo(a.contributionPercentage));
    return contributions;
  }

  /// Metode simulasi heuristik lama (dijaga sebagai fallback)
  static List<FeatureContribution> calculateContributions({
    required double risk,
    required String? gender,
    required double age,
    required String? hypertension,
    required String? heartDisease,
    required String? smokingHistory,
    required double bmi,
    required double hba1c,
    required double glucose,
  }) {
    const double baseValue = 10.0; // Base population risk
    
    // 1. Calculate raw heuristic weights for each input feature
    double wHbA1c = 0;
    if (hba1c >= 6.5) {
      wHbA1c = 30.0;
    } else if (hba1c >= 5.7) {
      wHbA1c = 15.0;
    } else {
      wHbA1c = -5.0; // Protective factor
    }

    double wGlucose = 0;
    if (glucose >= 200) {
      wGlucose = 25.0;
    } else if (glucose >= 140) {
      wGlucose = 15.0;
    } else if (glucose >= 100) {
      wGlucose = 5.0;
    } else {
      wGlucose = -3.5;
    }

    double wBmi = 0;
    if (bmi >= 30) {
      wBmi = 15.0;
    } else if (bmi >= 25) {
      wBmi = 8.0;
    } else if (bmi < 18.5) {
      wBmi = 2.0;
    } else {
      wBmi = -4.0;
    }

    double wHypertension = (hypertension == 'Ya') ? 12.0 : -2.0;
    double wHeartDisease = (heartDisease == 'Ya') ? 10.0 : -1.5;
    
    // Age weight based on baseline age of 35
    double wAge = (age * 0.22) - 7.5; 

    double wSmoking = 0;
    if (smokingHistory == 'Current' || smokingHistory == 'Ever') {
      wSmoking = 6.0;
    } else if (smokingHistory == 'Former' || smokingHistory == 'Not Current') {
      wSmoking = 3.0;
    } else {
      wSmoking = -1.0;
    }

    double wGender = (gender == 'Male') ? 1.0 : -0.5;

    // 2. Normalize weights so they perfectly sum to (risk - baseValue)
    final List<Map<String, dynamic>> rawFeatures = [
      {
        'name': 'Kadar HbA1c',
        'valueText': '${hba1c.toStringAsFixed(1)}%',
        'rawWeight': wHbA1c,
        'icon': Icons.water_drop_rounded,
        'desc': 'Rata-rata gula darah 3 bulan terakhir.',
        'highDesc': 'Kadar HbA1c Anda tinggi (>= 5.7%), yang merupakan indikator utama prediabetes/diabetes.',
        'lowDesc': 'Kadar HbA1c Anda berada dalam rentang optimal (< 5.7%), menekan risiko diabetes.',
      },
      {
        'name': 'Glukosa Darah',
        'valueText': '${glucose.toStringAsFixed(0)} mg/dL',
        'rawWeight': wGlucose,
        'icon': Icons.bloodtype_rounded,
        'desc': 'Kadar glukosa darah saat tes.',
        'highDesc': 'Glukosa darah di atas normal meningkatkan beban kerja pankreas dan sensitivitas insulin.',
        'lowDesc': 'Glukosa darah Anda normal (< 100 mg/dL), indikasi regulasi gula darah yang sehat.',
      },
      {
        'name': 'Indeks Massa Tubuh',
        'valueText': '${bmi.toStringAsFixed(1)} BMI',
        'rawWeight': wBmi,
        'icon': Icons.monitor_weight_rounded,
        'desc': 'Rasio berat badan terhadap tinggi badan.',
        'highDesc': 'BMI tinggi (>= 25) memicu penumpukan lemak visceral dan memicu resistensi insulin.',
        'lowDesc': 'BMI Anda ideal (18.5 - 24.9), mendukung fungsi metabolisme sel tubuh yang optimal.',
      },
      {
        'name': 'Tekanan Darah Tinggi',
        'valueText': hypertension ?? 'Tidak',
        'rawWeight': wHypertension,
        'icon': Icons.speed_rounded,
        'desc': 'Riwayat hipertensi medis.',
        'highDesc': 'Tekanan darah tinggi merusak pembuluh darah kecil dan berkaitan dengan sindrom metabolik.',
        'lowDesc': 'Tidak memiliki riwayat hipertensi membantu menjaga sirkulasi dan kesehatan vaskular.',
      },
      {
        'name': 'Penyakit Jantung',
        'valueText': heartDisease ?? 'Tidak',
        'rawWeight': wHeartDisease,
        'icon': Icons.favorite_rounded,
        'desc': 'Riwayat penyakit kardiovaskular.',
        'highDesc': 'Penyakit jantung berkolerasi dengan gangguan metabolik sistemik secara keseluruhan.',
        'lowDesc': 'Ketiadaan riwayat penyakit jantung mengurangi kemungkinan komplikasi kardiovaskular.',
      },
      {
        'name': 'Faktor Usia',
        'valueText': '${age.toStringAsFixed(0)} Tahun',
        'rawWeight': wAge,
        'icon': Icons.calendar_month_rounded,
        'desc': 'Usia kronologis pasien.',
        'highDesc': 'Pertambahan usia meningkatkan risiko diabetes akibat penurunan alami fungsi pankreas.',
        'lowDesc': 'Usia muda diasosiasikan dengan cadangan fungsi pankreas yang lebih sehat dan aktif.',
      },
      {
        'name': 'Riwayat Merokok',
        'valueText': smokingHistory ?? 'No Info',
        'rawWeight': wSmoking,
        'icon': Icons.smoking_rooms_rounded,
        'desc': 'Status konsumsi tembakau.',
        'highDesc': 'Zat beracun pada rokok memicu inflamasi kronis dan menurunkan sensitivitas reseptor insulin.',
        'lowDesc': 'Tidak memiliki kebiasaan merokok melindungi sel-sel tubuh dari stres oksidatif.',
      },
      {
        'name': 'Jenis Kelamin',
        'valueText': gender ?? 'Other',
        'rawWeight': wGender,
        'icon': Icons.person_rounded,
        'desc': 'Pengaruh hormonal & genetika.',
        'highDesc': 'Faktor biologis gender memberikan sedikit pengaruh tambahan pada metabolisme tubuh.',
        'lowDesc': 'Profil hormon gender memberikan perlindungan alami minor terhadap resistensi insulin.',
      },
    ];

    double sumPositive = 0;
    double sumNegative = 0;
    for (var f in rawFeatures) {
      double w = f['rawWeight'] as double;
      if (w > 0) {
        sumPositive += w;
      } else {
        sumNegative += w.abs();
      }
    }

    double targetDiff = risk - baseValue;
    
    // Scale contributions to align perfectly with computed risk
    List<FeatureContribution> contributions = [];
    for (var f in rawFeatures) {
      double w = f['rawWeight'] as double;
      double scaledWeight = 0;
      if (targetDiff >= 0) {
        final factorNegative = (100.0 - risk) / (100.0 - baseValue);
        if (w > 0) {
          final sumNegativeNew = -sumNegative * factorNegative;
          final sumPositiveNew = targetDiff - sumNegativeNew;
          scaledWeight = sumPositive > 0 ? w * sumPositiveNew / sumPositive : 0;
        } else {
          scaledWeight = w * factorNegative;
        }
      } else {
        final factorPositive = risk / baseValue;
        if (w < 0) {
          final sumPositiveNew = sumPositive * factorPositive;
          final sumNegativeNew = targetDiff - sumPositiveNew;
          scaledWeight = sumNegative > 0 ? w * sumNegativeNew / (-sumNegative) : 0;
        } else {
          scaledWeight = w * factorPositive;
        }
      }

      if (scaledWeight > 45.0) scaledWeight = 45.0;
      if (scaledWeight < -20.0) scaledWeight = -20.0;

      contributions.add(
        FeatureContribution(
          name: f['name'] as String,
          valueText: f['valueText'] as String,
          contributionPercentage: scaledWeight,
          icon: f['icon'] as IconData,
          description: f['desc'] as String,
          impactMessage: scaledWeight >= 0 ? f['highDesc'] as String : f['lowDesc'] as String,
        ),
      );
    }

    contributions.sort((a, b) => b.contributionPercentage.compareTo(a.contributionPercentage));
    return contributions;
  }
}

