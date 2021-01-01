import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'package:taskc/taskc.dart' as taskc show synchronize;
import 'package:taskc/taskc.dart' hide synchronize;

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
    });
  });
}

class Storage {
  Storage(this._home);

  final Directory _home;
  var _box;
  var _connection;
  var _credentials;

  Future<void> initialize() async {
    var _address = 'localhost';
    var _port = 53589;
    var _certificate = 'fixture/.task/first_last.cert.pem';
    var _key = 'fixture/.task/first_last.key.pem';
    var _ca = 'fixture/.task/ca.cert.pem';

    await Directory('${_home.path}/.task/').delete(recursive: true);
    await Directory('${_home.path}/.task/').create();

    _box = await Hive.openBox(
      'tasks',
      bytes: Uint8List(0),
    );
    _connection = Connection(
      address: _address,
      port: _port,
      context: SecurityContext()
        ..useCertificateChain(_certificate)
        ..usePrivateKey(_key)
        ..setTrustedCertificates(_ca),
      onBadCertificate: Platform.isMacOS ? (_) => true : null,
    );
    _credentials = Credentials.fromString(
      parseTaskrc(
        File('fixture/.taskrc').readAsStringSync(),
      )['taskd.credentials'],
    );
  }

  Future<bool> synchronize() async {
    var response = await taskc.synchronize(
      connection: _connection,
      credentials: _credentials,
      payload: File('${_home.path}/.task/backlog.data').readAsStringSync(),
    );
    var header = response.header;
    var payload = response.payload;
    switch (header['code']) {
      case '200':
        var userKey = payload.userKey;
        var tasks = payload.tasks.map(
          (task) => Task.fromJson(json.decode(task)),
        );
        tasks.forEach((task) {
          _box.put(task.uuid, task);
        });
        File('${_home.path}/.task/backlog.data').writeAsStringSync(
          '$userKey\n',
        );
        print(header['status']);
        return true;
        break;
      case '201':
        print(header['status']);
        return false;
        break;
      default:
        throw Exception(header);
    }
  }

  Future<void> addTask(Task task) async {
    await _box.put(task.uuid, task);
    await File('${_home.path}/.task/backlog.data').writeAsString(
      '${json.encode(task.toJson())}\n',
      mode: FileMode.append,
    );
  }

  Future<Map> getTasks() => Future.value(_box.toMap());
}

// class TaskAdapter extends TypeAdapter<Task> {
//   var typeId = 0;

//   Task read(BinaryReader reader) {}

//   void write(BinaryWriter writer, Task task) {}
// }
