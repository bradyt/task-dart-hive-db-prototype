import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import 'package:taskc/taskc.dart' as taskc show synchronize;
import 'package:taskc/taskc.dart' hide synchronize;

class Storage {
  Storage(this._home);

  final Directory _home;
  var _box;
  var _connection;
  var _credentials;

  Future<void> initializeConfigStorage() async {
    await Directory('${_home.path}/.task/').delete(recursive: true);
    await Directory('${_home.path}/.task/').create();
  }

  Future<void> addTaskrc(File taskrc) => taskrc.copy('${_home.path}/.taskrc');

  Future<void> addPemFiles(Map map) => Future.forEach(map.entries,
      (entry) => entry.value.copy('${_home.path}/.task/${entry.key}.pem'));

  Future<void> initializeDbAndConnection() async {
    var taskrc =
        parseTaskrc(await File('${_home.path}/.taskrc').readAsString());

    var server = taskrc['taskd.server'].split(':');
    var credentials = Credentials.fromString(taskrc['taskd.credentials']);

    var address = server.first;
    var port = int.parse(server.last);

    var certificate = '${_home.path}/.task/certificate.pem';
    var key = '${_home.path}/.task/key.pem';
    var ca = '${_home.path}/.task/ca.pem';

    _box = await Hive.openBox(
      'tasks',
      path: '${_home.path}/tasks.hivedb',
    );

    _connection = Connection(
      address: address,
      port: port,
      context: SecurityContext()
        ..useCertificateChain(certificate)
        ..usePrivateKey(key)
        ..setTrustedCertificates(ca),
      onBadCertificate: Platform.isMacOS ? (_) => true : null,
    );
    _credentials = credentials;
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
          _box.put(task.uuid, task.toJson());
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
    await _box.put(task.uuid, task.toJson());
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
