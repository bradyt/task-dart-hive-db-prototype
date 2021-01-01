import 'dart:io';

import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'package:taskc/taskc.dart' show Task;

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

      await storage.initializeConfigStorage();

      await storage.addTaskrc(File('fixture/.taskrc'));

      await storage.addPemFiles({
        'certificate': File('fixture/.task/first_last.cert.pem'),
        'key': File('fixture/.task/first_last.key.pem'),
        'ca': File('fixture/.task/ca.cert.pem'),
      });

      await storage.initializeDbAndConnection();
    });

    test('Add a task to hive and read it', () async {
      var task;
      task = taskFromDescription('hello world');
      await storage.addTask(task);
      task = taskFromDescription('foo bar');
      await storage.addTask(task);
      // (await storage.getTasks()).entries.forEach((entry) {
      //   print(entry.key);
      //   print(entry.value.toJson());
      // });
      await storage.synchronize();
      task = taskFromDescription('baz');
      await storage.addTask(task);
      await storage.synchronize();
      await storage.synchronize();
      var tasks = await storage.getTasks();
      expect(tasks.length > 0, true);
    });
  });
}
