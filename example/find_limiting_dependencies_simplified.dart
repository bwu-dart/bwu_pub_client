library bwu_pub_client.example.check_dependencies;

import 'dart:async' show Future, Stream;
import 'dart:collection';
import 'package:bwu_pub_client/bwu_pub_client.dart';
import 'package:http/http.dart' as http;

const startPackageName = 'appengine';

/// Collect all dependencies (direct and transitive).
Map<String, PubPackage> allDependencies = <String, PubPackage>{};

main() async {
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

/// Collect all direct and transitive dependencies and let
/// `outdatedDependencies()` find which have constraints that limit updating to
/// the most recent version.
Future<Map<String, Set<String>>> findLimitingDependencies(
    PubClient pubClient, String packageName) async {
  /// Queue of packages to fetch info from pub.dartlang.org
  final queue = new Queue<String>();
  queue.add(packageName);

  while (queue.isNotEmpty) {
    /// Fetch data from pub.dartlang.org
    final PubPackage package = await pubClient.fetchPackage(queue.removeLast());
    allDependencies[package.name] = package;

    /// Queue transtitive dependencies to process
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

/// Find the dependencies where a dependency constraint prevents updating to
/// the most recent version.
Map<String, Set<String>> outdatedDependencies() {
  final result = <String, Set<String>>{};
  final depending = findDependingPackages();
  depending.forEach((k, v) {
    v.forEach((d) {
      final dep = allDependencies[d].latest.pubspec.dependencies[k];
      /// Check if latest version is supported (only hosted packages are
      /// supported currently because others would require to fetch version
      /// information from a path or Git reference.
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

/// Builds a map from each dependency to the packages which depend on this
/// dependency (from the set of transitive dependencies of the
/// `startPackageName`).
Map<String, List<String>> findDependingPackages() {
  final result = {};
  allDependencies.forEach((k, v) {
    final dependencies = findDependingOn(k);
    result[k] = dependencies;
  });
  return result;
}

/// Get the packages which depend on package [name].
List<String> findDependingOn(String name) {
  return allDependencies.keys
      .where((k) =>
          allDependencies[k].latest.pubspec.dependencies.containsKey(name))
      .toList();
}
