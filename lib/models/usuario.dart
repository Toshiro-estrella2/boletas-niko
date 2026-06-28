class Usuario {
  final int id;
  final String usuario;
  final String nombre;
  final String area;

  Usuario({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.area,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      usuario: json['usuario'] as String,
      nombre: json['nombre'] as String,
      area: json['area'] as String,
    );
  }
}