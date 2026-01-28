import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TodoApp());
}

bool isSameDaySafe(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Habit tracker-productive',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.pink,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF1B6B), Color(0xFF910057)],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(
              radius: 200,
              backgroundColor: Colors.white.withOpacity(0.05),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Hero(
                        tag: 'logo',
                        child: Icon(
                          Icons.task_alt_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Habit tracker',
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'PRODUCTIVE EDITION',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Kelola hari Anda secara profesional dengan pengalaman yang elegan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 80),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                const TodoHomePage(),
                            transitionsBuilder:
                                (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                            transitionDuration: const Duration(milliseconds: 800),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Text(
                          'MULAI SEKARANG',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF1B6B),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum TodoPriority { rendah, sedang, tinggi }

class Todo {
  String id;
  String title;
  String description;
  bool done;
  TodoPriority priority;
  String category;
  DateTime? dueDate;
  DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    this.description = '',
    this.done = false,
    this.priority = TodoPriority.rendah,
    this.category = 'Umum',
    this.dueDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'done': done ? 1 : 0,
        'priority': priority.index,
        'category': category,
        'dueDate': dueDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Todo.fromMap(Map<String, dynamic> map) => Todo(
        id: map['id'],
        title: map['title'],
        description: map['description'],
        done: map['done'] == 1,
        priority: TodoPriority.values[map['priority']],
        category: map['category'],
        dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
        createdAt: DateTime.parse(map['createdAt']),
      );

  Map<String, dynamic> toJson() => toMap();

  factory Todo.fromJson(Map<String, dynamic> json) => Todo.fromMap(json);
}

enum FilterStatus { semua, pending, selesai }

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  List<Todo> todos = [];
  FilterStatus filter = FilterStatus.semua;
  String searchQuery = "";
  String sortBy = "Tanggal Dibuat";
  final controller = TextEditingController();
  final uuid = const Uuid();
  final dbHelper = DatabaseHelper();
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = null;
    initNotification();
    _refreshTodos();
  }

  Future<void> _refreshTodos() async {
    final data = await dbHelper.getTodos();
    if (mounted) {
      setState(() {
        todos = data;
        _isLoading = false;
      });
    }
  }

  void _showClearCompletedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Bersihkan Daftar?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("Hapus semua tugas yang telah selesai?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          FilledButton(
            onPressed: () async {
              final doneTodos = todos.where((t) => t.done).toList();
              for (var t in doneTodos) {
                await dbHelper.deleteTodo(t.id);
              }
              _refreshTodos();
              if (mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  Future<void> initNotification() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await notifications.initialize(initSettings);
  }

  Future<void> showReminder(Todo todo) async {
    if (kIsWeb || todo.dueDate == null) return;

    final androidDetails = AndroidNotificationDetails(
      'todo_channel',
      'Pengingat Tugas',
      importance: Importance.max,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    await notifications.show(
      todo.hashCode,
      '⏰ Batas Waktu: ${todo.title}',
      'Kategori: ${todo.category}',
      notificationDetails,
    );
  }

  Future<void> loadTodos() async {
    // No longer used, handled by _refreshTodos
  }

  Future<void> saveTodos() async {
    // No longer used, handled via direct DB calls
  }

  void _showAddEditDialog([Todo? existingTodo]) {
    final titleController =
        TextEditingController(text: existingTodo?.title ?? "");
    final descController =
        TextEditingController(text: existingTodo?.description ?? "");
    final categoryController =
        TextEditingController(text: existingTodo?.category ?? "Umum");
    var selectedPriority = existingTodo?.priority ?? TodoPriority.rendah;
    var selectedDate = existingTodo?.dueDate;
    TimeOfDay? selectedTime = existingTodo?.dueDate != null
        ? TimeOfDay.fromDateTime(existingTodo!.dueDate!)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  existingTodo == null ? 'Tambah Tugas Baru' : 'Edit Tugas',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Tugas',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan / Catatan',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Prioritas Tugas:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<TodoPriority>(
                    segments: const [
                      ButtonSegment(
                          value: TodoPriority.rendah,
                          label: Text("Rendah"),
                          icon: Icon(Icons.keyboard_arrow_down, size: 16)),
                      ButtonSegment(
                          value: TodoPriority.sedang,
                          label: Text("Sedang"),
                          icon: Icon(Icons.remove, size: 16)),
                      ButtonSegment(
                          value: TodoPriority.tinggi,
                          label: Text("Tinggi"),
                          icon: Icon(Icons.keyboard_arrow_up, size: 16)),
                    ],
                    selected: {selectedPriority},
                    onSelectionChanged: (val) {
                      setDialogState(() => selectedPriority = val.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setDialogState(() {
                          selectedDate = pickedDate;
                          selectedTime = pickedTime;
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.pink.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.pink.withOpacity(0.02),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_rounded, size: 20, color: Colors.pink),
                        const SizedBox(width: 12),
                        Text(
                          selectedDate == null || selectedTime == null
                              ? "Atur Waktu & Pengingat"
                              : "${DateFormat('dd MMM').format(selectedDate!)} pukul ${selectedTime!.format(context)}",
                          style: TextStyle(
                            color: selectedDate == null ? Colors.grey[600] : Colors.black87,
                            fontWeight: selectedDate == null ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (selectedDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setDialogState(() {
                              selectedDate = null;
                              selectedTime = null;
                            }),
                          )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed: () async {
                      if (titleController.text.isNotEmpty) {
                        DateTime? finalDueDate;
                        if (selectedDate != null && selectedTime != null) {
                          finalDueDate = DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day,
                            selectedTime!.hour,
                            selectedTime!.minute,
                          );
                        }

                        if (existingTodo == null) {
                          final newTodo = Todo(
                            id: uuid.v4(),
                            title: titleController.text,
                            description: descController.text,
                            priority: selectedPriority,
                            category: categoryController.text,
                            dueDate: finalDueDate,
                          );
                          await dbHelper.insertTodo(newTodo);
                          if (finalDueDate != null) showReminder(newTodo);
                        } else {
                          existingTodo.title = titleController.text;
                          existingTodo.description = descController.text;
                          existingTodo.priority = selectedPriority;
                          existingTodo.category = categoryController.text;
                          existingTodo.dueDate = finalDueDate;
                          await dbHelper.updateTodo(existingTodo);
                        }
                        _refreshTodos();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                        existingTodo == null ? 'Simpan Tugas' : 'Perbarui Tugas',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Todo> get processedTodos {
    var list = todos.where((t) {
      final matchesFilter = filter == FilterStatus.semua ||
          (filter == FilterStatus.pending && !t.done) ||
          (filter == FilterStatus.selesai && t.done);
      final matchesSearch =
          t.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              t.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
              t.description.toLowerCase().contains(searchQuery.toLowerCase());
      
      final matchesCalendar = _selectedDay == null || 
          (t.dueDate != null && isSameDaySafe(t.dueDate, _selectedDay));

      return matchesFilter && matchesSearch && matchesCalendar;
    }).toList();

    // Sort by status first: Active at top, Completed at bottom
    list.sort((a, b) {
      if (a.done != b.done) {
        return a.done ? 1 : -1;
      }
      
      // If both have same status, sort by chosen criteria
      if (sortBy == "Prioritas") {
        return b.priority.index.compareTo(a.priority.index);
      } else if (sortBy == "Jatuh Tempo") {
        if (a.dueDate == null && b.dueDate == null) return b.createdAt.compareTo(a.createdAt);
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      } else {
        // Default: Sort by proximity of deadline for active tasks, then by creation date
        if (!a.done) {
          if (a.dueDate != null && b.dueDate != null) {
            return a.dueDate!.compareTo(b.dueDate!);
          }
          if (a.dueDate != null) return -1;
          if (b.dueDate != null) return 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      }
    });
    return list;
  }

  Color _getPriorityColor(TodoPriority p) {
    switch (p) {
      case TodoPriority.tinggi:
        return Colors.redAccent;
      case TodoPriority.sedang:
        return Colors.orangeAccent;
      case TodoPriority.rendah:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          backgroundColor: Colors.pinkAccent,
          foregroundColor: Colors.white,
          label: const Text("Tugas Baru",
              style: TextStyle(fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add),
          elevation: 0,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 56, bottom: 20),
                    title: Text(
                      'Habit tracker',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    centerTitle: false,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [Color(0xFFFF1B6B), Color(0xFF910057)],
                            ),
                          ),
                        ),
                        Positioned(
                          right: -50,
                          top: -50,
                          child: CircleAvatar(
                            radius: 100,
                            backgroundColor: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        Positioned(
                          left: 56,
                          top: 60, // Moved even higher as requested
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, dd MMMM').format(DateTime.now()),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${todos.where((t) => !t.done).length} Tugas Tertunda",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Cari tugas...',
                                    prefixIcon: const Icon(Icons.search,
                                        color: Colors.pink),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                                  ),
                                  onChanged: (val) =>
                                      setState(() => searchQuery = val),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Categories filter moved here for better space utilization
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('Semua', FilterStatus.semua),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Pending', FilterStatus.pending),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Selesai', FilterStatus.selesai),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 320,
                        child: _buildUrgentAlertPanel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DropdownButton<String>(
                        value: sortBy,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.sort, size: 20),
                        style: GoogleFonts.poppins(
                          color: Colors.pink,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        items: ["Tanggal Dibuat", "Prioritas", "Jatuh Tempo"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setState(() => sortBy = val!),
                      ),
                      if (todos.any((t) => t.done))
                        TextButton.icon(
                          onPressed: _showClearCompletedDialog,
                          icon: const Icon(Icons.cleaning_services_rounded, size: 18, color: Colors.orangeAccent),
                          label: Text(
                            "Bersihkan Selesai",
                            style: GoogleFonts.poppins(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          processedTodos.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "Agenda Anda sudah bersih!",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final todo = processedTodos[index];
                        return _buildTodoCard(todo, index);
                      },
                      childCount: processedTodos.length,
                    ),
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, FilterStatus status) {
    bool isSelected = filter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => filter = status),
      selectedColor: Colors.pink.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.pink : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.pink : Colors.grey[200]!,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildTodoCard(Todo todo, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(todo.id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.9),
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 25),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Hapus",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(width: 8),
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Konfirmasi Hapus", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                content: const Text("Apakah Anda yakin ingin menghapus tugas ini?"),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Batal")),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text("Hapus"),
                  ),
                ],
              );
            },
          );
        },
        onDismissed: (_) async {
          await dbHelper.deleteTodo(todo.id);
          _refreshTodos();
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAddEditDialog(todo),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: todo.done,
                            activeColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            onChanged: (val) async {
                              todo.done = val!;
                              await dbHelper.updateTodo(todo);
                              _refreshTodos();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            todo.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: todo.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: todo.done ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ),
                        _buildPriorityBadge(todo.priority),
                      ],
                    ),
                    if (todo.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 45, top: 2),
                        child: Text(
                          todo.description,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(left: 45, top: 12),
                      child: Divider(height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 45, top: 12),
                      child: Row(
                        children: [
                          _buildSmallIconText(Icons.category, todo.category),
                          const Spacer(),
                          if (todo.dueDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (todo.dueDate!.isBefore(DateTime.now()) && !todo.done)
                                    ? Colors.redAccent.withOpacity(0.1)
                                    : Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _buildSmallIconText(
                                Icons.notifications_active_rounded,
                                DateFormat('dd MMM, HH:mm').format(todo.dueDate!),
                                isError: todo.dueDate!.isBefore(DateTime.now()) &&
                                    !todo.done,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(TodoPriority p) {
    Color color = _getPriorityColor(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        p.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildUrgentAlertPanel() {
    final urgentTodos = todos.where((t) =>
        !t.done &&
        t.dueDate != null &&
        t.dueDate!.difference(DateTime.now()).inDays <= 1).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.pink.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   const Icon(Icons.calendar_month_rounded, color: Colors.pink, size: 20),
                   const SizedBox(width: 8),
                   Text(
                    "Kalender & Pengingat",
                    style: GoogleFonts.poppins(
                      color: Colors.pink,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (_selectedDay != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.grey),
                  onPressed: () => setState(() => _selectedDay = null),
                  tooltip: 'Reset Filter Tanggal',
                ),
            ],
          ),
          TableCalendar(
            key: const ValueKey('calendar_web_v1'),
            firstDay: DateTime(2023, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            selectedDayPredicate: (day) => isSameDaySafe(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            rowHeight: 40,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            eventLoader: (day) {
              return todos.where((t) => t.dueDate != null && isSameDaySafe(t.dueDate, day)).toList();
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
          if (urgentTodos.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1, thickness: 0.5),
            ),
            const Row(
              children: [
                Icon(Icons.bolt, color: Colors.redAccent, size: 16),
                SizedBox(width: 4),
                Text(
                  "Tugas Mendesak",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...urgentTodos.take(2).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "• ${t.title}",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallIconText(IconData icon, String text, {bool isError = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isError ? Colors.redAccent : Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isError ? Colors.redAccent : Colors.grey[700],
            fontWeight: isError ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
