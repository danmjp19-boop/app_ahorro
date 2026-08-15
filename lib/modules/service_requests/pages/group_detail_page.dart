import 'package:app_ahorro/modules/service_requests/pages/group_invite_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_ahorro/modules/service_requests/services/saving_group_service.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:share_plus/share_plus.dart'; // share
import 'package:qr_flutter/qr_flutter.dart'; // qr

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  final String userId;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.userId,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final SavingGroupService _service = SavingGroupService();
  final TextEditingController _amountCtrl = TextEditingController();

  // Cambia esta base si quieres que el enlace apunte a tu dominio/route real
  String getInviteLink(String groupId) {
    return "https://app.example.com/join/$groupId";
  }

  void _copyGroupCode(BuildContext context, String groupId) async {
    await Clipboard.setData(ClipboardData(text: groupId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Código del grupo copiado al portapapeles")),
    );
  }

  void _shareInviteLink(String groupId) {
    final link = getInviteLink(groupId);
    Share.share("Únete a nuestro grupo de ahorro: $link");
  }

  void _showQr(BuildContext context, String groupId) {
    final link = getInviteLink(groupId);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Código QR de invitación"),
        content: SizedBox(
          width: 220,
          height: 220,
          child: Center(child: QrImageView(data: link, size: 200)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detalle del grupo")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("saving_groups")
            .doc(widget.groupId)
            .snapshots(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final String name = data["name"];
          final double goal = (data["goal"] ?? 0) * 1.0;
          final double totalSaved = (data["totalSaved"] ?? 0) * 1.0;
          final String adminId = data["adminId"];
          final List members = List.from(data["members"] ?? []);

          final bool isAdmin = widget.userId == adminId;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // ---------- ROW DE ACCIONES DEL ADMIN ----------
                if (isAdmin)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text("Copiar código"),
                        onPressed: () =>
                            _copyGroupCode(context, widget.groupId),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text("Compartir enlace"),
                        onPressed: () => _shareInviteLink(widget.groupId),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code),
                        label: const Text("Ver QR"),
                        onPressed: () => _showQr(context, widget.groupId),
                      ),
                    ],
                  ),

                const SizedBox(height: 10),

                Text("Meta: \$${goal.toStringAsFixed(0)}"),
                Text("Ahorro total: \$${totalSaved.toStringAsFixed(0)}"),
                const SizedBox(height: 20),

                LinearProgressIndicator(
                  value: goal > 0 ? (totalSaved / goal).clamp(0, 1) : 0,
                ),
                const SizedBox(height: 20),

                const Text("Miembros", style: TextStyle(fontSize: 20)),

                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (_, i) {
                      final member = members[i];
                      return ListTile(
                        title: Text(member.toString()),
                        trailing: isAdmin && member != adminId
                            ? IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  _service.removeMember(
                                    groupId: widget.groupId,
                                    userId: member,
                                  );
                                },
                              )
                            : null,
                      );
                    },
                  ),
                ),

                if (isAdmin) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text("Invitar miembros"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              GroupInvitePage(groupId: widget.groupId),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 20),

                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Agregar aporte",
                  ),
                ),

                const SizedBox(height: 10),

                ElevatedButton(
                  child: const Text("Agregar"),
                  onPressed: () {
                    final double amount =
                        double.tryParse(_amountCtrl.text) ?? 0;
                    if (amount > 0) {
                      _service.addContribution(
                        groupId: widget.groupId,
                        userId: widget.userId,
                        amount: amount,
                      );
                      _amountCtrl.clear();
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
