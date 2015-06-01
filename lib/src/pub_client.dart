library bwu_pub_client.src.pub_client;

import 'dart:async' show Future, Stream;
import 'dart:convert' show JSON;
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart' as semver;
import 'package:quiver/core.dart' as qu;

final _log = new Logger('bwu_pub_client.src.pub_client');

final Map<String, Set<String>> unsupportedProperties = <String, Set<String>>{};

Uri packageUri(String name) =>
    Uri.parse('https://pub.dartlang.org/api/packages/${name}');

Uri pageUri(int page) =>
    Uri.parse('https://pub.dartlang.org/api/packages?page=${page}');

Uri versionUri(String name, String version) => Uri
    .parse('https://pub.dartlang.org/api/packages/${name}/versions/${version}');

class PubClient {
  http.Client httpClient;
  final Set<PubPackage> packageCache = new Set<PubPackage>();
  final Set<Version> versionCache = new Set<Version>();
  final Set<PubDartlangPage> pageCache = new Set<PubDartlangPage>();

  PubClient(this.httpClient);

  PubPackage packageFromCache(String name) =>
      packageCache.firstWhere((p) => p.name == name, orElse: () => null);

  PubDartlangPage pageFromCache(int page) =>
      pageCache.firstWhere((p) => p.page == page, orElse: () => null);

  Version versionFromCache(String packageName, Version version) => versionCache
      .firstWhere((v) => v.parent.name == packageName && v == version,
          orElse: () => null);

  Future<PubDartlangPage> fetchPage(int page) async {
    PubDartlangPage pubPage = pageFromCache(page);
    if (pubPage != null) {
      return pubPage;
    }
    _log.finest('fetch page: ${pageUri(page)}');
    final response = (await httpClient.get(pageUri(page))).body;
    _log.finest(response);
    pubPage = new PubDartlangPage.fromJson(page, JSON.decode(response));
    return pubPage;
  }

  Future<PubPackage> fetchPackage(String name) async {
    PubPackage package = packageFromCache(name);
    if (package != null) {
      return package;
    }
    final uri = packageUri(name);
    _log.finest('fetch page: ${uri}');
    final response = (await httpClient.get(uri)).body;
    _log.finest(response);
    return new PubPackage.fromJson(JSON.decode(response), isLoaded: true);
  }

  Future<Null> loadPackage(PubPackage p) async {
    if (p.isLoaded) {
      return;
    }
    ;
    final url = packageUri(p.name);
    _log.finest('fetch package: ${url}');
    final response = (await httpClient.get(url)).body;
    _log.finest(response);
    p.loadFromJson(JSON.decode(response), isLoaded: true);
  }

  Future<Null> loadVersion(PubPackage p, Version v) async {
    if (v.isLoaded) {
      return;
    }
    final url = versionUri(p.name, v.version.toString());
    _log.finest('fetch version: ${url}');
    final response = (await httpClient.get(url)).body;
    _log.finest(response);
    v..loadFromJson(JSON.decode(response), isLoaded: true);
  }
}

final RegExp authorRegExp = new RegExp(
    r'([^<]*)(?:<)([a-zA-Z0-9._%+-]+@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,4})(?:>.*)');

String getAuthorName(String author) {
  if (author == null) {
    return null;
  }
  _log.finest('getAuthorName: $author');
  final Match match = authorRegExp.firstMatch(author);
  if (match != null && match.groupCount >= 2) {
    return match.group(1).trim();
  }
  return null;
}

class Version {
  PubPackage parent;
  /// If `false` it is only initialized from data sent along with package
  /// information.
  /// If `true` it is initialized from an explicit version request.
  bool isLoaded = false;
  Pubspec pubspec;
//  Uri url;
  Uri archiveUrl;
  semver.Version version;
  Uri newDartdocUrl;
  Uri packageUrl;
  int downloads;
  DateTime createdAt;
  final Set<String> libraries = new Set<String>();
  String uploader;

  Version();

  factory Version.fromJson(PubPackage parent, Map json) {
    return new Version()
      ..parent = parent
      ..loadFromJson(json);
  }

  static const supportedProps = const [
    'pubspec',
    'url',
    'archive_url',
    'version',
    'new_dartdoc_url',
    'package_url',
    'downloads',
    'created',
    'libraries',
    'uploader'
  ];

