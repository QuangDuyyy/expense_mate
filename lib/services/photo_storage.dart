import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoStorage {
  Future<String> keep(String source) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = await Directory(p.join(root.path, 'receipts'))
        .create(recursive: true);
    final destination = p.join(
      folder.path,
      '${DateTime.now().microsecondsSinceEpoch}${p.extension(source)}',
    );
    await File(source).copy(destination);
    return destination;
  }

  Future<void> remove(String? path) async {
    if (path == null) return;
    final root = await getApplicationDocumentsDirectory();
    final folder = p.join(root.path, 'receipts');
    if (!p.isWithin(folder, path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
