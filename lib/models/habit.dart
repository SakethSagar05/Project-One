import '../logic/local_date.dart';

/// Parent entity. One row in the Habit table.
class Habit {
  const Habit({
    this.id,
    required this.title,
    required this.category,
    required this.weeklyTarget,
    required this.startedLocalDate,
    this.motivation,
  });

  factory Habit.fromMap(Map<String, Object?> map) => Habit(
        id: map['id'] as int?,
        title: map['title'] as String,
        category: map['category'] as String,
        weeklyTarget: map['weeklyTarget'] as int,
        startedLocalDate: parseDateKey(map['startedLocalDate'] as String),
        motivation: map['motivation'] as String?,
      );

  /// Null until the row has been inserted.
  final int? id;
  final String title;
  final String category;

  /// Days per week, 1 to 7.
  final int weeklyTarget;

  /// Plain local date the habit started (no time part).
  final DateTime startedLocalDate;

  /// Optional "why I'm doing this" note.
  final String? motivation;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'category': category,
        'weeklyTarget': weeklyTarget,
        'startedLocalDate': toDateKey(startedLocalDate),
        'motivation': motivation,
      };

  Habit copyWith({
    int? id,
    String? title,
    String? category,
    int? weeklyTarget,
    DateTime? startedLocalDate,
    String? motivation,
  }) =>
      Habit(
        id: id ?? this.id,
        title: title ?? this.title,
        category: category ?? this.category,
        weeklyTarget: weeklyTarget ?? this.weeklyTarget,
        startedLocalDate: startedLocalDate ?? this.startedLocalDate,
        motivation: motivation ?? this.motivation,
      );
}
