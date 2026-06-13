// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> downloadFileImpl(String url, String fileName) async {
  final rawUrl = url
      .replaceFirst('github.com', 'raw.githubusercontent.com')
      .replaceFirst('/blob/', '/');

  try {
    final response = await html.HttpRequest.request(rawUrl, responseType: 'blob');
    final blob = response.response as html.Blob;
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: objectUrl)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();

    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(objectUrl);
  } catch (e) {
    // Fallback: open raw URL in new window if download fails
    html.window.open(rawUrl, '_blank');
  }
}
