import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TflitePredictionService {
  static final TflitePredictionService _instance = TflitePredictionService._internal();
  factory TflitePredictionService() => _instance;
  TflitePredictionService._internal();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Koefisien normalisasi StandardScaler dari training model.
  List<double> _scalerMean = [0.417507, 41.760982, 0.078007, 0.040876, 2.232136, 27.313739, 5.530527, 138.114281];
  List<double> _scalerStd = [0.493517, 22.467616, 0.268183, 0.198002, 1.880222, 6.757163, 1.072414, 40.896643];

  bool get isModelLoaded => _isModelLoaded;

  /// Memuat file model TensorFlow Lite dari assets.
  Future<void> initModel() async {
    if (_isModelLoaded) return;
    try {
      final options = InterpreterOptions()..threads = 4;
      
      _interpreter = await Interpreter.fromAsset(
        'assets/models/diacare_model.tflite',
        options: options,
      );
      _isModelLoaded = true;
      debugPrint('TflitePredictionService: Model TFLite berhasil dimuat.');
    } catch (e) {
      debugPrint('TflitePredictionService: Gagal memuat model TFLite: $e');
    }
  }

  /// Memperbarui nilai StandardScaler secara dinamis berdasarkan cetakan Python
  void updateScalerCoefficients(List<double> mean, List<double> std) {
    if (mean.length == 8 && std.length == 8) {
      _scalerMean = mean;
      _scalerStd = std;
      debugPrint('TflitePredictionService: Scaler coefficients updated.');
    }
  }

  /// Menjalankan inferensi real-time untuk probabilitas risiko dan kontribusi SHAP.
  /// Mengembalikan Map dengan 'riskPercentage' dan 'shapValues'.
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
    if (!_isModelLoaded || _interpreter == null) {
      throw Exception('Model TFLite belum dimuat. Panggil initModel() terlebih dahulu.');
    }

    // 1. Encoding data kategorikal (wajib sama persis dengan train_tflite.py)
    double genderVal = 0.0; // Default Female
    if (gender == 'Male') {
      genderVal = 1.0;
    } else if (gender == 'Other') {
      genderVal = 2.0;
    }

    double smokingVal = 0.0; // Default No Info
    switch (smokingHistory.toLowerCase()) {
      case 'current':
        smokingVal = 1.0;
        break;
      case 'ever':
        smokingVal = 2.0;
        break;
      case 'former':
        smokingVal = 3.0;
        break;
      case 'never':
        smokingVal = 4.0;
        break;
      case 'not current':
        smokingVal = 5.0;
        break;
    }

    double hyperVal = hypertension ? 1.0 : 0.0;
    double heartVal = heartDisease ? 1.0 : 0.0;

    // 2. Menyusun array input mentah sesuai urutan kolom fitur Python
    List<double> rawInput = [
      genderVal,
      age,
      hyperVal,
      heartVal,
      smokingVal,
      bmi,
      hba1c,
      glucose,
    ];

    // 3. Normalisasi Fitur menggunakan StandardScaler (z = (x - mean) / std)
    List<double> scaledInput = List.generate(8, (i) {
      return (rawInput[i] - _scalerMean[i]) / _scalerStd[i];
    });

    // Format input tensor dengan shape [1, 8]
    var inputTensor = [scaledInput];

    // 4. Mempersiapkan buffer untuk Multi-Head Output
    var riskOutput = List<double>.filled(1, 0.0).reshape([1, 1]);
    var shapOutput = List<double>.filled(8, 0.0).reshape([1, 8]);

    var outputs = {
      0: shapOutput,
      1: riskOutput,
    };

    // 5. Jalankan inferensi model
    _interpreter!.runForMultipleInputs([inputTensor], outputs);

    // Ambil hasil
    double riskProb = (outputs[1] as List<List<double>>)[0][0] * 100.0; // Ubah probabilitas ke persen (0-100)
    List<double> shapValues = (outputs[0] as List<List<double>>)[0];

    // Menjaga batas persen yang wajar di UI
    if (riskProb < 1.0) riskProb = 1.0;
    if (riskProb > 99.0) riskProb = 99.0;

    return {
      'riskPercentage': double.parse(riskProb.toStringAsFixed(1)),
      'shapValues': shapValues,
    };
  }

  /// Menutup interpreter untuk melepas memori.
  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
    debugPrint('TflitePredictionService: Model closed.');
  }
}
