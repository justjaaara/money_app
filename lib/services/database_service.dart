import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/local/app_database.dart';
import '../models/transaction_model.dart' as model;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal()
    : _database = AppDatabase(),
      _firestore = FirebaseFirestore.instance,
      _connectivity = Connectivity() {
    debugPrint('[MoneyApp][DB] DatabaseService initialized');
    debugPrint('[MoneyApp][DB] Firestore.instance.app=${_firestore.app.name}');
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      if (_isOnlineResult(result)) {
        unawaited(syncPendingTransactions());
      }
    });
  }

  final AppDatabase _database;
  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> addTransaction(model.Transaction transaction) async {
    debugPrint(
      '[MoneyApp][DB] addTransaction local start: ${transaction.id} ${transaction.title}',
    );
    await _database
        .into(_database.transactions)
        .insertOnConflictUpdate(
          TransactionsCompanion.insert(
            id: transaction.id,
            title: transaction.title,
            amount: transaction.amount,
            type: transaction.type,
            date: transaction.date,
            category: Value(transaction.category),
            description: Value(transaction.description),
            syncedWithFirebase: const Value(false),
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt,
          ),
        );
    debugPrint('[MoneyApp][DB] addTransaction local saved: ${transaction.id}');

    unawaited(_syncTransactionIfOnline(transaction));
  }

  Future<List<model.Transaction>> getAllTransactions() async {
    final rows = await _database.select(_database.transactions).get();
    final pendingDeletionIds = await _pendingDeletionIds();
    return rows
        .where((row) => !pendingDeletionIds.contains(row.id))
        .map(_mapRowToModel)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<model.Transaction>> getTransactionsByType(
    model.TransactionType type,
  ) async {
    final rows = await (_database.select(
      _database.transactions,
    )..where((tbl) => tbl.type.equals(type.name))).get();
    final pendingDeletionIds = await _pendingDeletionIds();
    return rows
        .where((row) => !pendingDeletionIds.contains(row.id))
        .map(_mapRowToModel)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<model.Transaction>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rows =
        await (_database.select(_database.transactions)..where(
              (tbl) =>
                  tbl.date.isBiggerOrEqualValue(startDate) &
                  tbl.date.isSmallerOrEqualValue(endDate),
            ))
            .get();
    final pendingDeletionIds = await _pendingDeletionIds();
    return rows
        .where((row) => !pendingDeletionIds.contains(row.id))
        .map(_mapRowToModel)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<model.Transaction?> getTransactionById(String id) async {
    final row = await (_database.select(
      _database.transactions,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final pendingDeletionIds = await _pendingDeletionIds();
    if (pendingDeletionIds.contains(id)) return null;
    return _mapRowToModel(row);
  }

  Future<int> updateTransaction(model.Transaction transaction) async {
    final count =
        await (_database.update(
          _database.transactions,
        )..where((tbl) => tbl.id.equals(transaction.id))).write(
          TransactionsCompanion(
            title: Value(transaction.title),
            amount: Value(transaction.amount),
            type: Value(transaction.type),
            date: Value(transaction.date),
            category: Value(transaction.category),
            description: Value(transaction.description),
            syncedWithFirebase: const Value(false),
            createdAt: Value(transaction.createdAt),
            updatedAt: Value(transaction.updatedAt),
          ),
        );

    if (count > 0) {
      unawaited(
        _syncTransactionIfOnline(
          transaction.copyWith(syncedWithFirebase: false),
        ),
      );
    }

    return count;
  }

  Future<int> deleteTransaction(String id) async {
    final isOnline = await _isOnline();
    if (isOnline) {
      await _deleteRemote(id);
      await (_database.delete(
        _database.transactions,
      )..where((tbl) => tbl.id.equals(id))).go();
      await (_database.delete(
        _database.pendingDeletions,
      )..where((tbl) => tbl.transactionId.equals(id))).go();
      return 1;
    }

    await _database
        .into(_database.pendingDeletions)
        .insertOnConflictUpdate(
          PendingDeletionsCompanion.insert(transactionId: id),
        );
    return 1;
  }

  Future<List<model.Transaction>> getUnsyncedTransactions() async {
    final rows = await (_database.select(
      _database.transactions,
    )..where((tbl) => tbl.syncedWithFirebase.equals(false))).get();
    final pendingDeletionIds = await _pendingDeletionIds();
    return rows
        .where((row) => !pendingDeletionIds.contains(row.id))
        .map(_mapRowToModel)
        .toList();
  }

  Future<int> markAsSynced(String id) async {
    return (_database.update(
      _database.transactions,
    )..where((tbl) => tbl.id.equals(id))).write(
      TransactionsCompanion(
        syncedWithFirebase: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteAllTransactions() async {
    await _database.delete(_database.pendingDeletions).go();
    return _database.delete(_database.transactions).go();
  }

  Future<double> getTotalBalance() async {
    final rows = await getAllTransactions();
    var income = 0.0;
    var expense = 0.0;

    for (final transaction in rows) {
      if (transaction.type == model.TransactionType.income) {
        income += transaction.amount;
      } else {
        expense += transaction.amount;
      }
    }

    return income - expense;
  }

  Future<Map<String, double>> getTotals(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rows = await getTransactionsByDateRange(startDate, endDate);
    var income = 0.0;
    var expense = 0.0;

    for (final transaction in rows) {
      if (transaction.type == model.TransactionType.income) {
        income += transaction.amount;
      } else {
        expense += transaction.amount;
      }
    }

    return {'income': income, 'expense': expense};
  }

  Future<void> syncPendingTransactions() async {
    final online = await _isOnline();
    debugPrint('[MoneyApp][DB] syncPendingTransactions online=$online');
    if (!online) return;

    final unsyncedTransactions = await getUnsyncedTransactions();
    debugPrint(
      '[MoneyApp][DB] syncPendingTransactions unsynced=${unsyncedTransactions.length}',
    );
    for (final transaction in unsyncedTransactions) {
      await _pushTransaction(transaction);
    }

    final pendingDeletions = await _database
        .select(_database.pendingDeletions)
        .get();
    debugPrint(
      '[MoneyApp][DB] syncPendingTransactions deletions=${pendingDeletions.length}',
    );
    for (final deletion in pendingDeletions) {
      await _deleteRemote(deletion.transactionId);
      await (_database.delete(
        _database.transactions,
      )..where((tbl) => tbl.id.equals(deletion.transactionId))).go();
      await (_database.delete(
        _database.pendingDeletions,
      )..where((tbl) => tbl.transactionId.equals(deletion.transactionId))).go();
    }
  }

  Future<bool> hasPendingChanges() async {
    final unsynced = await getUnsyncedTransactions();
    final pendingDeletionIds = await _pendingDeletionIds();
    return unsynced.isNotEmpty || pendingDeletionIds.isNotEmpty;
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _database.close();
  }

  model.Transaction _mapRowToModel(LocalTransaction row) {
    return model.Transaction(
      id: row.id,
      title: row.title,
      amount: row.amount,
      type: row.type,
      date: row.date,
      category: row.category,
      description: row.description,
      syncedWithFirebase: row.syncedWithFirebase,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> _syncTransactionIfOnline(model.Transaction transaction) async {
    final online = await _isOnline();
    debugPrint(
      '[MoneyApp][DB] _syncTransactionIfOnline id=${transaction.id} online=$online',
    );
    if (!online) return;
    await _pushTransaction(transaction);
  }

  Future<void> _pushTransaction(model.Transaction transaction) async {
    debugPrint('[MoneyApp][DB] _pushTransaction start id=${transaction.id}');
    try {
      await _firestore
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toFirebaseMap(), SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Firestore write timeout after 30s',
                const Duration(seconds: 30),
              );
            },
          );
      debugPrint(
        '[MoneyApp][DB] _pushTransaction firestore ok id=${transaction.id}',
      );
      await markAsSynced(transaction.id);
      await (_database.delete(
        _database.pendingDeletions,
      )..where((tbl) => tbl.transactionId.equals(transaction.id))).go();
      debugPrint('[MoneyApp][DB] _pushTransaction done id=${transaction.id}');
    } catch (e) {
      debugPrint(
        '[MoneyApp][DB] _pushTransaction ERROR id=${transaction.id} error=$e',
      );
    }
  }

  Future<void> _deleteRemote(String id) async {
    await _firestore.collection('transactions').doc(id).delete();
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return _isOnlineResult(connectivityResult);
  }

  bool _isOnlineResult(List<ConnectivityResult> connectivityResult) {
    return connectivityResult.isNotEmpty &&
        !connectivityResult.contains(ConnectivityResult.none);
  }

  Future<Set<String>> _pendingDeletionIds() async {
    final rows = await _database.select(_database.pendingDeletions).get();
    return rows.map((row) => row.transactionId).toSet();
  }

  /// Test Firestore connectivity with a simple document
  Future<void> testFirestoreConnection() async {
    try {
      debugPrint('[MoneyApp][DB] testFirestoreConnection START');
      final testData = {
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
      debugPrint('[MoneyApp][DB] testFirestoreConnection writing: $testData');

      debugPrint(
        '[MoneyApp][DB] testFirestoreConnection calling _firestore.collection...',
      );
      final writeTask = _firestore
          .collection('test')
          .doc('connection_test')
          .set(testData, SetOptions(merge: true));

      debugPrint(
        '[MoneyApp][DB] testFirestoreConnection awaiting write with 15s timeout...',
      );
      await writeTask.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint(
            '[MoneyApp][DB] testFirestoreConnection TIMEOUT - no response after 15s',
          );
          throw TimeoutException(
            'Firestore test write timeout after 15s - no network response',
            const Duration(seconds: 15),
          );
        },
      );

      debugPrint('[MoneyApp][DB] testFirestoreConnection SUCCESS');
    } on TimeoutException catch (e) {
      debugPrint('[MoneyApp][DB] testFirestoreConnection TIMEOUT_ERROR: $e');
    } on FirebaseException catch (e) {
      debugPrint(
        '[MoneyApp][DB] testFirestoreConnection FIREBASE_ERROR code=${e.code} message=${e.message}',
      );
    } catch (e, st) {
      debugPrint(
        '[MoneyApp][DB] testFirestoreConnection ERROR: $e\nSTACKTRACE: $st',
      );
    }
  }
}
