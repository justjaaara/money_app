import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  bool _hasPendingChanges = false;
  String? _errorMessage;

  // Getters
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get hasPendingChanges => _hasPendingChanges;
  String? get errorMessage => _errorMessage;

  TransactionProvider() {
    loadTransactions();
  }

  /// Load all transactions from database
  Future<void> loadTransactions() async {
    _setLoading(true);
    try {
      _errorMessage = null;
      debugPrint('[MoneyApp][Provider] loadTransactions start');
      _transactions = await _databaseService.getAllTransactions();
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      debugPrint(
        '[MoneyApp][Provider] loadTransactions local=${_transactions.length} pending=$_hasPendingChanges',
      );
      notifyListeners();
      unawaited(_syncAndRefresh());
    } catch (e) {
      _errorMessage = 'Error loading transactions: $e';
      debugPrint('[MoneyApp][Provider] loadTransactions error: $e');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new transaction
  Future<void> addTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required DateTime date,
    String? category,
    String? description,
  }) async {
    try {
      _errorMessage = null;
      debugPrint(
        '[MoneyApp][Provider] addTransaction start title=$title amount=$amount type=${type.name}',
      );
      final now = DateTime.now();
      final transaction = Transaction(
        id: const Uuid().v4(),
        title: title,
        amount: amount,
        type: type,
        date: date,
        category: category,
        description: description,
        syncedWithFirebase: false,
        createdAt: now,
        updatedAt: now,
      );

      await _databaseService.addTransaction(transaction);
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      _transactions.insert(0, transaction); // Add to top of list
      debugPrint(
        '[MoneyApp][Provider] addTransaction local inserted id=${transaction.id} pending=$_hasPendingChanges',
      );
      notifyListeners();
      unawaited(_syncAndRefresh());
    } catch (e) {
      _errorMessage = 'Error adding transaction: $e';
      debugPrint('[MoneyApp][Provider] addTransaction error: $e');
      notifyListeners();
    }
  }

  /// Update an existing transaction
  Future<void> updateTransaction({
    required String id,
    required String title,
    required double amount,
    required TransactionType type,
    required DateTime date,
    String? category,
    String? description,
  }) async {
    try {
      _errorMessage = null;
      final existingTransaction = _transactions.firstWhere((t) => t.id == id);

      final updatedTransaction = Transaction(
        id: id,
        title: title,
        amount: amount,
        type: type,
        date: date,
        category: category,
        description: description,
        syncedWithFirebase: existingTransaction.syncedWithFirebase,
        createdAt: existingTransaction.createdAt,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateTransaction(updatedTransaction);
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      await _databaseService.syncPendingTransactions();
      final index = _transactions.indexWhere((t) => t.id == id);
      if (index != -1) {
        _transactions[index] = updatedTransaction;
      }
      _transactions = await _databaseService.getAllTransactions();
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error updating transaction: $e';
      notifyListeners();
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String id) async {
    try {
      _errorMessage = null;
      await _databaseService.deleteTransaction(id);
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      await _databaseService.syncPendingTransactions();
      _transactions = await _databaseService.getAllTransactions();
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error deleting transaction: $e';
      notifyListeners();
    }
  }

  /// Get transactions by type
  List<Transaction> getTransactionsByType(TransactionType type) {
    return _transactions.where((t) => t.type == type).toList();
  }

  /// Get transactions by date range
  List<Transaction> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _transactions
        .where((t) => t.date.isAfter(startDate) && t.date.isBefore(endDate))
        .toList();
  }

  /// Get total balance
  Future<double> getTotalBalance() async {
    return _databaseService.getTotalBalance();
  }

  /// Get income and expense totals
  Future<Map<String, double>> getTotals(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _databaseService.getTotals(startDate, endDate);
  }

  /// Get unsynced transactions
  Future<List<Transaction>> getUnsyncedTransactions() async {
    return _databaseService.getUnsyncedTransactions();
  }

  /// Mark transaction as synced
  Future<void> markAsSynced(String id) async {
    try {
      await _databaseService.markAsSynced(id);
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      final index = _transactions.indexWhere((t) => t.id == id);
      if (index != -1) {
        _transactions[index] = _transactions[index].copyWith(
          syncedWithFirebase: true,
        );
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error marking as synced: $e';
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _syncAndRefresh() async {
    try {
      await _databaseService.syncPendingTransactions();
      _transactions = await _databaseService.getAllTransactions();
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error syncing transactions: $e';
      notifyListeners();
    }
  }

  /// Pull data from remote Firestore and upsert into local DB, then refresh UI.
  Future<void> pullFromRemote() async {
    _setLoading(true);
    try {
      await _databaseService.pullFromRemote();
      _transactions = await _databaseService.getAllTransactions();
      _hasPendingChanges = await _databaseService.hasPendingChanges();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error pulling from remote: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
