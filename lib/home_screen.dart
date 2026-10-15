import 'package:flutter/material.dart';

import 'api.dart';
import 'login_screen.dart';
import 'models.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _salir(BuildContext context) async {
    await ApiClient.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ApiClient.instance.sesion!;
    // Misma lógica que PANTALLAS en routes.py: una vista por rol (rol desconocido → Cliente)
    final (titulo, cuerpo) = switch (s.rol) {
      Rol.administrador => ('Panel de administración', const _VistaAdmin()),
      Rol.auditor => ('Vista de auditoría', const _VistaAuditor()),
      _ => ('Mi cuenta', _VistaCliente(sesion: s)),
    };

    return PopScope(
      canPop: false, // el botón Atrás no regresa al login (US02-E2)
      child: Scaffold(
        appBar: AppBar(
          title: Text(titulo),
          actions: [IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout), onPressed: () => _salir(context))],
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(children: [
                Expanded(child: Text('Hola, ${s.usuario}', style: Theme.of(context).textTheme.titleLarge)),
                Chip(label: Text('ID ${s.id} · ${s.rol}')),
              ]),
            ),
            Expanded(child: cuerpo),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Cliente ─────────────────────────
class _VistaCliente extends StatelessWidget {
  final Sesion sesion;
  const _VistaCliente({required this.sesion});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Bienvenido. Aquí está la información de tu cuenta.'),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          ListTile(title: const Text('ID'), trailing: Text('${sesion.id}')),
          ListTile(title: const Text('Usuario'), trailing: Text(sesion.usuario)),
          ListTile(title: const Text('Rol'), trailing: Text(sesion.rol)),
        ])),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text('Tu cuenta es de cliente: no tienes acceso a la lista de usuarios ni puedes crear cuentas.'),
          ),
        ),
      ]);
}

// ───────────────────────── Auditor ─────────────────────────
class _VistaAuditor extends StatelessWidget {
  const _VistaAuditor();
  @override
  Widget build(BuildContext context) => const _ListaUsuarios(
        encabezado: 'Acceso de solo lectura. Puedes consultar los usuarios, pero no crearlos.',
      );
}

// ───────────────────────── Administrador ─────────────────────────
class _VistaAdmin extends StatefulWidget {
  const _VistaAdmin();
  @override
  State<_VistaAdmin> createState() => _VistaAdminState();
}

class _VistaAdminState extends State<_VistaAdmin> {
  int _version = 0; // al cambiar, la lista se vuelve a cargar

  Future<void> _nuevoUsuario() async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FormularioNuevo(),
    );
    if (creado == true) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        _ListaUsuarios(
          key: ValueKey(_version),
          encabezado: 'Creas usuarios, eliges su rol y consultas la lista completa.',
        ),
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _nuevoUsuario,
            icon: const Icon(Icons.person_add),
            label: const Text('Crear usuario'),
          ),
        ),
      ]);
}

class _FormularioNuevo extends StatefulWidget {
  const _FormularioNuevo();
  @override
  State<_FormularioNuevo> createState() => _FormularioNuevoState();
}

class _FormularioNuevoState extends State<_FormularioNuevo> {
  final _usuario = TextEditingController(), _pass = TextEditingController(), _pass2 = TextEditingController();
  String _rol = Rol.cliente;
  bool _cargando = false;
  String? _error;

  Future<void> _crear() async {
    if (_pass.text != _pass2.text) return setState(() => _error = 'Las contraseñas no coinciden.');
    setState(() { _cargando = true; _error = null; });
    try {
      final u = await ApiClient.instance.registrar(_usuario.text.trim(), _pass.text, _rol);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Usuario creado (ID ${u.id}, rol ${u.rol}).')));
      Navigator.pop(context, true);
    } on SesionExpirada {
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() { _usuario.dispose(); _pass.dispose(); _pass2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Crear usuario', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _usuario, decoration: const InputDecoration(labelText: 'Usuario')),
            const SizedBox(height: 12),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña (mín. 6)')),
            const SizedBox(height: 12),
            TextField(controller: _pass2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar contraseña')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: Rol.todos.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _rol = v ?? Rol.cliente),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cargando ? null : _crear,
              child: _cargando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Crear usuario'),
            ),
          ]),
        ),
      );
}

// ───────────────────────── Lista compartida (Admin y Auditor) ─────────────────────────
class _ListaUsuarios extends StatefulWidget {
  final String encabezado;
  const _ListaUsuarios({super.key, required this.encabezado});
  @override
  State<_ListaUsuarios> createState() => _ListaUsuariosState();
}

class _ListaUsuariosState extends State<_ListaUsuarios> {
  late Future<List<Usuario>> _futuro = ApiClient.instance.listarUsuarios();

  Future<void> _recargar() async {
    setState(() => _futuro = ApiClient.instance.listarUsuarios());
    await _futuro.catchError((_) => <Usuario>[]);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _recargar,
        child: FutureBuilder<List<Usuario>>(
          future: _futuro,
          builder: (context, snap) {
            final hijos = <Widget>[
              Padding(padding: const EdgeInsets.all(16), child: Text(widget.encabezado)),
            ];
            if (snap.connectionState != ConnectionState.done) {
              hijos.add(const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
            } else if (snap.hasError) {
              hijos.add(Padding(padding: const EdgeInsets.all(16), child: Text('${snap.error}')));
            } else {
              hijos.addAll(snap.data!.map((u) => ListTile(
                    leading: CircleAvatar(child: Text('${u.id}')),
                    title: Text(u.usuario),
                    trailing: Chip(label: Text(u.rol)),
                  )));
              hijos.add(const SizedBox(height: 90)); // espacio para el botón flotante
            }
            return ListView(physics: const AlwaysScrollableScrollPhysics(), children: hijos);
          },
        ),
      );
}
