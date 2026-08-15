import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SavingContributionsPage extends StatelessWidget {
  final String groupId;
  final String userId;

  const SavingContributionsPage({
    super.key,
    required this.groupId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis aportes"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("saving_groups")
            .doc(groupId)
            .collection("contributions")
            .where("userId", isEqualTo: userId)
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          double totalUser = 0;
          for (var d in docs) {
            totalUser += (d["amount"] * 1.0);
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Total aportado: \$${totalUser.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text("No tienes aportes aún"),
                        )
                      : ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final data = docs[i].data() as Map<String, dynamic>;
                            final amount = data["amount"] * 1.0;
                            final date = (data["timestamp"] as Timestamp).toDate();

                            return ListTile(
                              title: Text("\$${amount.toStringAsFixed(0)}"),
                              subtitle: Text(date.toString()),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
