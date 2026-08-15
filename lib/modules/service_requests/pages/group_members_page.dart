import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMembersPage extends StatelessWidget {
  final String groupId;
  final String adminId;
  final String currentUserId;

  const GroupMembersPage({
    super.key,
    required this.groupId,
    required this.adminId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Miembros del grupo")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("saving_groups")
            .doc(groupId)
            .collection("contributions")
            .snapshots(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final contributions = snapshot.data!.docs;

          // Agrupar por usuarios
          final Map<String, double> memberTotals = {};

          for (var doc in contributions) {
            final data = doc.data() as Map<String, dynamic>;
            final uid = data["userId"];
            final amount = data["amount"] * 1.0;

            memberTotals[uid] = (memberTotals[uid] ?? 0) + amount;
          }

          final memberList = memberTotals.entries.toList();

          return ListView.builder(
            itemCount: memberList.length,
            itemBuilder: (_, i) {
              final uid = memberList[i].key;
              final amount = memberList[i].value;

              final bool isAdmin = currentUserId == adminId;

              return ListTile(
                title: Text(uid),
                subtitle: Text("Aportado: \$${amount.toStringAsFixed(0)}"),
                trailing: isAdmin && uid != adminId
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection("saving_groups")
                              .doc(groupId)
                              .update({
                            "members": FieldValue.arrayRemove([uid])
                          });
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
