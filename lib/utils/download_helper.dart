import 'download_helper_non_web.dart'
    if (dart.library.html) 'download_helper_web.dart';

class DownloadHelper {
  static Future<void> downloadFile(String url, String fileName) async {
    await downloadFileImpl(url, fileName);
  }
}
