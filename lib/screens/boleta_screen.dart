import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/boleta_item.dart';
import '../models/usuario.dart';
import '../models/firma.dart';
import '../services/boleta_service.dart';
import '../services/supabase_service.dart';
import '../screens/login_screen.dart';

class BoletaScreen extends StatefulWidget {
  final Usuario usuarioActual;
  const BoletaScreen({super.key, required this.usuarioActual});

  @override
  State<BoletaScreen> createState() => _BoletaScreenState();
  
}

class _BoletaScreenState extends State<BoletaScreen> {
  final _serieController = TextEditingController(text: '026');
  final _numeroController = TextEditingController();

  List<BoletaItem> _items = [];
  bool _loading = false;
  String? _error;
  String _filtroTipo = 'S';
  final Set<String> _fechasAbiertas = {};
  bool _totalesAbierto = false;
  List<Map<String, String>> _favoritos = [];
  String? _serieActual;
  String? _numeroActual;

  // Firmas
  List<Firma> _firmas = [];
  Map<int, Usuario> _usuariosMap = {};
  Map<String, String> _ordenInfo = {};

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
    _cargarUsuarios();
    
    
  }

  Future<void> _cargarUsuarios() async {
    final map = await SupabaseService.getUsuariosMap();
    setState(() => _usuariosMap = map);
  }

  Future<void> _cargarFirmas() async {
    if (_serieActual == null || _numeroActual == null) return;
    final firmas = await SupabaseService.getFirmas(_serieActual!, _numeroActual!);
    // Resolver nombres
    for (final f in firmas) {
      final u = _usuariosMap[f.usuarioId];
      if (u != null) { f.nombre = u.nombre; f.area = u.area; }
    }
    setState(() => _firmas = firmas);
  }

  Future<void> _firmarFecha(String fecha) async {
    // Fecha y hora actual formateada
    final ahora = DateTime.now();
    final fechaFirma =
        '${ahora.day.toString().padLeft(2, '0')}/'
        '${ahora.month.toString().padLeft(2, '0')}/'
        '${ahora.year}  '
        '${ahora.hour.toString().padLeft(2, '0')}:'
        '${ahora.minute.toString().padLeft(2, '0')}';

    final firma = Firma(
      fecha: fecha,
      fechaFirma: fechaFirma,   // ← nuevo
      usuarioId: widget.usuarioActual.id,
      tipo: _filtroTipo,
    );

    await SupabaseService.agregarFirma(
      serie: _serieActual!,
      numero: _numeroActual!,
      op: _items.isNotEmpty ? _items.first.opId : '',
      firma: firma,
    );
    await _cargarFirmas();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firmado como ${widget.usuarioActual.nombre} — $fecha'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

String _rolLabel(String area, String tipo) {
  if (tipo == 'S') {
    return area == 'ALMACEN' ? 'ENTREGADO POR' : 'RECIBIDO POR';
  } else {
    // En Ingresos: PRODUCCION y ACABADOS entregan, ALMACEN recibe
    if (area == 'PRODUCCION' || area == 'ACABADOS') return 'ENTREGADO POR';
    return 'RECIBIDO POR';
  }
}

  // Firmas de una fecha específica
  List<Firma> _firmasDeFecha(String fecha) =>
      _firmas.where((f) => f.fecha == fecha).toList();

  // ── FAVORITOS (sin cambios) ──
  Future<void> _cargarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favoritos') ?? '[]';
    setState(() {
      _favoritos = List<Map<String, String>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, String>.from(e)),
      );
    });
  }

  Future<void> _guardarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favoritos', jsonEncode(_favoritos));
  }

  bool _esFavorito() =>
      _favoritos.any((f) => f['serie'] == _serieActual && f['numero'] == _numeroActual);

