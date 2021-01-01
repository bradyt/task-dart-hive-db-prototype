import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'package:taskc/taskc.dart';

import 'package:task_dart_hive_db_prototype/task_dart_hive_db_prototype.dart';

void main() {
  group('Test hive usage', () {
    var storage;

    Task taskFromDescription(String description) => Task(
          status: 'pending',
          uuid: Uuid().v1(),
          entry: DateTime.now().toUtc(),
          description: description,
        );

    setUp(() async {
      storage = Storage(Directory.systemTemp);
      await storage.initialize();
    });

    test('Add a task to hive and read it', () async {
      var task;
      task = taskFromDescription('hello world');
      storage.addTask(task);
      task = taskFromDescription('foo bar');
      storage.addTask(task);
      (await storage.getTasks()).entries.forEach((entry) {
        print(entry.key);
        print(entry.value.toJson());
      });
    });
  });
}

class Storage {
  Storage(this._home);

  final Directory _home;
  var _box;

  Future<void> initialize() async {
    _box = await Hive.openBox(
      'tasks',
      bytes: Uint8List(0),
    );
  }

  Future<void> addTask(Task task) => _box.put(task.uuid, task);

  Future<Map> getTasks() => Future.value(_box.toMap());
}

// class TaskAdapter extends TypeAdapter<Task> {
//   var typeId = 0;

//   Task read(BinaryReader reader) {}

//   void write(BinaryWriter writer, Task task) {}
// }
