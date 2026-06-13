import 'package:url_launcher/url_launcher.dart';

Future<void> downloadFileImpl(String url, String fileName) async {
  final rawUrl = url
      .replaceFirst('github.com', 'raw.githubusercontent.com')
      .replaceFirst('/blob/', '/');
      
  final Uri uri = Uri.parse(rawUrl);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
