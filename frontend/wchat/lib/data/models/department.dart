class Department {
  final int id;
  final String name;
  final String description;
  final List<Map<String, dynamic>>? users;

  Department({
    required this.id,
    required this.name,
    required this.description,
    this.users,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    var usersList = json['users'] as List?;
    return Department(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      users: usersList?.cast<Map<String, dynamic>>(),
    );
  }
}