import 'package:sqflite/sqflite.dart' show DatabaseException;

import '../database/app_database.dart';
import '../models/transaction.dart';

class DuplicateOrderIdException implements Exception {
  const DuplicateOrderIdException(this.orderId);
  final String orderId;
}

class TransactionRepository {
  TransactionRepository(this._database);
  final AppDatabase _database;

  Future<int> insertTransaction(Transaction transaction) async {
    try {
      final database = await _database.database;
      final values = Map<String, Object?>.from(transaction.toMap())..remove('id');
      return await database.insert('transactions', values);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw DuplicateOrderIdException(transaction.orderId);
      rethrow;
    }
  }
}
