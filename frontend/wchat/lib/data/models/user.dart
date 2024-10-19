

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String role;
  final String? department;
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
    this.department,
    required this.isManager,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      role: json['role'],
      department: json['department'],
      hourlyRate: json['hourly_rate'],
      isManager: json['is_manager'],
    );
  }
}