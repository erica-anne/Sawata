class GuardianContact {
  GuardianContact({
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
  });

  final String name;
  final String relationship;
  final String phone;
  final String email;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class GuardianMessage {
  GuardianMessage({
    required this.text,
    required this.time,
    required this.fromUser,
  });

  final String text;
  final DateTime time;
  final bool fromUser;
}
