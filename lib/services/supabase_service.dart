import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario.dart';
import '../models/firma.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // Login — busca usuario por nombre de usuario
  static Future<Usuario?> login(String usuario) async {
    final res = await _client
        .from('usuarios_boletas')
        .select()
        .eq('usuario', usuario.toLowerCase().trim())
        .maybeSingle();

    if (res == null) return null;
    return Usuario.fromJson(res);
  }

  // Trae todos los usuarios para resolver nombres
  static Future<Map<int, Usuario>> getUsuariosMap() async {
    final res = await _client.from('usuarios_boletas').select();
    final map = <int, Usuario>{};
    for (final row in res) {
      final u = Usuario.fromJson(row);
      map[u.id] = u;
    }
    return map;
  }

  // Trae firmas de una boleta
  static Future<List<Firma>> getFirmas(String serie, String numero) async {
    final res = await _client
        .from('boletas')
        .select('firmas')
        .eq('serie', serie)
        .eq('numero', numero)
        .maybeSingle();

    if (res == null) return [];

    final List<dynamic> firmasRaw = res['firmas'] ?? [];
    return firmasRaw.map((f) => Firma.fromJson(f)).toList();
  }

  static String convertirOpFormat(String serie, String numero) {
    final serieNum = int.tryParse(serie) ?? 0;       // 026 → 26
    final ultimosCuatro = numero.length >= 4
        ? numero.substring(numero.length - 4)         // 0001010 → 1010
        : numero;
    return '$ultimosCuatro-$serieNum';                // → "1010-26"
  }
  // Busca maquina y molde en tabla ordenes
  static Future<Map<String, String>> getOrdenInfo(String serie, String numero) async {
    try {
      final opFormato = convertirOpFormat(serie, numero);

      final res = await _client
          .from('ordenes')
          .select('op, maquina, molde')
          .eq('op', opFormato)
          .maybeSingle();

      if (res == null) return {'maquina': '', 'molde': '', 'op_app': opFormato};

      return {
        'op_app': res['op']?.toString() ?? opFormato,
        'maquina': res['maquina']?.toString() ?? '',
        'molde': res['molde']?.toString() ?? '',
      };
    } catch (_) {
      return {'maquina': '', 'molde': '', 'op_app': ''};
    }
  }

  static Future<String> getNgrokUrl() async {
  try {
    final res = await _client
        .from('ngrok')
        .select('url')
        .eq('id', 1)
        .single();
    return res['url'] as String;
  } catch (_) {
    return ''; // si falla retorna vacío
  }
}

  // Agrega una firma a la boleta (crea el registro si no existe)
  static Future<void> agregarFirma({
    required String serie,
    required String numero,
    required String op,
    required Firma firma,
  }) async {
    // ¿Ya existe la boleta?
    final existente = await _client
        .from('boletas')
        .select('id, firmas')
        .eq('serie', serie)
        .eq('numero', numero)
        .maybeSingle();

    if (existente == null) {
      // Crear boleta nueva con esta firma
      await _client.from('boletas').insert({
        'serie': serie,
        'numero': numero,
        'op': op,
        'firmas': [firma.toJson()],
      });
    } else {
      // Agregar firma al array existente
      final List<dynamic> firmasActuales = existente['firmas'] ?? [];
      firmasActuales.add(firma.toJson());
      await _client
          .from('boletas')
          .update({'firmas': firmasActuales})
          .eq('id', existente['id']);
    }
  }
}