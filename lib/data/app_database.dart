import 'package:sqflite/sqflite.dart';

/// Opens the local SQLite database and creates the two related tables.
class AppDatabase {
  AppDatabase._();

  static const String fileName = 'habit_mastery_league.db';
  static const int schemaVersion = 1;

  /// [factory] and [path] let tests use an in-memory FFI database.
  static Future<Database> open({
    DatabaseFactory? factory,
    String? path,
    bool singleInstance = true,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? '${await dbFactory.getDatabasesPath()}/$fileName';
    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: singleInstance,
        // Foreign keys are off by default in SQLite; ON DELETE CASCADE needs them.
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
      ),
    );
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Habit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL CHECK (length(trim(title)) > 0),
        category TEXT NOT NULL,
        weeklyTarget INTEGER NOT NULL CHECK (weeklyTarget BETWEEN 1 AND 7),
        startedLocalDate TEXT NOT NULL,
        motivation TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE CheckIn (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL REFERENCES Habit(id) ON DELETE CASCADE,
        localDate TEXT NOT NULL,
        note TEXT,
        UNIQUE (habitId, localDate)
      )
    ''');
  }
}
