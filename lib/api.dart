import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String mensaje;
  final int? status;
  ApiException(this.mensaje, [this.status]);
  @override
  String toString() => mensaje;
}

class SesionExpirada extends ApiException {
  SesionExpirada() : super('Sesión no válida. Inicia sesión.', 401);
}

/// Cliente del backend Flask. El servidor guarda el JWT en la cookie `token`,
/// así que aquí se lee del `Set-Cookie` del login y se reenvía en el header `Cookie`.
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  static const _clave = 'token';
  final _storage = const FlutterSecureStorage();
  String? _token;
  Sesion? sesion;

  /// La UI la asigna para volver al login cuando el servidor responde 401.
  void Function()? onSesionExpirada;

  Uri _uri(String ruta) => Uri.parse('$apiUrl$ruta');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Cookie': 'token=$_token',
      };

  Future<bool> restaurarSesion() async {
    final t = await _storage.read(key: _clave);
    final s = t == null ? null : Sesion.desdeToken(t);
    if (t == null || s == null || s.expirada) {
      await _limpiar();
      return false;
    }
    _token = t;
    sesion = s;
    return true;
  }

  Future<void> _limpiar() async {
    _token = null;
    sesion = null;
    await _storage.delete(key: _clave);
  }

  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder.');
    } on SocketException {
      throw ApiException('Sin conexión a internet. Revisa tu red e inténtalo de nuevo.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor.');
    }
  }

  Map<String, dynamic> _cuerpo(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  /// Traduce 401 (sesión caída) y otros errores a excepciones.
  Future<void> _validar(http.Response r) async {
    if (r.statusCode == 401 && _token != null) {
      await _limpiar();
      onSesionExpirada?.call();
      throw SesionExpirada();
    }
  }

  Future<Sesion> login(String usuario, String password) async {
    final r = await _enviar(() => http.post(_uri('/auth/login'),
        headers: _headers, body: jsonEncode({'usuario': usuario, 'password': password})));
    final d = _cuerpo(r);
    if (r.statusCode == 401) throw ApiException('Usuario o contraseña inválidos', 401);
    if (r.statusCode != 200) throw ApiException(d['error']?.toString() ?? 'Error inesperado', r.statusCode);

    final cookie = RegExp(r'(?:^|[,;\s])token=([^;,\s]+)').firstMatch(r.headers['set-cookie'] ?? '');
    if (cookie == null) throw ApiException('El servidor no devolvió una sesión.');
    final token = cookie.group(1)!;

    _token = token;
    await _storage.write(key: _clave, value: token);
    sesion = Sesion.desdeToken(token) ??
        Sesion((d['id'] as num).toInt(), d['usuario'] as String, d['rol'] as String, null);
    return sesion!;
  }

  Future<void> logout() async {
    try {
      await http.post(_uri('/auth/logout'), headers: _headers).timeout(const Duration(seconds: 8));
    } catch (_) {/* aunque falle la red, se cierra la sesión local */}
    await _limpiar();
  }

  /// Solo Administrador y Auditor (403 para Cliente).
  Future<List<Usuario>> listarUsuarios() async {
    final r = await _enviar(() => http.get(_uri('/usuarios'), headers: _headers));
    await _validar(r);
    if (r.statusCode != 200) {
      throw ApiException(_cuerpo(r)['error']?.toString() ?? 'No se pudo cargar la lista.', r.statusCode);
    }
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Usuario.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Solo Administrador.
  Future<Usuario> registrar(String usuario, String password, String rol) async {
    final r = await _enviar(() => http.post(_uri('/auth/registro'),
        headers: _headers, body: jsonEncode({'usuario': usuario, 'password': password, 'rol': rol})));
    await _validar(r);
    if (r.statusCode != 201) {
      throw ApiException(_cuerpo(r)['error']?.toString() ?? 'Error inesperado', r.statusCode);
    }
    return Usuario.fromJson(_cuerpo(r));
  }
}
