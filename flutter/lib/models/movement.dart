class Movement {
  final String id;
  final String name;
  final int? reps;
  final int? durationSeconds;
  final String? unit;
  final double? weight;
  final String? weightUnit;
  final String? notes;

  Movement({
    required this.id,
    required this.name,
    this.reps,
    this.durationSeconds,
    this.unit,
    this.weight,
    this.weightUnit,
    this.notes,
  });

  factory Movement.fromJson(Map<String, dynamic> json) {
    return Movement(
      id: json['id'] as String? ?? '',
      name: json['name'] as String,
      reps: json['reps'] as int?,
      durationSeconds: json['duration_seconds'] as int?,
      unit: json['unit'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      weightUnit: json['weight_unit'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'reps': reps,
      'duration_seconds': durationSeconds,
      'unit': unit,
      'weight': weight,
      'weight_unit': weightUnit,
      'notes': notes,
    };
  }

  Movement copyWith({
    String? id,
    String? name,
    int? reps,
    int? durationSeconds,
    String? unit,
    double? weight,
    String? weightUnit,
    String? notes,
  }) {
    return Movement(
      id: id ?? this.id,
      name: name ?? this.name,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      unit: unit ?? this.unit,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      notes: notes ?? this.notes,
    );
  }

  String get displayText {
    final parts = <String>[];

    if (reps != null) {
      parts.add('$reps');
    }

    if (unit != null && unit != 'reps') {
      parts.add(unit!);
    }

    parts.add(name);

    if (weight != null) {
      parts.add('@ ${weight}${weightUnit ?? 'lbs'}');
    }

    return parts.join(' ');
  }

  String get shortDisplayText {
    if (reps != null) {
      return '$reps $name';
    }
    if (durationSeconds != null) {
      return '${durationSeconds}s $name';
    }
    return name;
  }
}
