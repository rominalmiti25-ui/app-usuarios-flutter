import 'dart:convert';

class Rol {
  static const administrador = 'Administrador';
  static const auditor = 'Auditor';
  static const cliente = 'Cliente';
  static const todos = [cliente, auditor, administrador];
}

class Usuario {
  final int id;
  final String usuario;
  final String rol;
  Usuario(this.id, this.usuario, this.rol);

  factory Usuario.fromJson(Map<String, dynamic> j) =>
      Usuario((j['id'] as num).toInt(), j['usuario'] as String, j['rol'] as String);
}

/// Datos de la sesión actual (equivale al `sesion` que Flask inyectaba en los templates).
class Sesion {
  final int id;
  final String usuario;
  final String rol;
  final DateTime? expira;
  Sesion(this.id, this.usuario, this.rol, this.expira);

  bool get expirada => expira != null && DateTime.now().isAfter(expira!);

  /// Lee el payload del JWT (sub, usuario, rol, exp). No valida la firma: eso lo hace el servidor.
  static Sesion? desdeToken(String token) {
    try {
      final partes = token.split('.');
      if (partes.length != 3) return null;
      final p = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))))
          as Map<String, dynamic>;
      final exp = p['exp'] as num?;
      return Sesion(
        int.parse(p['sub'].toString()),
        p['usuario'] as String,
        p['rol'] as String,
        exp == null ? null : DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000),
      );
    } catch (_) {
      return null;
    }
  }
}
