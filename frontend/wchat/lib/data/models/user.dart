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
  final bool fullTime;
  final List<Availability> availability;

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
    required this.fullTime,
    required this.availability,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse departments
    List<String> parseDepartments(dynamic depts) {
      if (depts == null) return [];
      // If it's already a string, split it
      if (depts is String) {
        return depts.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
      }
      // If it's a single department as a string
      if (depts is String) {
        return [depts];
      }
      return [];
    }

    // Parse availability array into List<Availability>
    List<Availability> parseAvailability(List<dynamic>? availabilityJson) {
      if (availabilityJson == null) return [];
      return availabilityJson.map((avail) => Availability.fromJson(avail)).toList();
    }

    return User(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      role: json['role'] ?? json['role_name'] ?? '', // Check both 'role' and 'role_name'
      departments: parseDepartments(json['department'] ?? json['departments']), // Check both singular and plural
      hourlyRate: (json['hourly_rate'] is int) 
          ? json['hourly_rate'].toDouble() 
          : json['hourly_rate'],
      isManager: json['is_manager'],
      fullTime: json['full_time'] ?? true,
      availability: parseAvailability(json['availability'] as List?),
    );
  }

  // Helper method to get availability for a specific day
  Availability? getAvailabilityForDay(int day) {
    try {
      return availability.firstWhere((a) => a.day == day);
    } catch (e) {
      return null;
    }
  }

  // Helper method to check if user is available on a specific day
  bool isAvailableOnDay(int day) {
    final dayAvailability = getAvailabilityForDay(day);
    return dayAvailability?.isAvailable ?? false;
  }
}

class Availability {
  final int day;
  final bool isAvailable;
  final String? startTime;
  final String? endTime;

  Availability({
    required this.day,
    required this.isAvailable,
    this.startTime,
    this.endTime,
  });

  factory Availability.fromJson(Map<String, dynamic> json) {
    return Availability(
      day: json['day'],
      isAvailable: json['is_available'],
      startTime: json['start_time'],
      endTime: json['end_time'],
    );
  }
}