import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'main.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'todo_pro.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE todos(
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        done INTEGER,
        priority INTEGER,
        category TEXT,
        dueDate TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<int> insertTodo(Todo todo) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList('todos_fallback') ?? [];
      list.add(jsonEncode(todo.toMap()));
      await prefs.setStringList('todos_fallback', list);
      return 1;
    }
    Database db = await database;
    return await db.insert('todos', todo.toMap());
  }

  Future<List<Todo>> getTodos() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList('todos_fallback') ?? [];
      return list.map((e) => Todo.fromMap(jsonDecode(e))).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('todos', orderBy: 'createdAt DESC');
    return List.generate(maps.length, (i) {
      return Todo.fromMap(maps[i]);
    });
  }

  Future<int> updateTodo(Todo todo) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList('todos_fallback') ?? [];
      int index = list.indexWhere((e) => Todo.fromMap(jsonDecode(e)).id == todo.id);
      if (index != -1) {
        list[index] = jsonEncode(todo.toMap());
        await prefs.setStringList('todos_fallback', list);
      }
      return 1;
    }
    Database db = await database;
    return await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<int> deleteTodo(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList('todos_fallback') ?? [];
      list.removeWhere((e) => Todo.fromMap(jsonDecode(e)).id == id);
      await prefs.setStringList('todos_fallback', list);
      return 1;
    }
    Database db = await database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
