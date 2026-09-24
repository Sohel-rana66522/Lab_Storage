import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String toCsv(List<String> headers, List<List<String>> rows) {
  String esc(String v) => (v.contains(',') || v.contains('"') || v.contains('\n'))
      ? '"${v.replaceAll('"', '""')}"'
      : v;
  final b = StringBuffer()..writeln(headers.map(esc).join(','));
  for (final r in rows) {
    b.writeln(r.map(esc).join(','));
  }
  return b.toString();
}

Future<void> copyCsv(BuildContext context, String csv, {String label = 'CSV'}) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: csv));
  messenger.showSnackBar(
      SnackBar(content: Text('$label copied to clipboard. Paste it into Excel or Sheets.')));
}
