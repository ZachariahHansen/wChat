class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String role;
  final List<String> departments;
  final bool isManager;
  final double hourlyRate;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.hourlyRate,
    required this.departments,
    required this.isManager,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse departments string into List<String>
    List<String> parseDepartments(String? depts) {
      if (depts == null || depts.isEmpty) return [];
      return depts.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    }

    return User(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      role: json['role_name'] ?? '',
      departments: parseDepartments(json['departments']),
      hourlyRate: json['hourly_rate'].toDouble(),
      isManager: json['is_manager'],
    );
  }
}
