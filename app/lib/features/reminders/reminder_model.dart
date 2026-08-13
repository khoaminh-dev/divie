class MedicineReminder {
  const MedicineReminder({
    required this.id,
    required this.name,
    required this.time,
    this.note = '',
    this.enabled = true,
  });

  final int id;
  final String name;
  final String time;
  final String note;
  final bool enabled;

  String get displayLabel => note.isEmpty ? name : '$name · $note';

  MedicineReminder copyWith({
    String? name,
    String? time,
    String? note,
    bool? enabled,
  }) => MedicineReminder(
    id: id,
    name: name ?? this.name,
    time: time ?? this.time,
    note: note ?? this.note,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'time': time,
    'note': note,
    'enabled': enabled,
  };

  factory MedicineReminder.fromJson(
    Map<String, dynamic> json,
  ) => MedicineReminder(
    id: (json['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    name: json['name'] as String? ?? '',
    time: json['time'] as String? ?? '08:00',
    note: json['note'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
  );
}
