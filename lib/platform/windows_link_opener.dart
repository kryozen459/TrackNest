import 'dart:io';

Future<bool> openExternalUrl(Uri url) async {
  if (url.scheme != 'https' || url.host.isEmpty) return false;

  try {
    await Process.start('explorer.exe', [
      url.toString(),
    ], mode: ProcessStartMode.detached);
    return true;
  } on ProcessException {
    return false;
  }
}