Future<void> _toggleFavorito() async {
  if (_serieActual == null || _numeroActual == null) return;
  setState(() {
    if (_esFavorito()) {
      _favoritos.removeWhere(
          (f) => f['serie'] == _serieActual && f['numero'] == _numeroActual);
    } else {
      // Obtener fechas únicas de S e I desde los items actuales
      final fechasS = _items
          .where((i) => i.tipoMode == 'S')
          .map((i) => i.fechaCreacion.split('  ').first)
          .toSet()
          .join(',');
      final fechasI = _items
          .where((i) => i.tipoMode == 'I')
          .map((i) => i.fechaCreacion.split('  ').first)
          .toSet()
          .join(',');

      _favoritos.add({
        'serie': _serieActual!,
        'numero': _numeroActual!,
        'descripcion': _items.isNotEmpty ? _items.first.descripcionFinal : '',
        'fechas_s': fechasS,   // ← nuevo
        'fechas_i': fechasI,   // ← nuevo
      });
    }
  });
  await _guardarFavoritos();
}

  Future<void> _eliminarFavorito(Map<String, String> fav) async {
    setState(() => _favoritos.remove(fav));
    await _guardarFavoritos();
  }

void _abrirFavoritos() {
  final Map<String, List<Firma>> firmasPorFav = {};

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        Future<void> cargarFirmasFavoritos() async {
          for (final fav in _favoritos) {
            final key = '${fav['serie']}-${fav['numero']}';
            if (!firmasPorFav.containsKey(key)) {
              final firmas = await SupabaseService.getFirmas(fav['serie']!, fav['numero']!);
              for (final f in firmas) {
                final u = _usuariosMap[f.usuarioId];
                if (u != null) { f.nombre = u.nombre; f.area = u.area; }
              }
              firmasPorFav[key] = firmas;
            }
          }
          setModalState(() {});
        }

        if (firmasPorFav.isEmpty && _favoritos.isNotEmpty) {
          cargarFirmasFavoritos();
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Boletas Guardadas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_favoritos.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No hay boletas guardadas.',
                              style: TextStyle(color: Colors.grey))))
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _favoritos.length,
                      itemBuilder: (_, i) {
                        final fav = _favoritos[i];
                        final key = '${fav['serie']}-${fav['numero']}';
                        final firmasFav = firmasPorFav[key] ?? [];
                        final cargado = firmasPorFav.containsKey(key);

                        
                        // Fechas donde el área actual ya firmó, separadas por tipo
                        final firmadasS = <String>{};
                        final firmadasI = <String>{};
                        for (final f in firmasFav) {
                          if (f.area == widget.usuarioActual.area) {
                            if (f.tipo == 'S') firmadasS.add(f.fecha);
                            if (f.tipo == 'I') firmadasI.add(f.fecha);
                          }
                        }
                        
                        // Fechas desde favoritos guardados (movimientos del GESCOM)
                        final todasFechasS = (fav['fechas_s'] ?? '')
                            .split(',')
                            .where((f) => f.isNotEmpty)
                            .toList();
                        final todasFechasI = (fav['fechas_i'] ?? '')
                            .split(',')
                            .where((f) => f.isNotEmpty)
                            .toList();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Encabezado
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.receipt_long, color: Colors.blue, size: 20),
                                        const SizedBox(width: 8),
                                        Text('${fav['serie']} - ${fav['numero']}',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.open_in_new, color: Colors.blue, size: 20),
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            _serieController.text = fav['serie']!;
                                            _numeroController.text = fav['numero']!.replaceFirst('000', '');
                                            await _buscar();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          onPressed: () async {
                                            await _eliminarFavorito(fav);
                                            setModalState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                if (widget.usuarioActual.area != 'CALIDAD') ...[
                                  const Divider(height: 12),
                                  if (!cargado)
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 12, height: 12,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.grey.shade400),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('Verificando firmas...',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                      ],
                                    )
                                    else ...[
                                      // Salidas (S)
                                      if (todasFechasS.isNotEmpty) ...[
                                        const Text('Salidas (S):',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        ...todasFechasS.map((fecha) {
                                          final firmado = firmadasS.contains(fecha);
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 3),
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 8),
                                                Text(fecha, style: const TextStyle(fontSize: 11)),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: firmado ? Colors.green.shade600 : Colors.orange.shade700,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    firmado ? '✓ FIRMADO' : '⏳ PENDIENTE',
                                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 6),
                                      ],
                                      // Ingresos (I)
                                      if (todasFechasI.isNotEmpty) ...[
                                        const Text('Ingresos (I):',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        ...todasFechasI.map((fecha) {
                                          final firmado = firmadasI.contains(fecha);
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 3),
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 8),
                                                Text(fecha, style: const TextStyle(fontSize: 11)),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: firmado ? Colors.green.shade600 : Colors.orange.shade700,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    firmado ? '✓ FIRMADO' : '⏳ PENDIENTE',
                                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                      if (todasFechasS.isEmpty && todasFechasI.isEmpty)
                                        Text('Sin movimientos registrados',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  Map<String, List<BoletaItem>> _agruparPorFecha(List<BoletaItem> items) {
    final Map<String, List<BoletaItem>> grupos = {};
    for (final item in items) {
      final soloFecha = item.fechaCreacion.split('  ').first;
      grupos.putIfAbsent(soloFecha, () => []).add(item);
    }
    return grupos;
  }

  Map<String, _ResumenCodigo> _calcularTotales(List<BoletaItem> items) {
    final Map<String, _ResumenCodigo> totales = {};
    for (final item in items) {
      final codigo = item.productoConsumido;
      if (totales.containsKey(codigo)) {
        totales[codigo]!.cantidad += item.cantidad;
      } else {
        totales[codigo] = _ResumenCodigo(
          codigo: codigo,
          descripcion: item.descripcionConsumido,
          cantidad: item.cantidad,
          unidad: item.unidad,
        );
      }
    }
    return totales;
  }

Future<void> _buscar() async {
  final serie = _serieController.text.trim();
  final numero = _numeroController.text.trim().padLeft(7, '0');
  if (serie.isEmpty || numero.isEmpty) {
    setState(() => _error = 'Ingresa Serie y Número');
    return;
  }
  setState(() {
    _loading = true; _error = null; _items = [];
    _fechasAbiertas.clear(); _totalesAbierto = false;
    _serieActual = serie; _numeroActual = numero;
    _firmas = []; _ordenInfo = {};  // ← limpiar también
  });
  try {
    final items = await BoletaService.getBoleta(serie, numero);
    setState(() {
      _items = items;
      if (items.isEmpty) _error = 'No se encontraron registros';
    });
    await _cargarFirmas();
    // Cargar info de ordenes
    final ordenInfo = await SupabaseService.getOrdenInfo(serie, numero);
    setState(() => _ordenInfo = ordenInfo);  // ← agregar aquí
  } catch (e) {
    setState(() => _error = e.toString());
  } finally {
    setState(() => _loading = false);
  }
}

Widget _guiaItem(IconData icono, String titulo, String descripcion) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: Colors.blue.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$titulo: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: descripcion),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final itemsFiltrados = _items.where((i) => i.tipoMode == _filtroTipo).toList();
    final grupos = _agruparPorFecha(itemsFiltrados);
    final fechas = grupos.keys.toList();
    final totales = _calcularTotales(itemsFiltrados);
    final esFav = _esFavorito();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cerrar sesión'),
                content: Text('¿Deseas cerrar la sesión de ${widget.usuarioActual.nombre}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('usuario_sesion');
                      await prefs.remove('fecha_login');
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            );
          },
          child: const Text('Boleta Digital'),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Usuario actual
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                widget.usuarioActual.nombre.split(' ').first,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: 'Boletas guardadas',
            onPressed: _abrirFavoritos,
          ),
          if (_items.isNotEmpty)
            IconButton(
              icon: Icon(esFav ? Icons.bookmark : Icons.bookmark_border),
              tooltip: esFav ? 'Quitar de favoritos' : 'Guardar boleta',
              onPressed: _toggleFavorito,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buscador
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _serieController,
                    decoration: const InputDecoration(
                        labelText: 'Serie', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('000',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _numeroController,
                    decoration: const InputDecoration(
                        labelText: '4 dígitos', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _buscar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Icon(Icons.search),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            if (_items.isNotEmpty) ...[
              _encabezado(_items.first),
              const SizedBox(height: 8),

              // Filtro S / I
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _filtroTipo = 'S'; _fechasAbiertas.clear(); _totalesAbierto = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _filtroTipo == 'S' ? Colors.red.shade700 : Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                        ),
                        child: Center(
                          child: Text('Salidas (S)',
                              style: TextStyle(
                                  color: _filtroTipo == 'S' ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _filtroTipo = 'I'; _fechasAbiertas.clear(); _totalesAbierto = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _filtroTipo == 'I' ? Colors.green.shade700 : Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                        ),
                        child: Center(
                          child: Text('Ingresos (I)',
                              style: TextStyle(
                                  color: _filtroTipo == 'I' ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // TOTALES colapsable
              if (totales.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => _totalesAbierto = !_totalesAbierto),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(8),
                        topRight: const Radius.circular(8),
                        bottomLeft: Radius.circular(_totalesAbierto ? 0 : 8),
                        bottomRight: Radius.circular(_totalesAbierto ? 0 : 8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL POR CÓDIGO',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Icon(_totalesAbierto ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white),
                      ],
                    ),
                  ),
                ),
                if (_totalesAbierto)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.shade100),
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                    ),
                    child: Column(
                      children: totales.values.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.codigo,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(r.descripcion,
                                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                ],
                              ),
                            ),
                            Text(
                              '${r.cantidad % 1 == 0 ? r.cantidad.toInt() : r.cantidad} ${r.unidad}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13,
                                color: _filtroTipo == 'S' ? Colors.red.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                const SizedBox(height: 10),
              ],

              // FECHAS colapsables con firmas
              ...fechas.map((fecha) {
                final itemsDelDia = grupos[fecha]!;
                final abierto = _fechasAbiertas.contains(fecha);
                final firmasDia = _firmasDeFecha(fecha);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        if (abierto) _fechasAbiertas.remove(fecha);
                        else _fechasAbiertas.add(fecha);
                      }),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(top: 6, bottom: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fecha,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Row(
                                  children: [
                                    _badgeFirma(firmasDia),          // ← nuevo
                                    const SizedBox(width: 6),
                                    Text('${itemsDelDia.length} reg.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    const SizedBox(width: 4),
                                    Icon(abierto ? Icons.expand_less : Icons.expand_more,
                                        size: 20, color: Colors.grey.shade700),
                                  ],
                                ),
                          ],
                        ),
                      ),
                    ),
                    if (abierto) ...[
                      // Items del día
                      ...itemsDelDia.map((item) => _itemCard(item)),
                      const SizedBox(height: 4),

                      // Firmas existentes de este día
                      if (firmasDia.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: firmasDia.map((f) {
                              final rol = _rolLabel(f.area, f.tipo);
                              final color = f.area == 'ALMACEN'
                                  ? Colors.blue.shade700
                                  : Colors.orange.shade700;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.verified_user, size: 16, color: color),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                          children: [
                                            TextSpan(
                                              text: '$rol: ',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: color),
                                            ),
                                            TextSpan(text: f.nombre.isNotEmpty ? f.nombre : 'ID ${f.usuarioId}'),
                                            TextSpan(
                                              text: f.fechaFirma.isNotEmpty ? '\n${f.fechaFirma}' : '',  // ← nuevo
                                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Botón firmar
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: widget.usuarioActual.area == 'CALIDAD'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.visibility, size: 16, color: Colors.grey.shade500),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CALIDAD — solo lectura',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: () => _firmarFecha(fecha),
                                  icon: const Icon(Icons.draw, size: 18),
                                  label: Text(
                                    'Firmar como ${widget.usuarioActual.nombre} (${widget.usuarioActual.area})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue.shade800,
                                    side: BorderSide(color: Colors.blue.shade800),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                );
              }),

              if (itemsFiltrados.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Sin registros de tipo $_filtroTipo',
                        style: const TextStyle(color: Colors.grey)),
                  ),
                ),
              ] else if (!_loading && _error == null) ...[
                const SizedBox(height: 24),
                // ── GUÍA DE USO ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text('¿Cómo usar la app?',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.blue.shade700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _guiaItem(Icons.tag, 'Serie',
                          'Código de la serie de la boleta. Por defecto es 026 y puede admitir A26 o P26'),
                      _guiaItem(Icons.pin, 'Número',
                          'Ingresa los últimos 4 dígitos. Ej: si el número es 0001010, escribe 1010.'),
                      _guiaItem(Icons.search, 'Buscar',
                          'Presiona el botón para cargar los materiales de la boleta.'),
                      _guiaItem(Icons.swap_horiz, 'Salidas / Ingresos',
                          'Filtra entre materiales que salieron (S) o ingresaron (I) del almacén.'),
                      _guiaItem(Icons.calculate_outlined, 'Total por código',
                          'Muestra la suma total de cada material en toda la boleta.'),
                      _guiaItem(Icons.calendar_today, 'Fechas',
                          'Los movimientos están agrupados por fecha. Toca una fecha para expandirla.'),
                      _guiaItem(Icons.draw, 'Firmar',
                          'Registra tu conformidad en una fecha específica como ${widget.usuarioActual.area}.'),
                      _guiaItem(Icons.bookmark_border, 'Guardar boleta',
                          'Guarda la boleta actual en favoritos para acceder rápido después.'),
                      _guiaItem(Icons.bookmarks_outlined, 'Favoritos',
                          'Ver todas tus boletas guardadas y su estado de firma por fecha.'),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

