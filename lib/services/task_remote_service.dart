import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/transaction_model.dart' as model;

class TaskRemoteService {
  TaskRemoteService([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<model.Transaction>> fetchAll() async {
    final snap = await _firestore.collection('transactions').get();
    final result = <model.Transaction>[];
    for (final d in snap.docs) {
      try {
        final data = d.data();
        data.putIfAbsent('id', () => d.id);
        result.add(model.Transaction.fromFirebaseMap(data));
      } catch (e) {
        debugPrint(
          '[MoneyApp][Remote] Skipping malformed transaction doc id=${d.id}: $e',
        );
      }
    }
    return result;
  }

  Future<void> push(model.Transaction t) async {
    await _firestore
        .collection('transactions')
        .doc(t.id)
        .set(t.toFirebaseMap(), SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _firestore.collection('transactions').doc(id).delete();
  }
}
