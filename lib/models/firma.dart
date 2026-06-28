class Firma {
  final String fecha;          // fecha de la boleta (agrupación)
  final String fechaFirma;     // fecha y hora real de la firma ← nuevo
  final int usuarioId;
  final String tipo;
  String nombre;
  String area;

  Firma({
    required this.fecha,
    required this.fechaFirma,  // ← nuevo
    required this.usuarioId,
    required this.tipo,
    this.nombre = '',
    this.area = '',
  });

  factory Firma.fromJson(Map<String, dynamic> json) {
    return Firma(
      fecha: json['fecha'] as String,
      fechaFirma: json['fecha_firma'] as String? ?? '',  // ← nuevo
      usuarioId: json['usuario_id'] as int,
      tipo: json['tipo'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'fecha': fecha,
    'fecha_firma': fechaFirma,   // ← nuevo
    'usuario_id': usuarioId,
    'tipo': tipo,
  };
}