  loadFromJson(Map json, {bool isLoaded: false}) {
    if (json == null) {
      return;
    }
    if (isLoaded) {
      this.isLoaded = true;
    }
    pubspec = new Pubspec.fromJson(this, json['pubspec']);

//    final url = json['url'];
//    if (url != null) this.url = Uri.parse(url);

    final archiveUrl = json['archive_url'];
    if (archiveUrl != null) this.archiveUrl = Uri.parse(archiveUrl);

    final version = json['version'];
    if (version != null) this.version = new semver.Version.parse(version);

    final newDartdocUrl = json['new_dartdoc_url'];
    if (newDartdocUrl != null) this.newDartdocUrl = Uri.parse(newDartdocUrl);

    final packageUrl = json['package_url'];
    if (packageUrl != null) this.packageUrl = Uri.parse(packageUrl);

    final downloads = json['downloads'];
    if (downloads != null) this.downloads = downloads;

    final created = json['created'];
    if (created != null) this.createdAt = DateTime.parse(created);

    final libraries = json['libraries'];
    if (libraries != null) this.libraries.addAll(libraries);

    final uploader = json['uploader'];
    if (uploader != null) this.uploader = uploader;

    // Report unsupported properties.
    final jsonProps = json.keys.toList();
    Set<String> properties = unsupportedProperties['Version'];
    if (properties == null) {
      properties = unsupportedProperties['Version'] = new Set<String>();
    }
    jsonProps.removeWhere((p) => supportedProps.contains(p));
    if (jsonProps.isNotEmpty) {
      properties.addAll(jsonProps);
      _log.info(
          'Version: ${packageUrl} doesn\'t save these properties: ${jsonProps}');
    }
  }

  @override
  int get hashCode => qu.hash2(parent, version);

  @override
  bool operator ==(other) {
    if (other is! Version) return false;
    return parent == (other as Version).parent &&
        version == (other as Version).version;
  }
}

class PubDartlangPage {
  Uri prevUrl;
  Uri nextUrl;
  final List<PubPackage> packages = <PubPackage>[];
  int pages;
  int page;

  static const supportedProps = const [
    'prev_url',
    'next_url',
    'pages',
    'packages'
  ];

  PubDartlangPage.fromJson(int page, Map json) {
    this.page = page;
    final prevUrl = json['prev_url'];
    if (prevUrl != null) this.prevUrl = Uri.parse(prevUrl);

    final nextUrl = json['next_url'];
    if (nextUrl != null) this.nextUrl = Uri.parse(nextUrl);

    pages = json['pages'];

    final packages = json['packages'];
    if (packages != null) {
      this.packages.addAll(packages.map((p) => new PubPackage.fromJson(p)));
    }

    // Report unsupported properties.
    final jsonProps = json.keys.toList();
    Set<String> properties = unsupportedProperties['PubDartlangPage'];
    if (properties == null) {
      properties = unsupportedProperties['PubDartlangPage'] = new Set<String>();
    }
    jsonProps.removeWhere((p) => supportedProps.contains(p));
    if (jsonProps.isNotEmpty) {
      properties.addAll(jsonProps);
      _log.info(
          'Page: (prev)${prevUrl} doesn\'t save these properties: ${jsonProps}');
    }
  }

  @override
  int get hashCode => page.hashCode;

  @override
  bool operator ==(other) {
    if (other is! PubDartlangPage) return false;
    return page == other.page;
  }
}

class PubPackage {
  String name;
  /// If `false` it is only initialized from data sent along with a page
  /// information.
  /// If `true` it is initialized from an explicit package request.
  bool isLoaded = false;
//  Uri url;
  Uri uploadersUrl;
  Uri newVersionUrl;
  Uri versionUrl;
  Version latest;
  DateTime createdAt;
  int downloads;

  final Set<String> uploaders = new Set<String>();
  final Set<Version> versions = new Set<Version>();

  static const supportedProps = const [
    'name',
    'url',
    'uploaders_url',
    'new_version_url',
    'version_url',
    'latest',
    'created',
    'downloads',
    'uploaders',
    'versions'
  ];

  factory PubPackage.fromJson(Map json, {bool isLoaded: false}) {
    return new PubPackage()..loadFromJson(json, isLoaded: isLoaded);
  }

  PubPackage();

  void loadFromJson(Map json, {bool isLoaded: false}) {
    if (json == null) return;
    if (isLoaded) this.isLoaded = isLoaded;

    name = json['name'];

//    final url = json['url'];
//    if (url != null) this.url = Uri.parse(url);

    final uploadersUrl = json['uploaders_url'];
    if (uploadersUrl != null) this.uploadersUrl = Uri.parse(uploadersUrl);

    final newVersionUrl = json['new_version_url'];
    if (newVersionUrl != null) this.newVersionUrl = Uri.parse(newVersionUrl);

    final versionUrl = json['version_url'];
    if (versionUrl != null) this.versionUrl = Uri.parse(versionUrl);

    latest = new Version.fromJson(this, json['latest']);

    final created = json['created'];
    if (created != null) this.createdAt = DateTime.parse(created);

    final downloads = json['downloads'];
    if (downloads != null) this.downloads = downloads;

    final uploaders = json['uploaders'];
    if (uploaders != null) this.uploaders.addAll(uploaders);

    final versions = json['versions'];
    if (versions != null) {
      this.versions.addAll(versions.map((v) => new Version.fromJson(this, v)));
    }

    // Report unsupported properties.
    final jsonProps = json.keys.toList();
    Set<String> properties = unsupportedProperties['Package'];
    if (properties == null) {
      properties = unsupportedProperties['Package'] = new Set<String>();
    }
    jsonProps.removeWhere((p) => supportedProps.contains(p));
    if (jsonProps.isNotEmpty) {
      properties.addAll(jsonProps);
      _log.info(
          'Package: ${name} doesn\'t save these properties: ${jsonProps}');
    }
  }

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(other) {
    if (other is! PubPackage) return false;
    return name == other.name;
  }
}

