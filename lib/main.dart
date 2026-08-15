import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_ahorro/firebase_options.dart';
import 'package:flutter/services.dart';

String uid() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('Usuario no autenticado');
  }
  return user.uid;
}

// =================== INICIALIZACIÓN DE FIREBASE ===================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Esperar a que Firebase termine de recuperar la sesión
    await FirebaseAuth.instance.authStateChanges().first;

    runApp(const AhorroApp());
  } catch (e, stackTrace) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error al iniciar la aplicación:\n\n$e\n\n$stackTrace',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =================== APP PRINCIPAL ===================

class AhorroApp extends StatelessWidget {
  const AhorroApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ahorro Inteligente',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return PantallaPrincipal();
          }
          return LoginPage();
        },
      ),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  @override
  _PantallaPrincipalState createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indice = 0;
  String _resultadoAnalisis = "Cargando análisis inteligente...";
  bool _cargandoAnalisis = true;

  @override
  void initState() {
    super.initState();
    _refrescarAnalisis();
  }

  Future<void> _refrescarAnalisis() async {
    setState(() {
      _cargandoAnalisis = true;
      _resultadoAnalisis = "Recalculando análisis por cambios...";
    });

    final resultado = await obtenerAnalisisFinanciero();

    if (mounted) {
      setState(() {
        _resultadoAnalisis = resultado;
        _cargandoAnalisis = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 Lista de páginas actualizada
    final List<Widget> _paginas = [
      PaginaInicio(
        resultadoAnalisis: _resultadoAnalisis,
        cargando: _cargandoAnalisis,
      ),
      PaginaIngresos(refrescarAnalisis: _refrescarAnalisis),
      PaginaGastos(refrescarAnalisis: _refrescarAnalisis),
      PaginaMetas(refrescarAnalisis: _refrescarAnalisis),

      /// 👇 AGREGA ESTA LÍNEA AQUÍ
      PaginaAhorroColaborativo(boteId: "default"),

      PaginaMotivacion(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ahorro Inteligente 💰'),
        centerTitle: true,
        backgroundColor: Colors.cyan,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!mounted) return;
            },
          ),
        ],
      ),
      body: _paginas[_indice],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: (index) {
          setState(() {
            _indice = index;
          });
        },
        selectedItemColor: Colors.cyan,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1A1E36),
        type: BottomNavigationBarType.fixed,
        // 🚀 Elementos de navegación actualizados
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Ingresos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.money_off), label: 'Gastos'),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Metas'),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt),
            label: 'Colaborativo',
          ), // 🚀 NUEVO ICONO
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: 'Motivación',
          ),
        ],
      ),
    );
  }
}

// =================== FUNCIONES DE FORMATO ===================

String _formatearValor(double valor) {
  final formatter = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '',
    decimalDigits: 0,
  );
  return formatter.format(valor).trim();
}

// =================== PÁGINA AHORRO COLABORATIVO (REEMPLAZAR) ===================

class PaginaAhorroColaborativo extends StatefulWidget {
  final String boteId; //

  const PaginaAhorroColaborativo({
    super.key,
    required this.boteId, //
  });

  @override
  _PaginaAhorroColaborativoState createState() =>
      _PaginaAhorroColaborativoState();
}

