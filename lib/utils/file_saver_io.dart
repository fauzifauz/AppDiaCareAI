import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> saveJsonFile(
  String content,
  String fileName, {
  required void Function(String path) onSuccess,
  required void Function(Object error) onError,
}) async {
  try {
    Directory? dir;
    
    if (Platform.isAndroid) {
      // 1. Try public Download folder
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        try {
          final testFile = File('${publicDownload.path}/.test_write');
          await testFile.writeAsString('test');
          await testFile.delete();
          dir = publicDownload;
        } catch (_) {
          // Permission denied, fallback
        }
      }
      
      // 2. Fallback to path_provider's getDownloadsDirectory
      if (dir == null) {
        try {
          dir = await getDownloadsDirectory();
        } catch (_) {}
      }
      
      // 3. Fallback to external files directory (always accessible without permission dialog)
      if (dir == null) {
        try {
          dir = await getExternalStorageDirectory();
        } catch (_) {}
      }
    } else if (Platform.isIOS) {
      // On iOS, use the application documents directory
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {}
    }

    dir ??= await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    onSuccess(file.path);
  } catch (e) {
    onError(e);
  }
}
