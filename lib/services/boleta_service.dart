import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/boleta_item.dart';
import 'supabase_service.dart';

class BoletaService {
  static Future<List<BoletaItem>> getBoleta(String serie, String numero) async {
    final baseUrl = await SupabaseService.getNgrokUrl();

    if (baseUrl.isEmpty) {
      throw Exception('No se pudo obtener la URL del servidor');
    }

    final uri = Uri.parse('$baseUrl/boleta/$serie/$numero');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => BoletaItem.fromJson(item)).toList();
    } else {
      throw Exception('Error al cargar boleta: ${response.statusCode}');
    }
  }
}