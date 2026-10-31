import '../logic/local_date.dart';

/// Child entity. One row in the CheckIn table, linked to a Habit by habitId.
/// UNIQUE(habitId, localDate): at most one check-in per habit per day.
class CheckIn {
  const CheckIn({
    this.id,
    required this.habitId,
    required this.localDate,
    this.note,
  });

  factory CheckIn.fromMap(Map<String, Object?> map) => CheckIn(
        id: map['id'] as int?,
        habitId: map['habitId'] as int,
        localDate: parseDateKey(map['localDate'] as String),
        note: map['note'] as String?,
      );

  final int? id;
  final int habitId;

  /// Plain local date of the check-in (no time part).
  final DateTime localDate;
  final String? note;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'habitId': habitId,
        'localDate': toDateKey(localDate),
        'note': note,
      };

  CheckIn copyWith({DateTime? localDate, String? note}) => CheckIn(
        id: id,
        habitId: habitId,
        localDate: localDate ?? this.localDate,
        note: note ?? this.note,
      );
}
