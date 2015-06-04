library bwu_pub_client.src.limiting_dependencies;

import 'dart:async' show Future, Stream;
import 'dart:collection';
import 'package:bwu_pub_client/bwu_pub_client.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart' show Logger, Level;

final _log = new Logger('check_dependencies');

Map<String, PubPackage> allDependencies = <String, PubPackage>{};

Future<Null> printLimitingDependencies(String package) async {
  final pubClient = new PubClient(new http.Client());
  Map<String, Set<String>> outdated =
      await findLimitingDependencies(pubClient, package);
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
  return _outdatedDependencies();
}

Map<String, Set<String>> _outdatedDependencies() {
  final result = <String, Set<String>>{};
  final depending = _findDependingPackages();
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

Map<String, List<String>> _findDependingPackages() {
  final result = {};
  allDependencies.forEach((k, v) {
    final dependencies = _findDependingOn(k);
    result[k] = dependencies;
  });
  return result;
}

List<String> _findDependingOn(String name) {
  return allDependencies.keys
      .where((k) =>
          allDependencies[k].latest.pubspec.dependencies.containsKey(name))
      .toList();
}
