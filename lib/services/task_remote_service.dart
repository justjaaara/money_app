import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart' as model;

class TaskRemoteService {
  TaskRemoteService([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<model.Transaction>> fetchAll() async {
    final snap = await _firestore.collection('transactions').get();
    return snap.docs
        .map((d) => model.Transaction.fromFirebaseMap(d.data()))
        .toList();
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
