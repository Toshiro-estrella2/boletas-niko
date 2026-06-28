class BoletaItem {
  final String opId;
  final String serie;
  final String numero;
  final String productoFinal;
  final String descripcionFinal; // ← nuevo
  final String productoConsumido;
  final String descripcionConsumido; // ← nuevo
  final String fechaCreacion;
  final String tipoMode;
  final String nomProducto;
  final double cantidad;
  final String unidad;

  BoletaItem({
    required this.opId,
    required this.serie,
    required this.numero,
    required this.productoFinal,
    required this.descripcionFinal, // ← nuevo
    required this.productoConsumido,
    required this.descripcionConsumido, // ← nuevo
    required this.fechaCreacion,
    required this.tipoMode,
    required this.nomProducto,
    required this.cantidad,
    required this.unidad,
  });

  factory BoletaItem.fromJson(Map<String, dynamic> json) {
    // Convertir OLE Date a DateTime legible
    String fechaFormateada = '';
    final fechaRaw = json['FechaCreacion'];
    if (fechaRaw != null) {
      try {
        final oleDate = double.parse(fechaRaw.toString());
        final fecha = DateTime(
          1899,
          12,
          30,
        ).add(Duration(milliseconds: (oleDate * 24 * 60 * 60 * 1000).round()));
        fechaFormateada =
            '${fecha.day.toString().padLeft(2, '0')}/'
            '${fecha.month.toString().padLeft(2, '0')}/'
            '${fecha.year}  '
            '${fecha.hour.toString().padLeft(2, '0')}:'
            '${fecha.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        fechaFormateada = fechaRaw.toString();
      }
    }

    return BoletaItem(
      opId: json['OP_Id']?.toString() ?? '',
      serie: json['Serie']?.toString() ?? '',
      numero: json['Numero']?.toString() ?? '',
      productoFinal: json['ProductoFinal']?.toString() ?? '',
      descripcionFinal: json['DescripcionFinal']?.toString() ?? '',
      productoConsumido: json['ProductoConsumido']?.toString() ?? '',
      descripcionConsumido: json['DescripcionConsumido']?.toString() ?? '',
      fechaCreacion: fechaFormateada, // ← ya formateada
      tipoMode: json['TipoMode']?.toString() ?? '',
      nomProducto: json['Nom_Producto']?.toString() ?? '',
      cantidad: json['Cantidad'] != null
          ? (json['Cantidad'] as num).toDouble()
          : 0.0,
      unidad: json['Unidad']?.toString() ?? '',
    );
  }
}