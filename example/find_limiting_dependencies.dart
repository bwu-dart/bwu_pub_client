library bwu_pub_client.example.check_dependencies;

import 'dart:async' show Future, Stream;
import 'dart:collection';
import 'package:bwu_pub_client/bwu_pub_client.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart' show Logger, Level;
import 'package:quiver_log/log.dart' show BASIC_LOG_FORMATTER, PrintAppender;
import 'package:stack_trace/stack_trace.dart' show Chain;

final _log = new Logger('check_dependencies');

const startPackageName = 'appengine';

Map<String, PubPackage> allDependencies = <String, PubPackage>{};

void main(List<String> args) {
  Logger.root.level = Level.FINEST;
  var appender = new PrintAppender(BASIC_LOG_FORMATTER);
  appender.attachLogger(Logger.root);

  Chain.capture(() => _main(), onError: (error, stack) {
    _log.shout(error);
    _log.shout(stack.terse);
  });
}

_main() async {
  final pubClient = new PubClient(new http.Client());
  Map<String, Set<String>> outdated =
      await findLimitingDependencies(pubClient, startPackageName);
  outdated.forEach((k, v) {
    print(
        '"${k}" (latest: ${allDependencies[k].latest.version}) doesn\'t support the latest version of:');
    v.forEach((e) {
      print(
          '    "${e}" (${allDependencies[e].latest.version}) - constraint: ${allDependencies[k].latest.pubspec.dependencies[e].versionConstraint}');
    });
  });
}

Future<Map<String, Set<String>>> findLimitingDependencies(
    PubClient pubClient, String packageName) async {
  final queue = new Queue<String>();
  queue.add(packageName);
  while (queue.isNotEmpty) {
    final PubPackage package = await pubClient.fetchPackage(queue.removeLast());
    allDependencies[package.name] = package;
    final dependencies = package.latest.pubspec.dependencies;
    if (dependencies != null) {
      for (final p in dependencies.keys) {
        if (!allDependencies.containsKey(p) && !queue.contains(p)) {
          queue.add(p);
        }
      }
    }
  }
  return outdatedDependencies();
}

Map<String, Set<String>> outdatedDependencies() {
  final result = <String, Set<String>>{};
  final depending = findDependingPackages();
  depending.forEach((k, v) {
//    print('${k}, ${v}');
    v.forEach((d) {
      final dep = allDependencies[d].latest.pubspec.dependencies[k];
      if (dep.kind == DependencyKind.hosted &&
          !dep.versionConstraint.allows(allDependencies[k].latest.version)) {
        if (result[d] == null) {
          result[d] = new Set<String>()..add(k);
        } else {
          result[d].add(k);
        }
      }
    });
  });
  return result;
}

Map<String, List<String>> findDependingPackages() {
  final result = {};
  allDependencies.forEach((k, v) {
    final dependencies = findDependingOn(k);
    result[k] = dependencies;
  });
  return result;
}

List<String> findDependingOn(String name) {
  return allDependencies.keys
      .where((k) =>
          allDependencies[k].latest.pubspec.dependencies.containsKey(name))
      .toList();
}
