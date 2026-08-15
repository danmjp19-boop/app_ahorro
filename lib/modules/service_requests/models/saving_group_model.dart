import 'package:cloud_firestore/cloud_firestore.dart';

class SavingGroup {
  final String id;
  final String name;
  final double goal;
  final String adminId;
  final List<String> members;
  final double totalSaved;

  SavingGroup({
    required this.id,
    required this.name,
    required this.goal,
    required this.adminId,
    required this.members,
    required this.totalSaved,
  });

  factory SavingGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavingGroup(
      id: doc.id,
      name: data['name'] ?? '',
      goal: (data['goal'] ?? 0).toDouble(),
      adminId: data['adminId'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      totalSaved: (data['totalSaved'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'goal': goal,
      'adminId': adminId,
      'members': members,
      'totalSaved': totalSaved,
    };
  }
}
