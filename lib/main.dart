import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nested Task Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FirebaseAuth.instance.currentUser == null
          ? LoginScreen()
          : TaskListScreen(),
    );
  }
}

// Task and SubTask Models
class Task {
  String id;
  String name;
  List<SubTask> additionalTasks;

  Task({
    required this.id,
    required this.name,
    required this.additionalTasks,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'additionalTasks': additionalTasks.map((task) => task.toMap()).toList(),
    };
  }

  static Task fromMap(Map<String, dynamic> map, String id) {
    return Task(
      id: id,
      name: map['name'],
      additionalTasks: (map['additionalTasks'] as List)
          .map((task) => SubTask.fromMap(task))
          .toList(),
    );
  }

  bool areAllSubTasksCompleted() {
    return additionalTasks.isNotEmpty &&
        additionalTasks.every((subTask) => subTask.isCompleted);
  }
}

class SubTask {
  String name;
  bool isCompleted;

  SubTask({
    required this.name,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isCompleted': isCompleted,
    };
  }

  static SubTask fromMap(Map<String, dynamic> map) {
    return SubTask(
      name: map['name'],
      isCompleted: map['isCompleted'],
    );
  }
}

// Login Screen
class LoginScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _signIn(BuildContext context) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => TaskListScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _signIn(context),
              child: Text('Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                );
              },
              child: Text('Don\'t have an account? Register'),
            ),
          ],
        ),
      ),
    );
  }
}

// Register Screen
class RegisterScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _register(BuildContext context) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => TaskListScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _register(context),
              child: Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}

// Task List Screen (Main Screen)
class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _subTaskController = TextEditingController();

  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  void _fetchTasks() {
    final uid = _auth.currentUser?.uid;
    _firestore
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _tasks = snapshot.docs
            .map((doc) => Task.fromMap(doc.data(), doc.id))
            .toList();
      });
    });
  }

  Future<void> _addTask(String taskName) async {
    final uid = _auth.currentUser?.uid;
    final task = Task(id: '', name: taskName, additionalTasks: []);
    final docRef = await _firestore.collection('tasks').add({
      'name': taskName,
      'userId': uid,
      'additionalTasks':
          task.additionalTasks.map((task) => task.toMap()).toList(),
    });
    task.id = docRef.id; // Update task ID after it's added to Firestore
  }

  Future<void> _addSubTask(Task task, String subTaskName) async {
    final subTask = SubTask(name: subTaskName, isCompleted: false);
    task.additionalTasks.add(subTask);

    await _firestore.collection('tasks').doc(task.id).update({
      'additionalTasks':
          task.additionalTasks.map((subTask) => subTask.toMap()).toList(),
    });
  }

  Future<void> _toggleSubTaskCompletion(Task task, SubTask subTask) async {
    subTask.isCompleted = !subTask.isCompleted;

    await _firestore.collection('tasks').doc(task.id).update({
      'additionalTasks':
          task.additionalTasks.map((task) => task.toMap()).toList(),
    });
  }

  Future<void> _deleteTask(Task task) async {
    await _firestore.collection('tasks').doc(task.id).delete();
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task List'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(labelText: 'Enter task name'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    if (_taskController.text.isNotEmpty) {
                      _addTask(_taskController.text);
                      _taskController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, taskIndex) {
                final task = _tasks[taskIndex];
                return Card(
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(task.name),
                        Row(
                          children: [
                            Checkbox(
                              value: task.areAllSubTasksCompleted(),
                              onChanged: null,
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => _deleteTask(task),
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text('Additional tasks'),
                            ...task.additionalTasks.map((subTask) {
                              return ListTile(
                                leading: Checkbox(
                                  value: subTask.isCompleted,
                                  onChanged: (value) =>
                                      _toggleSubTaskCompletion(task, subTask),
                                ),
                                title: Text(subTask.name),
                              );
                            }).toList(),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _subTaskController,
                                      decoration: InputDecoration(
                                        labelText: 'Add additional task',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add),
                                    onPressed: () {
                                      if (_subTaskController.text.isNotEmpty) {
                                        _addSubTask(
                                            task, _subTaskController.text);
                                        _subTaskController.clear();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
