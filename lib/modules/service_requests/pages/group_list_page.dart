import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_ahorro/modules/service_requests/services/saving_group_service.dart';
import 'package:app_ahorro/modules/service_requests/pages/group_detail_page.dart';

class GroupListPage extends StatefulWidget {
  final String userId;
  const GroupListPage({super.key, required this.userId});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  final SavingGroupService _service = SavingGroupService();
  final TextEditingController _joinCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _goalCtrl = TextEditingController();

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Crear grupo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: "Nombre del grupo"),
            ),
            TextField(
              controller: _goalCtrl,
              decoration: const InputDecoration(
                hintText: "Meta (solo números)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Crear"),
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              final goal = double.tryParse(_goalCtrl.text.trim()) ?? 0;

              if (name.isEmpty || goal <= 0) return;

              final groupId = await _service.createGroup(
                name: name,
                goal: goal,
                adminId: widget.userId,
              );

              Navigator.pop(context);

              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GroupDetailPage(groupId: groupId, userId: widget.userId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Unirse a un grupo"),
        content: TextField(
          controller: _joinCtrl,
          decoration: const InputDecoration(hintText: "Código de invitación"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Unirse"),
            onPressed: () async {
              final ok = await _service.joinGroup(
                _joinCtrl.text.trim(),
                widget.userId,
              );
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? "Te uniste al grupo" : "Código incorrecto",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis grupos"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateGroupDialog,
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showJoinDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getUserGroups(widget.userId),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data!.docs;

          if (groups.isEmpty) {
            return const Center(child: Text("No tienes grupos aún"));
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final data = groups[i].data() as Map<String, dynamic>;
              final groupId = groups[i].id;

              return ListTile(
                title: Text(data['name']),
                subtitle: Text(
                  "Ahorro total: \$${data['totalSaved']} / Meta: ${data['goal']}",
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailPage(
                        groupId: groupId,
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
