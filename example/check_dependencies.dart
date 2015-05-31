library bwu_pub_client.example.check_dependencies;

import 'package:http/http.dart' as http;
import 'dart:async' show Future, Stream;
import 'package:bwu_pub_client/bwu_pub_client.dart';
import 'package:logging/logging.dart' show Logger, Level;
import 'package:quiver_log/log.dart' show BASIC_LOG_FORMATTER, PrintAppender;
import 'package:stack_trace/stack_trace.dart' show Chain;

final packageVersions = {};
const startPackageName = 'bwu_datagrid';

final _log = new Logger('check_dependencies');

//void main(List<String> args) {
//  Logger.root.level = Level.FINEST;
//  var appender = new PrintAppender(BASIC_LOG_FORMATTER);
//  appender.attachLogger(Logger.root);
//
//  Chain.capture(() => _main(), onError: (error, stack) {
//    _log.shout(error);
//    _log.shout(stack.terse);
//  });
//}


main() async {
  final pubClient =new PubClient(new http.Client());
  final PubPackage startPackage = await pubClient.fetchPackageByName(startPackageName);
  packageVersions[startPackage.name] = startPackage.latest.version;
  await for (final p in startPackage.latest.pubspec.dependencies) {
    pubClient.fetchPackage(p);
  }
  print('p');
}

