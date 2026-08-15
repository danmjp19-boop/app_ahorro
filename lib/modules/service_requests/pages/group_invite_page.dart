import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

class GroupInvitePage extends StatelessWidget {
  final String groupId;

  const GroupInvitePage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final String inviteLink =
        "https://miapp.com/join?group=$groupId"; // puedes cambiar el dominio cuando quieras

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invitar miembros"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // ---------- QR CODE ----------
            QrImageView(
              data: inviteLink,
              version: QrVersions.auto,
              size: 220,
            ),

            const SizedBox(height: 30),

            // ---------- CÓDIGO ----------
            const Text(
              "Código del grupo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SelectableText(
              groupId,
              style: const TextStyle(fontSize: 22, color: Colors.cyan),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text("Copiar código"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: groupId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Código copiado")),
                );
              },
            ),

            const SizedBox(height: 25),

            // ---------- ENLACE ----------
            const Text(
              "Enlace directo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SelectableText(
              inviteLink,
              style: const TextStyle(fontSize: 16, color: Colors.cyan),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text("Copiar enlace"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enlace copiado")),
                );
              },
            ),

            const SizedBox(height: 25),

            // ---------- COMPARTIR ----------
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              icon: const Icon(Icons.share),
              label: const Text("Compartir"),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: "Únete a mi grupo de ahorro: $inviteLink"),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Texto copiado, pégalo en WhatsApp")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
