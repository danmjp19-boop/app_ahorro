import 'package:cloud_firestore/cloud_firestore.dart';

class SavingGroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Crear un nuevo grupo
  Future<String> createGroup({
    required String name,
    required double goal,
    required String adminId,
  }) async {
    final groupRef = await _db.collection('saving_groups').add({
      'name': name,
      'goal': goal,
      'adminId': adminId,
      'members': [adminId],
      'totalSaved': 0,
      'inviteCode': _generateInviteCode(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return groupRef.id;
  }

  /// Generar código de invitación
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ123456789';
    return List.generate(6, (i) {
      final n = DateTime.now().millisecondsSinceEpoch;
      return chars[(n + i * 37) % chars.length];
    }).join();
  }

  /// Unirse a un grupo con código
  Future<bool> joinGroup(String inviteCode, String userId) async {
    final query = await _db
        .collection('saving_groups')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    final groupId = query.docs.first.id;

    await _db.collection('saving_groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([userId])
    });

    return true;
  }

  /// Obtener grupos donde el usuario es miembro
  Stream<QuerySnapshot> getUserGroups(String userId) {
    return _db
        .collection('saving_groups')
        .where('members', arrayContains: userId)
        .snapshots();
  }

  /// Registrar aporte
  Future<void> addContribution({
    required String groupId,
    required String userId,
    required double amount,
  }) async {
    final contribRef = _db
        .collection('saving_groups')
        .doc(groupId)
        .collection('contributions')
        .doc();

    await contribRef.set({
      'userId': userId,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('saving_groups').doc(groupId).update({
      'totalSaved': FieldValue.increment(amount),
    });
  }

  /// Eliminar miembro (solo admin)
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _db.collection('saving_groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([userId])
    });
  }
}
