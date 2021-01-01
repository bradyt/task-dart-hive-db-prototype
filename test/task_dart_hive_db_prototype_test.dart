import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'package:taskc/taskc.dart';

import 'package:task_dart_hive_db_prototype/task_dart_hive_db_prototype.dart';

void main() {
  group('Test hive usage', () {
    var box;

    setUp(() async {
      box = await Hive.openBox(
        'tasks',
        bytes: Uint8List(0),
      );
    });

    test('Add a task to hive and read it', () {
      var task = Task(
        status: 'pending',
        uuid: Uuid().v1(),
        entry: DateTime.now().toUtc(),
        description: 'hello world',
      );
      box.put(task.uuid, task);
      var stored_task = box.get(task.uuid);
      print(stored_task.toJson());
    });
  });
}

// class TaskAdapter extends TypeAdapter<Task> {
//   var typeId = 0;

//   Task read(BinaryReader reader) {}

//   void write(BinaryWriter writer, Task task) {}
// }
