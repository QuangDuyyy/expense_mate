import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_layout.dart';

class OcrService {
  Future<String> recognize(String path) async =>
      (await recognizeDocument(path)).text;
  Future<ReceiptDocument> recognizeDocument(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      final lines = <ReceiptLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final b = line.boundingBox;
          lines.add(ReceiptLine(line.text, b.left, b.top, b.right, b.bottom));
        }
      }
      return lines.isEmpty
          ? ReceiptDocument(
              result.text,
              ReceiptDocument.parseItems(result.text),
            )
          : ReceiptDocument.fromLines(lines);
    } finally {
      await recognizer.close();
    }
  }
}
