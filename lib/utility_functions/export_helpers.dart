import 'dart:convert';
import 'dart:html' as html;
import 'package:csv/csv.dart';

void exportData(
    List<String> headers, List<List<String>> data, String fileName) {
  List<List<String>> csvData = [
    headers,
    ...data,
  ];

  String csv = const ListToCsvConverter().convert(csvData);

  // Create a Blob
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes]);

  // Create a link element
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