class _PaginaAhorroColaborativoState extends State<PaginaAhorroColaborativo> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controladores
  final TextEditingController _nombreBoteCtrl = TextEditingController();
  final MoneyMaskedTextController _metaBoteCtrl = MoneyMaskedTextController(
    decimalSeparator: '',
    thousandSeparator: '.',
    leftSymbol: '\$',
    precision: 0,
  );

  void _editarNombreMiembro(String docId, String nombreActual) async {
    TextEditingController _ctrl = TextEditingController(text: nombreActual);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar nombre"),
          content: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(labelText: "Nuevo nombre"),
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Guardar"),
              onPressed: () async {
                String nuevo = _ctrl.text.trim();

                if (nuevo.isNotEmpty) {
                  await _firestore
                      .collection('botes')
                      .doc(widget.boteId)
                      .collection('miembros')
                      .doc(docId)
                      .update({'nombre': nuevo});
                }

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  // UTIL: id del usuario actual (llama a la función uid() que ya tienes)
  String get _uid {
  final user = FirebaseAuth.instance.currentUser;
  return user?.uid ?? '';
}

  // ------------------ NUEVO: Gestión de códigos y solicitudes ------------------

  // Genera un código alfanumérico corto
  String _generarCodigoAlfanumerico(int length) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sin letras confusas
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    var seed = rnd;
    for (var i = 0; i < length; i++) {
      seed = (seed * 9301 + 49297) % 233280;
      final idx = (seed % chars.length).toInt();
      buffer.write(chars[idx]);
    }
    return buffer.toString();
  }

  // Crea y guarda un código de invitación (doc en colección 'invitaciones' raíz)
  Future<String?> _generarCodigoInvitacion(String boteId) async {
    try {
      final codigo = _generarCodigoAlfanumerico(6);
      final docRef = _firestore.collection('invitaciones').doc(codigo);
      await docRef.set({
        'codigo': codigo,
        'boteId': boteId,
        'creadorId': _uid,
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return codigo;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al generar código: $e')));
      return null;
    }
  }

  // Usuario ingresa un código: se crea una solicitud en botes/{boteId}/solicitudes con estado 'pendiente'
  Future<void> _crearSolicitudPorCodigo(String codigoIngresado) async {
    try {
      final invSnap = await _firestore
          .collection('invitaciones')
          .doc(codigoIngresado)
          .get();
      if (!invSnap.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Código inválido.')));
        return;
      }
      final invData = invSnap.data()!;
      if (invData['activo'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código ya no está activo.')),
        );
        return;
      }
      final boteId = invData['boteId'] as String;

      // Verificar si ya existe solicitud o ya es miembro
      final miembroDoc = await _firestore
          .collection('botes')
          .doc(boteId)
          .collection('miembros')
          .doc(_uid)
          .get();
      if (miembroDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya eres miembro de este bote.')),
        );
        return;
      }

      final solicitudRef = _firestore
          .collection('botes')
          .doc(boteId)
          .collection('solicitudes')
          .doc(_uid);
      final solicitudSnap = await solicitudRef.get();
      if (solicitudSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya tienes una solicitud pendiente.')),
        );
        return;
      }

      await solicitudRef.set({
        'userId': _uid,
        'status': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada. Espera la aprobación del administrador.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar solicitud: $e')));
    }
  }

  // Admin aprueba solicitud: añade miembro y elimina la solicitud
  Future<void> _aprobarSolicitud(String boteId, String userId) async {
    try {
      final boteRef = _firestore.collection('botes').doc(boteId);
      final miembroRef = boteRef.collection('miembros').doc(userId);
      final solicitudRef = boteRef.collection('solicitudes').doc(userId);

      await _firestore.runTransaction((tx) async {
        final boteSnap = await tx.get(boteRef);
        if (!boteSnap.exists) throw Exception('Bote no existe');
        // Añadir al array miembrosIds
        tx.update(boteRef, {
          'miembrosIds': FieldValue.arrayUnion([userId]),
        });
        // Crear doc miembro
        tx.set(miembroRef, {
          'userId': userId,
          'rol': 'miembro',
          'nombreUsuario': 'Miembro', // opcional: admin puede editar después
          'aporte': 0.0,
        });
        // Eliminar solicitud
        tx.delete(solicitudRef);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud aprobada. Usuario agregado como miembro.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al aprobar: $e')));
    }
  }

  // Admin rechaza solicitud: elimina la solicitud
  Future<void> _rechazarSolicitud(String boteId, String userId) async {
    try {
      final solicitudRef = _firestore
          .collection('botes')
          .doc(boteId)
          .collection('solicitudes')
          .doc(userId);
      await solicitudRef.delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud rechazada.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al rechazar: $e')));
    }
  }

  // ------------------ FIN: Gestión de códigos y solicitudes ------------------

  // Crea un nuevo bote y agrega al creador como miembro/admin
  Future<void> _crearBoteComun() async {
    final nombre = _nombreBoteCtrl.text.trim();
    final meta = _metaBoteCtrl.numberValue;

    if (nombre.isEmpty || meta <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa nombre y meta válidos.'),
        ),
      );
      return;
    }

    try {
      final nuevoBoteRef = await _firestore.collection('botes').add({
        'nombre': nombre,
        'meta': meta,
        'creadorId': _uid,
        'totalAhorrado': 0.0,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'miembrosIds': [_uid], // importante: para consultas con arrayContains
      });

      // Crear documento de miembro en subcolección 'miembros'
      await _firestore
          .collection('botes')
          .doc(nuevoBoteRef.id)
          .collection('miembros')
          .doc(_uid)
          .set({
            'userId': _uid,
            'rol': 'administrador',
            'nombreUsuario':
                'Admin (Tú)', // opcional: podrías guardar nombre real
            'aporte': 0.0,
          });

      _nombreBoteCtrl.clear();
      _metaBoteCtrl.text = "";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bote "$nombre" creado con éxito.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al crear bote: $e')));
    }
  }

  // Unirse a un bote (añadir UID a miembrosIds y crear doc en subcolección 'miembros')
  Future<void> _unirseABote(String boteId) async {
    try {
      final boteRef = _firestore.collection('botes').doc(boteId);

      // Agregar UID al array de miembros
      await boteRef.update({
        'miembrosIds': FieldValue.arrayUnion([_uid]),
      });

      // Crear doc de miembro si no existe
      final miembroRef = boteRef.collection('miembros').doc(_uid);
      final miembroSnap = await miembroRef.get();
      if (!miembroSnap.exists) {
        await miembroRef.set({
          'userId': _uid,
          'rol': 'miembro',
          'nombreUsuario': 'Miembro', // opcional
          'aporte': 0.0,
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Te has unido al bote.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al unirse al bote: $e')));
    }
  }

  // Salir de un bote (remover del array y eliminar doc de miembro si lo deseas)
  Future<void> _salirDeBote(String boteId) async {
    try {
      final boteRef = _firestore.collection('botes').doc(boteId);

      // Obtener aporte del miembro antes de eliminar (opcional: podrías restarlo del total)
      final miembroRef = boteRef.collection('miembros').doc(_uid);
      final miembroSnap = await miembroRef.get();
      double aporte = 0.0;
      if (miembroSnap.exists) {
        final data = miembroSnap.data()!;
        aporte = (data['aporte'] as num? ?? 0.0).toDouble();
      }

      // Si quieres restar el aporte del total, usar transaction
      await _firestore.runTransaction((tx) async {
        final boteSnap = await tx.get(boteRef);
        if (!boteSnap.exists) return;
        final totalActual = (boteSnap.data()?['totalAhorrado'] ?? 0.0) as num;
        final nuevoTotal = (totalActual.toDouble() - aporte).clamp(
          0.0,
          double.infinity,
        );
        tx.update(boteRef, {
          'totalAhorrado': nuevoTotal,
          'miembrosIds': FieldValue.arrayRemove([_uid]),
        });
        // eliminar doc miembro
        tx.delete(miembroRef);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Has salido del bote.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al salir del bote: $e')));
    }
  }

  // Diálogo para crear bote
  Future<void> _mostrarDialogoCrearBote() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E21),
          title: const Text(
            'Crear Bote Común',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreBoteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Bote (Ej: Viaje 2026)',
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _metaBoteCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Meta a alcanzar'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.cyan),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                _crearBoteComun();
                Navigator.pop(context);
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  // Diálogo para aportar a un bote
  Future<void> _mostrarDialogoAportar(
    String boteId,
    String boteNombre,
    double aporteActual,
  ) async {
    final MoneyMaskedTextController aporteCtrl = MoneyMaskedTextController(
      decimalSeparator: '',
      thousandSeparator: '.',
      leftSymbol: '\$',
      precision: 0,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E21),
          title: Text(
            'Aportar a: $boteNombre',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: aporteCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Monto a aportar'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.cyan),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                final valor = aporteCtrl.numberValue;
                if (valor > 0) {
                  _realizarAporte(boteId, valor);
                }
                Navigator.pop(context);
              },
              child: const Text('Aportar'),
            ),
          ],
        );
      },
    );
  }

  // Realiza aporte: actualiza aporte del miembro y totalAhorrado de forma atómica
  Future<void> _realizarAporte(String boteId, double monto) async {
    final boteRef = _firestore.collection('botes').doc(boteId);
    final miembroRef = boteRef.collection('miembros').doc(_uid);

    try {
      await _firestore.runTransaction((tx) async {
        final boteSnap = await tx.get(boteRef);
        if (!boteSnap.exists) throw Exception('Bote no existe');

        // Obtener datos actuales
        final totalActual = (boteSnap.data()?['totalAhorrado'] ?? 0.0) as num;
        final nuevoTotal = totalActual.toDouble() + monto;

        // Asegurarse de que exista doc de miembro; si no, crearlo con aporte inicial 0
        final miembroSnap = await tx.get(miembroRef);
        if (!miembroSnap.exists) {
          tx.set(miembroRef, {
            'userId': _uid,
            'rol': 'miembro',
            'nombreUsuario': 'Miembro',
            'aporte': monto,
          });
        } else {
          final aporteActual = (miembroSnap.data()?['aporte'] ?? 0.0) as num;
          tx.update(miembroRef, {'aporte': (aporteActual.toDouble() + monto)});
        }

        // Actualizar total del bote
        tx.update(boteRef, {'totalAhorrado': nuevoTotal});
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aporte de \$${_formatearValor(monto)} realizado con éxito.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al realizar aporte: $e')));
    }
  }

  // Muestra la ventana con miembros y sus aportes
  // Modificado: ahora recibe isCreator para mostrar solicitudes y botones de aprobación
  Future<void> _mostrarMiembros(
    String boteId, {
    required bool isCreator,
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        final miembroStream = _firestore
            .collection('botes')
            .doc(boteId)
            .collection('miembros')
            .snapshots();
        final solicitudesStream = _firestore
            .collection('botes')
            .doc(boteId)
            .collection('solicitudes')
            .snapshots();

        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E21),
          title: const Text('Miembros', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // LISTA DE MIEMBROS
                  StreamBuilder<QuerySnapshot>(
                    stream: miembroStream,
                    builder: (context, snap) {
                      if (snap.hasError)
                        return Text(
                          'Error: ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                        );
                      if (snap.connectionState == ConnectionState.waiting)
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.cyan),
                        );
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty)
                        return const Text(
                          'No hay miembros aún.',
                          style: TextStyle(color: Colors.white70),
                        );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: docs.map((d) {
                          final data = d.data() as Map<String, dynamic>;
                          final aporte = (data['aporte'] as num? ?? 0.0)
                              .toDouble();
                          return ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['nombreUsuario'] ?? data['userId'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),

                                if (data['userId'] == _uid)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.cyan,
                                      size: 20,
                                    ),
                                    onPressed: () => _editarNombreMiembro(
                                      d.id,
                                      data['nombreUsuario'] ?? '',
                                    ),
                                  ),
                              ],
                            ),

                            subtitle: Text(
                              'Aporte: \$${_formatearValor(aporte)}',
                              style: const TextStyle(color: Colors.cyan),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // SOLICITUDES PENDIENTES (solo para admin)
                  if (isCreator) ...[
                    const Divider(color: Colors.white24),
                    const Text(
                      'Solicitudes pendientes',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: solicitudesStream,
                      builder: (context, snap) {
                        if (snap.hasError)
                          return Text(
                            'Error: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                          );
                        if (snap.connectionState == ConnectionState.waiting)
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.cyan,
                            ),
                          );
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty)
                          return const Text(
                            'No hay solicitudes pendientes.',
                            style: TextStyle(color: Colors.white70),
                          );
                        return Column(
                          children: docs.map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final userId = data['userId'] as String? ?? '';
                            return ListTile(
                              title: Text(
                                'Usuario: $userId',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'Enviado: ${data['createdAt'] != null ? (data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate().toString() : data['createdAt'].toString()) : '—'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.greenAccent,
                                    ),
                                    onPressed: () =>
                                        _aprobarSolicitud(boteId, userId),
                                    tooltip: 'Aprobar',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () =>
                                        _rechazarSolicitud(boteId, userId),
                                    tooltip: 'Rechazar',
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.cyan)),
            ),
          ],
        );
      },
    );
  }

  // Diálogo para que el admin genere y copie el código
  Future<void> _mostrarDialogoGenerarCodigo(String boteId) async {
    final codigo = await _generarCodigoInvitacion(boteId);
    if (codigo == null) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E21),
          title: const Text(
            'Código de invitación',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                codigo,
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Comparte este código con las personas que quieres que soliciten unirse.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cerrar', style: TextStyle(color: Colors.cyan)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codigo));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado al portapapeles.'),
                  ),
                );
              },
              child: const Text('Copiar'),
            ),
          ],
        );
      },
    );
  }

  // Diálogo general para que cualquier usuario ingrese un código y envíe solicitud
  Future<void> _mostrarDialogoIngresarCodigo() async {
    final TextEditingController codigoCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E21),
          title: const Text(
            'Unirse por código',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: codigoCtrl,
            decoration: const InputDecoration(
              hintText: 'Ingresa el código de invitación',
            ),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.cyan),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                final codigo = codigoCtrl.text.trim().toUpperCase();
                if (codigo.isNotEmpty) {
                  _crearSolicitudPorCodigo(codigo);
                }
                Navigator.pop(context);
              },
              child: const Text('Enviar solicitud'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream: todos los botes donde el usuario es miembro (miembrosIds contiene uid)
    final Stream<QuerySnapshot> botesStream = _firestore
        .collection('botes')
        .where('miembrosIds', arrayContains: _uid)
        .orderBy('fechaCreacion', descending: true)
        .snapshots();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mis Botes Colaborativos',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _mostrarDialogoCrearBote,
                    icon: const Icon(Icons.group_add),
                    label: const Text('Crear Nuevo Bote'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón para ingresar código y solicitar unirse
                  TextButton(
                    onPressed: _mostrarDialogoIngresarCodigo,
                    child: const Text(
                      'Unirse por código',
                      style: TextStyle(color: Colors.cyan),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: botesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error al cargar los botes: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.cyan),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                // Mostrar opción para buscar botes públicos o ingresar código (opcional)
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No estás en ningún Bote aún.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          // Opcional: mostrar pantalla para buscar botes por ID o listado público
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Busca botes públicos o crea uno nuevo.',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan,
                        ),
                        child: const Text('Buscar botes'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final double totalAhorrado =
                      (data['totalAhorrado'] as num? ?? 0.0).toDouble();
                  final double meta = (data['meta'] as num? ?? 0.0).toDouble();
                  final progreso = meta == 0
                      ? 0.0
                      : (totalAhorrado / meta).clamp(0.0, 1.0);
                  final String creadorId = data['creadorId'] ?? '';
                  final bool isCreator = creadorId == _uid;

                  return Card(
                    color: const Color(0xFF1A1E36),
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data['nombre'] ?? 'Bote sin nombre',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.cyan,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              if (isCreator)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                              if (isCreator)
                                IconButton(
                                  icon: const Icon(
                                    Icons.person_add,
                                    color: Colors.greenAccent,
                                  ),
                                  tooltip: "Agregar miembro",
                                  onPressed: () =>
                                      _mostrarDialogoGenerarCodigo(doc.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Meta: \$${_formatearValor(meta)}",
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            "Ahorrado: \$${_formatearValor(totalAhorrado)}",
                            style: const TextStyle(color: Colors.greenAccent),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progreso,
                            minHeight: 10,
                            backgroundColor: Colors.grey,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.cyan,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                stream: _firestore
                                    .collection('botes')
                                    .doc(doc.id)
                                    .collection('miembros')
                                    .doc(_uid)
                                    .snapshots(),
                                builder: (context, memberSnapshot) {
                                  if (!memberSnapshot.hasData ||
                                      !memberSnapshot.data!.exists) {
                                    return const Text(
                                      'Mi aporte: \$0',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    );
                                  }
                                  final miembroData =
                                      memberSnapshot.data!.data()
                                          as Map<String, dynamic>;
                                  final double miAporte =
                                      (miembroData['aporte'] as num? ?? 0.0)
                                          .toDouble();

                                  return Text(
                                    "Mi Aporte: \$${_formatearValor(miAporte)}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Ver miembros',
                                    icon: const Icon(
                                      Icons.people,
                                      color: Colors.cyan,
                                    ),
                                    onPressed: () => _mostrarMiembros(
                                      doc.id,
                                      isCreator: isCreator,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _mostrarDialogoAportar(
                                      doc.id,
                                      data['nombre'] ?? 'Bote',
                                      0.0,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text('Aportar'),
                                  ),
                                  const SizedBox(width: 8),
                                  // Si por alguna razón el usuario no está en miembrosIds (aunque el stream filtro lo garantice),
                                  // mostramos botón para unirse (por seguridad)
                                  FutureBuilder<DocumentSnapshot>(
                                    future: _firestore
                                        .collection('botes')
                                        .doc(doc.id)
                                        .get(),
                                    builder: (context, futureSnap) {
                                      if (!futureSnap.hasData)
                                        return const SizedBox.shrink();
                                      final docData =
                                          futureSnap.data!.data()
                                              as Map<String, dynamic>;
                                      final miembros = List.from(
                                        docData['miembrosIds'] ?? [],
                                      );
                                      final bool soyMiembro = miembros.contains(
                                        _uid,
                                      );
                                      if (!soyMiembro) {
                                        return TextButton(
                                          onPressed: () => _unirseABote(doc.id),
                                          child: const Text(
                                            'Unirse',
                                            style: TextStyle(
                                              color: Colors.cyan,
                                            ),
                                          ),
                                        );
                                      } else {
                                        return TextButton(
                                          onPressed: () => _salirDeBote(doc.id),
                                          child: const Text(
                                            'Salir',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// =================== PÁGINA INICIO (MUESTRA DATOS Y ERRORES) ===================

class PaginaInicio extends StatelessWidget {
  final String resultadoAnalisis;
  final bool cargando;

  PaginaInicio({required this.resultadoAnalisis, required this.cargando});

  @override
  Widget build(BuildContext context) {
    bool errorEncontrado =
        resultadoAnalisis.contains("Error [Análisis IA - Gemini]") ||
        (resultadoAnalisis.isEmpty && !cargando);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bienvenido a tu panel de ahorro 💰',
                style: TextStyle(fontSize: 20, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Muestra el indicador de carga, el error o el análisis
              cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.cyan),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Análisis financiero IA (Gemini)",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.cyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        errorEncontrado
                            ? const Text(
                                "El análisis falló al cargar. Intenta de nuevo más tarde o verifica tu clave API y conexión.",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  height: 1.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Text(
                                resultadoAnalisis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== PÁGINA INGRESOS (CON RECARGA Y FORMATO) ===================

class PaginaIngresos extends StatefulWidget {
  final VoidCallback refrescarAnalisis;
  PaginaIngresos({required this.refrescarAnalisis});

  @override
  _PaginaIngresosState createState() => _PaginaIngresosState();
}

class _PaginaIngresosState extends State<PaginaIngresos> {
  final TextEditingController _nombreController = TextEditingController();
  // 💡 USANDO MoneyMaskedTextController para formato de moneda
  final MoneyMaskedTextController _valorController = MoneyMaskedTextController(
    decimalSeparator: '',
    thousandSeparator: '.',
    leftSymbol: '\$',
    precision: 0,
  );
  List<Map<String, dynamic>> _ingresos = [];
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarIngresos();
  }

  Future<void> _cargarIngresos() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('ingresos')
        .doc('data')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _ingresos = List<Map<String, dynamic>>.from(data['items']);
        _calcularTotal();
      });
    }
  }

  Future<void> _guardarIngresos() async {
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('ingresos')
        .doc('data')
        .set({'items': _ingresos});
  }

  void _agregarIngreso() {
    final nombre = _nombreController.text.trim();
    // 💡 Obteniendo el valor numérico (sin puntos ni $)
    final valor = _valorController.numberValue;

    if (nombre.isEmpty || valor <= 0) return;

    setState(() {
      _ingresos.add({'nombre': nombre, 'valor': valor});
      _calcularTotal();
      _guardarIngresos();
      widget.refrescarAnalisis();
      _nombreController.clear();
      _valorController.text = "";
    });
  }

  void _eliminarIngreso(int index) async {
    setState(() {
      _ingresos.removeAt(index);
      _calcularTotal();
    });

    await _guardarIngresos();
    widget.refrescarAnalisis();
  }

  void _calcularTotal() {
    _total = _ingresos.fold(
      0.0,
      (sum, item) => sum + (item['valor'] as num).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Total: \$${_formatearValor(_total)}',
            style: const TextStyle(
              fontSize: 22,
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nombreController,
            decoration: InputDecoration(
              labelText: 'Nombre del ingreso',
              labelStyle: const TextStyle(color: Colors.cyan),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 💡 USANDO EL CONTROLADOR MASCARADO
          TextField(
            controller: _valorController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Valor',
              labelStyle: const TextStyle(color: Colors.cyan),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _agregarIngreso,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Agregar ingreso',
              style: TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _ingresos.length,
              itemBuilder: (context, index) {
                final ingreso = _ingresos[index];
                return Card(
                  color: const Color(0xFF1A1E36),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                      ingreso['nombre'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '\$${_formatearValor(ingreso['valor'].toDouble())}',
                      style: const TextStyle(color: Colors.cyan),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _eliminarIngreso(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =================== PÁGINA GASTOS (CON RECARGA, FORMATO Y RECORDATORIOS) ===================

class PaginaGastos extends StatefulWidget {
  final VoidCallback refrescarAnalisis;
  PaginaGastos({required this.refrescarAnalisis});

  @override
  _PaginaGastosState createState() => _PaginaGastosState();
}

class _PaginaGastosState extends State<PaginaGastos> {
  List<String> _categorias = [
    "Arriendo",
    "Mercado",
    "Servicios públicos",
    "Agua",
    "Luz",
    "Gas",
    "Internet",
    "Teléfono",
    "Cuota moto",
    "Cuota apartamento",
    "Transporte",
    "Comida fuera",
    "Tarjeta de crédito",
    "Fiado tienda",
    "Cadenas",
    "Imprevistos",
  ];

  List<Map<String, dynamic>> _gastos = [];
  double _totalGastos = 0.0;
  double _totalIngresos = 0.0;
  bool _expanded = false;
  final TextEditingController _nuevaCatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _cargarGastos();
    _cargarIngresosTotales();
  }

  // =================== FIRESTORE: CATEGORÍAS ===================

  Future<void> _cargarCategorias() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('categorias')
        .doc('data')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _categorias = List<String>.from(data['items']);
      });
    } else {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('categorias')
          .doc('data')
          .set({'items': _categorias});
    }
  }

  Future<void> _guardarCategorias() async {
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('categorias')
        .doc('data')
        .set({'items': _categorias});
  }

  // =================== GASTOS ===================

  Future<void> _cargarGastos() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('gastos')
        .doc('data')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _gastos = List<Map<String, dynamic>>.from(data['items']);
        _calcularTotalGastos();
      });
    }
  }

  Future<void> _guardarGastos() async {
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('gastos')
        .doc('data')
        .set({'items': _gastos});
  }

  Future<void> _cargarIngresosTotales() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('ingresos')
        .doc('data')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final ingresos = List<Map<String, dynamic>>.from(data['items']);
      setState(() {
        _totalIngresos = ingresos.fold(
          0.0,
          (sum, item) => sum + (item['valor'] as num).toDouble(),
        );
      });
    }
  }

  void _calcularTotalGastos() {
    _totalGastos = _gastos.fold(
      0.0,
      (sum, item) => sum + (item['valor'] as num).toDouble(),
    );
  }

  Future<void> _mostrarDialogoAgregarGasto(String categoria) async {
    final MoneyMaskedTextController ctrl = MoneyMaskedTextController(
      decimalSeparator: '',
      thousandSeparator: '.',
      leftSymbol: '\$',
      precision: 0,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E21),
          title: Text(
            'Agregar gasto: $categoria',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Ej: 500.000'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.cyan),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                final valor = ctrl.numberValue;
                if (valor > 0) {
                  setState(() {
                    _gastos.add({
                      'nombre': categoria,
                      'valor': valor,
                      'fecha_recordatorio': null,
                    });
                    _calcularTotalGastos();
                    _guardarGastos();
                    widget.refrescarAnalisis();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _eliminarGasto(int index) async {
    setState(() {
      _gastos.removeAt(index);
      _calcularTotalGastos();
    });
    await _guardarGastos();
    widget.refrescarAnalisis();
  }

  void _agregarCategoriaDesdeCampo() {
    final nombre = _nuevaCatCtrl.text.trim();
    if (nombre.isEmpty || _categorias.contains(nombre)) return;

    setState(() {
      _categorias.add(nombre);
      _guardarCategorias();
      _nuevaCatCtrl.clear();
    });
  }

  Future<void> _seleccionarFechaRecordatorio(int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      helpText: 'Selecciona fecha de pago de ${_gastos[index]['nombre']}',
      confirmText: 'Aceptar',
      cancelText: 'Cancelar',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyan,
              onPrimary: Colors.white,
              surface: Color(0xFF1A1E36),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0A0E21),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _gastos[index]['fecha_recordatorio'] = picked
            .toIso8601String()
            .substring(0, 10);
        _guardarGastos();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recordatorio de pago de ${_gastos[index]['nombre']} guardado para el ${DateFormat('dd/MM/yyyy').format(picked)}',
          ),
        ),
      );
    }
  }

  Future<void> _mostrarDialogoOpcionesGasto(int index) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E21),
          title: Text(
            _gastos[index]['nombre'],
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.alarm_add, color: Colors.cyan),
                title: Text(
                  _gastos[index]['fecha_recordatorio'] == null
                      ? 'Agregar Recordatorio de Pago'
                      : 'Modificar Recordatorio',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarFechaRecordatorio(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Eliminar Gasto',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _eliminarGasto(index);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.cyan)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final disponible = _totalIngresos - _totalGastos;
    final progreso = (_totalIngresos == 0)
        ? 0.0
        : (_totalGastos / _totalIngresos).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            "Ingresos: \$${_formatearValor(_totalIngresos)}",
            style: const TextStyle(fontSize: 18, color: Colors.greenAccent),
          ),
          const SizedBox(height: 6),
          Text(
            "Gastos totales: \$${_formatearValor(_totalGastos)}",
            style: const TextStyle(fontSize: 18, color: Colors.cyan),
          ),
          const SizedBox(height: 6),
          Text(
            "Disponible: \$${_formatearValor(disponible)}",
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progreso.toDouble(),
            backgroundColor: Colors.grey,
            valueColor: const AlwaysStoppedAnimation(Colors.cyan),
            minHeight: 12,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1E36),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Seleccionar categoría',
                    style: TextStyle(color: Colors.white),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.cyan,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _gastos.isEmpty
                ? const Center(
                    child: Text(
                      'No hay gastos aún',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: _gastos.length,
                    itemBuilder: (context, index) {
                      final g = _gastos[index];
                      final String? fechaStr = g['fecha_recordatorio'];
                      String recordatorioTexto = "";
                      if (fechaStr != null) {
                        final fecha = DateTime.parse(fechaStr);
                        recordatorioTexto =
                            "Pago: ${DateFormat('dd/MM/yyyy').format(fecha)}";
                      }

                      return Card(
                        color: const Color(0xFF1A1E36),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            g['nombre'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: recordatorioTexto.isNotEmpty
                              ? Text(
                                  recordatorioTexto,
                                  style: const TextStyle(color: Colors.cyan),
                                )
                              : null,
                          trailing: Text(
                            '\$${_formatearValor(g['valor'].toDouble())}',
                            style: const TextStyle(color: Colors.greenAccent),
                          ),
                          onTap: () => _mostrarDialogoOpcionesGasto(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =================== PÁGINA METAS (CON RECARGA Y FORMATO) ===================

class PaginaMetas extends StatefulWidget {
  final VoidCallback refrescarAnalisis;
  PaginaMetas({required this.refrescarAnalisis});

  @override
  _PaginaMetasState createState() => _PaginaMetasState();
}

class _PaginaMetasState extends State<PaginaMetas> {
  List<Map<String, dynamic>> _metas = [];
  final TextEditingController _nombreCtrl = TextEditingController();
  // 💡 USANDO MoneyMaskedTextController para el valor meta
  final MoneyMaskedTextController _valorCtrl = MoneyMaskedTextController(
    decimalSeparator: '',
    thousandSeparator: '.',
    leftSymbol: '\$',
    precision: 0,
  );
  // 💡 USANDO MoneyMaskedTextController para el ahorro
  final MoneyMaskedTextController _ahorroCtrl = MoneyMaskedTextController(
    decimalSeparator: '',
    thousandSeparator: '.',
    leftSymbol: '\$',
    precision: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargarMetas();
  }

  Future<void> _cargarMetas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('metas_${uid()}');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() => _metas = List<Map<String, dynamic>>.from(decoded));
    }
  }

  Future<void> _guardarMetas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('metas_${uid()}', jsonEncode(_metas));
  }

  void _agregarMeta() {
    final nombre = _nombreCtrl.text.trim();
    // 💡 Obteniendo el valor numérico
    final valor = _valorCtrl.numberValue;
    if (nombre.isEmpty || valor <= 0) return;

    setState(() {
      _metas.add({'nombre': nombre, 'meta': valor, 'ahorrado': 0.0});
      _guardarMetas();
      widget.refrescarAnalisis(); // 🚀 Notifica a la IA
      _nombreCtrl.clear();
      _valorCtrl.text = ""; // Limpiar
    });
  }

  void _eliminarMeta(int index) {
    setState(() {
      _metas.removeAt(index);
      _guardarMetas();
      widget.refrescarAnalisis(); // 🚀 Notifica a la IA
    });
  }

  Future<void> _mostrarDialogoAhorro(int index) async {
    _ahorroCtrl.text = ""; // Limpiar para el diálogo

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E21),
          title: Text(
            'Añadir ahorro a: ${_metas[index]['nombre']}',
            style: const TextStyle(color: Colors.white),
          ),
          // 💡 USANDO EL CONTROLADOR MASCARADO
          content: TextField(
            controller: _ahorroCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Monto a ahorrar (ej: 100.000)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.cyan),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                // 💡 Obteniendo el valor numérico
                final valor = _ahorroCtrl.numberValue;

                if (valor > 0) {
                  setState(() {
                    _metas[index]['ahorrado'] =
                        (_metas[index]['ahorrado'] as num).toDouble() + valor;
                    _guardarMetas();
                    widget.refrescarAnalisis(); // 🚀 Notifica a la IA
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(
              labelText: "Nombre de la meta",
              labelStyle: TextStyle(color: Colors.cyan),
            ),
          ),
          const SizedBox(height: 10),
          // 💡 USANDO EL CONTROLADOR MASCARADO
          TextField(
            controller: _valorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Valor meta",
              labelStyle: TextStyle(color: Colors.cyan),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _agregarMeta,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            child: const Text("Agregar meta"),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _metas.length,
              itemBuilder: (context, i) {
                final meta = _metas[i];
                final double ahorrado = (meta['ahorrado'] as num).toDouble();
                final double metaValor = (meta['meta'] as num).toDouble();

                final progreso = metaValor == 0
                    ? 0.0
                    : (ahorrado / metaValor).clamp(0.0, 1.0);

                return Card(
                  color: const Color(0xFF1A1E36),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                      meta['nombre'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Meta: \$${_formatearValor(metaValor)}",
                          style: const TextStyle(color: Colors.cyan),
                        ),
                        Text(
                          "Ahorrado: \$${_formatearValor(ahorrado)}",
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progreso,
                          minHeight: 10,
                          backgroundColor: Colors.grey,
                          valueColor: const AlwaysStoppedAnimation(Colors.cyan),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.greenAccent,
                          ),
                          onPressed: () => _mostrarDialogoAhorro(i),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _eliminarMeta(i),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =================== PÁGINA MOTIVACIÓN (CON PREGUNTAS PREDETERMINADAS Y LIBRES) ===================
class PaginaMotivacion extends StatefulWidget {
  @override
  _PaginaMotivacionState createState() => _PaginaMotivacionState();
}

class _PaginaMotivacionState extends State<PaginaMotivacion> {
  // 💡 Controlador para la pregunta libre
  final TextEditingController _preguntaController = TextEditingController();
  String _mensaje = "";
  bool _cargando = false;

  final List<String> _preguntasPredeterminadas = [
    "¿Cómo puedo mejorar mi situación económica?",
    "¿Qué pasos debo seguir para salir de deudas?",
    "Dime estrategias efectivas para no malgastar el dinero.",
    "¿Cómo puedo empezar a invertir con poco capital?",
    "¿Cuál es la mejor manera de crear un fondo de emergencia?",
  ];

  // ⚡ Función que llama a la IA con una pregunta específica
  Future<void> _generarMotivacion(String pregunta) async {
    // Si la pregunta es desde el TextField, limpiar el campo.
    if (_preguntaController.text.isNotEmpty) {
      _preguntaController.clear();
    }

    // Si no hay pregunta válida, salimos.
    if (pregunta.trim().isEmpty) return;

    setState(() {
      _cargando = true;
      _mensaje = "Pensando en la mejor estrategia para ti...";
    });

    final ia = IAService();
    final resultado = await ia.generarMotivacion(pregunta);

    setState(() {
      _mensaje = resultado;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🚀 Preguntas para potenciar tus finanzas",
            style: TextStyle(
              fontSize: 18,
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Lista de botones con preguntas predeterminadas
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _preguntasPredeterminadas.map((pregunta) {
              return ElevatedButton(
                onPressed: _cargando
                    ? null
                    : () => _generarMotivacion(pregunta),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1E36),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.cyan, width: 1.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Text(pregunta, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
          ),

          const Divider(color: Colors.white24, height: 25),

          // 💡 Casilla de pregunta libre
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _preguntaController,
                  decoration: InputDecoration(
                    labelText: 'Escribe tu pregunta o duda financiera...',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyan, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _cargando
                    ? null
                    : () => _generarMotivacion(_preguntaController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.send),
              ),
            ],
          ),

          const Divider(color: Colors.white24, height: 30),

          // Área de respuesta
          _cargando
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.cyan),
                )
              : Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _mensaje.isEmpty
                          ? "Selecciona una pregunta o haz una propia para recibir orientación financiera."
                          : _mensaje,
                      style: const TextStyle(color: Colors.white, height: 1.5),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// =================== SERVICIO IA (GEMINI) ===================

class IAService {
  // 🔑 TU CLAVE DE GEMINI INSERTADA AQUÍ
  final String apiKey =
      "AIzaSyCkQqp5l0O1YRtDIMu0OHpQzFIT8t8vhsE"; // <-- **PEGA TU CLAVE DE GEMINI REAL AQUÍ**

  late final GenerativeModel _model;

  IAService() {
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  // FUNCIÓN PARA LA PÁGINA DE MOTIVACIÓN
  Future<String> generarMotivacion(String mensaje) async {
    final fullPrompt =
        "Eres un coach experto en motivación financiera, das consejos, educación financiera y estrategias para ahorrar. Mensaje del usuario: $mensaje";

    try {
      final response = await _model.generateContent([Content.text(fullPrompt)]);
      return response.text ?? "Error: Respuesta vacía de la IA.";
    } catch (e) {
      return "Error [Motivación - Gemini]: No se pudo conectar. Revisa tu clave: ${e.toString()}";
    }
  }

  // FUNCIÓN PARA EL ANÁLISIS FINANCIERO INTELIGENTE (Segmentación y Motivación)
  Future<String> analizarFinanzas({
    required double ingresos,
    required List<Map<String, dynamic>> gastos,
    required List<Map<String, dynamic>> metas,
  }) async {
    final totalGastos = gastos.fold(
      0.0,
      (sum, g) => sum + (g['valor'] as num).toDouble(),
    );
    final disponible = ingresos - totalGastos;

    String detallesGastos = gastos.isEmpty
        ? "No hay gastos registrados."
        : gastos
              .map((g) {
                String recordatorio = g['fecha_recordatorio'] != null
                    ? " (Recordatorio: ${g['fecha_recordatorio']})"
                    : "";
                return "${g['nombre']}: \$${_formatearValor(g['valor'].toDouble())}$recordatorio";
              })
              .join("\n- ");

    String detallesMetas = metas.isEmpty
        ? "No hay metas registradas."
        : metas
              .map(
                (m) =>
                    "${m['nombre']} (Meta: \$${_formatearValor(m['meta'].toDouble())}, Ahorrado: \$${_formatearValor(m['ahorrado'].toDouble())})",
              )
              .join("\n- ");

    final prompt =
        """
    Eres un analista financiero experto y un coach motivacional. Analiza la siguiente situación:
    RESUMEN GLOBAL:
    - Ingreso Total: \$${_formatearValor(ingresos)}
    - Gasto Total: \$${_formatearValor(totalGastos)}
    - Dinero Disponible (Ahorro potencial): \$${_formatearValor(disponible)}
    DETALLE DE GASTOS:
    - $detallesGastos
    METAS DE AHORRO:
    - $detallesMetas

    Genera un análisis real, personalizado y sobre todo **MOTIVACIONAL**, usando los siguientes encabezados de Markdown, en este orden:
    
    ## 🎉 ¡Felicidades y Reconocimiento!
    (Basándose en los datos, si el usuario ha reducido gastos, ha añadido ahorros a una meta o ha mejorado su saldo disponible, debes **felicitarlo y reconocer su esfuerzo**. Si no hay cambios positivos notables, debes motivar a iniciar el cambio.)
    
    ## 🎯 Análisis de Situación Actual
    (Evalúa la salud financiera general: porcentaje de ahorro potencial, balance actual, y si las metas son alcanzables.)
    
    ## 🧐 Detección de Fugas
    (Identifica las 3 categorías de gastos más altas o problemáticas que están impidiendo el ahorro.)
    
    ## 💡 Plan de Acción
    (Da pasos iniciales e inmediatos para estabilizar el presupuesto.)

    ## 💰 Optimización de Ahorro
    (Estrategias específicas para canalizar el dinero disponible hacia las metas o crear un fondo de emergencia.)
    
    ## 📉 Optimización de Gastos
    (Consejos sobre cómo reducir los gastos detectados como fugas, con sugerencias concretas.)
    """;

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Análisis vacío. Por favor, reintenta.";
    } catch (e) {
      return "Error [Análisis IA - Gemini]: No se pudo conectar. Revisa tu clave: ${e.toString()}";
    }
  }
}

// =================== ANALISIS FINANCIERO (Llama al servicio IA) ===================

Future<String> obtenerAnalisisFinanciero() async {
  final prefs = await SharedPreferences.getInstance();

  double totalIngresos = 0.0;
  final ingresosData = prefs.getString('ingresos_${uid()}');
  if (ingresosData != null) {
    final lista = List<Map<String, dynamic>>.from(jsonDecode(ingresosData));
    totalIngresos = lista.fold(
      0.0,
      (sum, item) => sum + (item["valor"] as num).toDouble(),
    );
  }

  List<Map<String, dynamic>> listaGastos = [];
  final gastosData = prefs.getString('gastos_${uid()}');
  if (gastosData != null)
    listaGastos = List<Map<String, dynamic>>.from(jsonDecode(gastosData));

  List<Map<String, dynamic>> listaMetas = [];
  final metasData = prefs.getString('metas_${uid()}');
  if (metasData != null)
    listaMetas = List<Map<String, dynamic>>.from(jsonDecode(metasData));

  final ia = IAService();

  final resultado = await ia.analizarFinanzas(
    ingresos: totalIngresos,
    gastos: listaGastos,
    metas: listaMetas,
  );

  return resultado;
}
