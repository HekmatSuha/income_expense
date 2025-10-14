import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import 'firebase_service.dart';

class RemoteAccountRecord {
  const RemoteAccountRecord({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String type;
  final DateTime createdAt;

  AccountsCompanion toCompanion() {
    return AccountsCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      type: Value(type),
      createdAt: Value(createdAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'createdAt': createdAt,
    };
  }

  static RemoteAccountRecord fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    return RemoteAccountRecord(
      id: snapshot.id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      type: data['type'] as String,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : (createdAtRaw as DateTime? ?? DateTime.now().toUtc()),
    );
  }
}

class AccountRemoteDataSource {
  AccountRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('accounts');
  }

  Stream<List<RemoteAccountRecord>> watch(String userId) {
    return _collection(userId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) =>
            snapshot.docs.map(RemoteAccountRecord.fromSnapshot).toList());
  }

  Future<void> upsert(RemoteAccountRecord record) {
    return _collection(record.userId)
        .doc(record.id)
        .set(record.toJson(), SetOptions(merge: true));
  }

  Future<void> delete(String userId, String id) {
    return _collection(userId).doc(id).delete();
  }
}

final accountRemoteDataSourceProvider =
    Provider<AccountRemoteDataSource>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return AccountRemoteDataSource(firestore);
});