Widget _badgeFirma(List<Firma> firmasDia) {
  // CALIDAD no ve el badge
  if (widget.usuarioActual.area == 'CALIDAD') return const SizedBox.shrink();
  
  final areaActual = widget.usuarioActual.area;
  final firmado = firmasDia.any((f) => f.area == areaActual);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: firmado ? Colors.green.shade600 : Colors.orange.shade700,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      firmado ? '✓ FIRMADO' : '⏳ PENDIENTE',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _encabezado(BoletaItem item) {
  return Card(
    color: Colors.blue.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ID: ${item.opId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              if (_ordenInfo['op_app']?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _ordenInfo['op_app']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
          Text('Serie: ${item.serie}   Número: ${item.numero}'),
          // ← Quitamos Producto y Descripción
          if (_ordenInfo['maquina']?.isNotEmpty == true ||
              _ordenInfo['molde']?.isNotEmpty == true) ...[
            const Divider(height: 12),
            // ← Ahora en columna en vez de Row
            if (_ordenInfo['maquina']?.isNotEmpty == true)
              Row(
                children: [
                  Icon(Icons.precision_manufacturing,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text('Máquina: ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 12)),
                  Text(_ordenInfo['maquina']!,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            if (_ordenInfo['molde']?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.view_in_ar,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text('Molde: ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 12)),
                  Text(_ordenInfo['molde']!,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

  Widget _itemCard(BoletaItem item) {
    final esIngreso = item.tipoMode == 'I';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: esIngreso ? Colors.green.shade700 : Colors.red.shade700,
          child: Text(item.tipoMode,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(item.descripcionConsumido),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código: ${item.productoConsumido}'),
            Text(item.fechaCreacion,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        trailing: Text(
          '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad} ${item.unidad}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _ResumenCodigo {
  final String codigo;
  final String descripcion;
  double cantidad;
  final String unidad;

  _ResumenCodigo({
    required this.codigo,
    required this.descripcion,
    required this.cantidad,
    required this.unidad,
  });
}