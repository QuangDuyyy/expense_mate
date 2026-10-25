import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../services/database_service.dart';
import '../services/photo_storage.dart';

class ExpenseStore extends ChangeNotifier {
  final DatabaseService _database;
  ExpenseStore(this._database);
  List<Expense> _items = [];
  List<Expense> get items => List.unmodifiable(_items);
  bool loading = false;
  String? error;
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _items = await _database.all();
    } catch (_) {
      error = 'Không đọc được dữ liệu. Hãy thử lại.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save(Expense item) async {
    await _database.save(item);
    await load();
  }

  Future<void> delete(Expense item) async {
    await _database.delete(item.id!);
    // A photo cleanup failure must not undo a successful database deletion.
    try {
      await PhotoStorage().remove(item.imagePath);
    } catch (_) {
      /* retry cleanup later */
    }
    await load();
  }
}
