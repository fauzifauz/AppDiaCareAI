import 'package:flutter/foundation.dart';

class TflitePredictionService {
  static final TflitePredictionService _instance = TflitePredictionService._internal();
  factory TflitePredictionService() => _instance;
  TflitePredictionService._internal();

  bool get isModelLoaded => false;

  /// Memuat file model (tidak didukung di Web).
  Future<void> initModel() async {
    debugPrint('TflitePredictionService (Stub): TensorFlow Lite is not supported on Web. Bypassing initialization.');
  }

  /// Memperbarui nilai StandardScaler (tidak didukung di Web).
  void updateScalerCoefficients(List<double> mean, List<double> std) {}

  /// Menjalankan prediksi (melempar UnsupportedError untuk memicu fallback di UI).
  Map<String, dynamic> predict({
    required String gender,
    required double age,
    required bool hypertension,
    required bool heartDisease,
    required String smokingHistory,
    required double bmi,
    required double hba1c,
    required double glucose,
  }) {
    throw UnsupportedError('TensorFlow Lite is not supported on Web.');
  }

  /// Menutup interpreter.
  void dispose() {}
}
