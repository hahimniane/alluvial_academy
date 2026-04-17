import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Shows invoice PDF: web keeps the print/preview dialog; native uses the
/// share sheet so we avoid the Printing preview WebView hanging on mobile.
Future<void> presentInvoicePdfBytes({
  required Uint8List bytes,
  required String filename,
}) async {
  if (kIsWeb) {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
    );
  } else {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