class Pubspec {
  Version parent;
  String version;
  String description;
  Map<String, Dependency> dependencies;
  Map<String, Dependency> devDependencies;
  String author;
  List<String> authors = <String>[];
  String documentation;
  String homepage;
  String name;
  Map<String, String> environment;
  List<Map> transformers;

  Uri url;
  Uri archiveUrl;
  Uri newDartdocUrl;
  Uri packageUrl;

// TODO(zoechi) executables, environnment, dependency_overrides
  static const supportedProps = const [
    'version',
    'description',
    'dependencies',
    'dev_dependencies',
    'author',
    'authors',
    'documentation',
    'homepage',
    'name',
    'environment',
    'transformers',
    'url',
    'archive_url',
    'new_dartdoc_url',
    'package_url'
  ];

  Pubspec.fromJson(Version parent, Map json) {
    this.parent = parent;
    if (json == null) return;
    version = json['version'];
    description = json['description'];
    final Map deps = json['dependencies'];
    if (deps != null) {
      dependencies = new Map.fromIterable(deps.keys,
          key: (k) => k, value: (k) => new Dependency.fromJson(this, deps[k]));
    } else {
      dependencies = {};
    }
    final devDeps = json['dev_dependencies'];
    if (devDeps != null) {
      devDependencies = new Map.fromIterable(devDeps.keys,
          key: (k) => k,
          value: (k) => new Dependency.fromJson(this, devDeps[k]));
    } else {
      devDependencies = {};
    }

    author = json['author'];
    final authors = json['authors'];
    if (authors != null) {
      this.authors.addAll(authors);
    }

    documentation = json['documentation'];
    homepage = json['homepage'];
    name = json['name'];
    environment = json['environment'];
    transformers = json['transformers'];

    final url = json['url'];
    if (url != null) this.url = Uri.parse(url);

    final archiveUrl = json['archive_url'];
    if (archiveUrl != null) this.archiveUrl = Uri.parse(archiveUrl);

    final newDartdocUrl = json['new_dartdoc_url'];
    if (newDartdocUrl != null) this.newDartdocUrl = Uri.parse(newDartdocUrl);

    final packageUrl = json['package_url'];
    if (packageUrl != null) this.packageUrl = Uri.parse(packageUrl);

    // Report unsupported properties.
    final jsonProps = json.keys.toList();
    Set<String> properties = unsupportedProperties['Pubspec'];
    if (properties == null) {
      properties = unsupportedProperties['Pubspec'] = new Set<String>();
    }
    jsonProps.removeWhere((p) => supportedProps.contains(p));
    if (jsonProps.isNotEmpty) {
      properties.addAll(jsonProps);
      _log.info(
          'Package: ${name} doesn\'t save these properties: ${jsonProps}');
    }
  }
}

class Dependency {
  Pubspec parent;
  final DependencyKind kind;
  final semver.VersionConstraint versionConstraint;
  /// For a path dependency the path.
  /// For a Git dependency the url.
  final String path;
  /// For a Git dependency the ref (tag, commit, branch)
  final String ref;

  Dependency(
      this.parent, this.kind, this.versionConstraint, this.path, this.ref);

  factory Dependency.fromJson(Pubspec parent, json) {
    DependencyKind kind;
    semver.VersionConstraint constraint;
    String path;
    String ref;

    if (json is String || json == null) {
      kind = DependencyKind.hosted;
      if (json != null) {
        constraint = new semver.VersionConstraint.parse(json);
      } else {
        constraint = semver.VersionConstraint.any;
      }
    } else {
      if (json.keys.length > 1) {
        throw 'Unsupported dependency: ${json}';
      }
      switch (json.keys.first) {
        case 'sdk':
          kind = DependencyKind.sdk;
          path = json[json.keys.first];
          break;
        case 'path':
          kind = DependencyKind.path;
          path = json[json.keys.first];
          break;
        case 'git':
          kind = DependencyKind.git;
          if (json['git'] is String) {
            path = json['git'];
          } else if (json['git'] is Map) {
            path = json['git']['url'];
            ref = json['git']['ref'];
          } else {
            throw 'Not supported Git dependency definition.';
          }
          break;
        default:
          throw 'Unsupported dependency: ${json}';
      }
    }
    return new Dependency(parent, kind, constraint, path, ref);
  }
}

enum DependencyKind { hosted, sdk, git, path, }
