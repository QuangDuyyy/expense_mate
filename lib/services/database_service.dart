import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class DatabaseService {
  Database? _database;
  Future<Database> get database async {
    return _database ??= await openDatabase(
      p.join(await getDatabasesPath(), 'expense_mate.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          merchant TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount > 0),
          date TEXT NOT NULL, category TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '', image_path TEXT,
          raw_text TEXT NOT NULL DEFAULT '', receipt_details TEXT
        )
      ''');
        await _createRestoreTable(db);
      },
      onOpen: (db) async {
        await _createRestoreTable(db);
        final columns = await db.rawQuery('PRAGMA table_info(expenses)');
        if (!columns.any((c) => c['name'] == 'receipt_details')) {
          await db.execute(
            'ALTER TABLE expenses ADD COLUMN receipt_details TEXT',
          );
        }
      },
    );
  }

  static Future<void> _createRestoreTable(Database db) => db.execute(
    'CREATE TABLE IF NOT EXISTS restored_items (origin TEXT NOT NULL, original_id INTEGER NOT NULL, PRIMARY KEY(origin, original_id))',
  );

  Future<int> restore(
    String origin,
    String currentOrigin,
    List<Map<String, Object?>> records,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      var added = 0;
      for (final record in records) {
        final originalId = record['id'] as int;
        final seen = await txn.query(
          'restored_items',
          where: 'origin = ? AND original_id = ?',
          whereArgs: [origin, originalId],
        );
        if (seen.isNotEmpty) continue;
        if (origin == currentOrigin) {
          final native = await txn.query(
            'expenses',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [originalId],
          );
          if (native.isNotEmpty) continue;
        }
        final row = Map<String, Object?>.from(record)..remove('id');
        await txn.insert('expenses', row);
        await txn.insert('restored_items', {
          'origin': origin,
          'original_id': originalId,
        });
        added++;
      }
      return added;
    });
  }

  Future<bool> wasRestored(String origin, String currentOrigin, int id) async {
    final db = await database;
    final seen = await db.query(
      'restored_items',
      where: 'origin = ? AND original_id = ?',
      whereArgs: [origin, id],
    );
    if (seen.isNotEmpty) return true;
    return origin == currentOrigin &&
        (await db.query(
          'expenses',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
        )).isNotEmpty;
  }

  Future<List<Expense>> all() async {
    final rows = await (await database).query(
      'expenses',
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<void> save(Expense item) async {
    final db = await database;
    if (item.id == null) {
      await db.insert('expenses', item.toMap());
    } else {
      await db.update(
        'expenses',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
  }

  Future<void> delete(int id) async {
    await (await database).delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
