library bwu_pub_client.src.pub_client;

import 'dart:async' show Future, Stream;
import 'dart:convert' show JSON;
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

final _log = new Logger('bwu_pub_client.src.pub_client');

final Map<String, Set<String>> unsupportedProperties = <String, Set<String>>{};

Uri packageUri(String name) =>
    Uri.parse('https://pub.dartlang.org/api/packages/${name}');

Uri pageUri(int page) =>
    Uri.parse('https://pub.dartlang.org/api/packages?page=${page}');

class PubClient {
  http.Client httpClient;

  PubClient(this.httpClient);

  Future<PubDartlangPage> fetchPage(int page) async {
    final response = (await httpClient.get(pageUri(page))).body;
    _log.finest('fetch page: ${pageUri(page)}');
    _log.finest(response);
    final pubPage = new PubDartlangPage.fromJson(JSON.decode(response));

    await for(final p in pubPage.packages) {// .getRange(0, 10), (p) {
      await fetchPackage(p);
    }
    return pubPage;
  }

  Future<PubPackage> fetchPackageByName(String name) async {
    final response = (await httpClient.get(packageUri(name))).body;
    _log.finest('fetch page: ${packageUri(name)}');
    _log.finest(response);
    return fetchPackage(new PubPackage.fromJson(JSON.decode(response)));
  }

  Future<PubPackage> fetchPackage(PubPackage p) async {
    final response = (await httpClient.get(p.url)).body;
    _log.finest('fetch package: ${p.url}');
    _log.finest(response);
    p.loadFromJson(JSON.decode(response));
    await for (final v in p.versions) {
      await fetchVersion(v);
    }
    return p;
  }

  Future<Version> fetchVersion(Version v) async {
    final response = (await httpClient.get(v.url)).body;
    _log.finest('fetch version: ${v.url}');
    _log.finest(response);
    return v..loadFromJson(JSON.decode(response));
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
  Pubspec pubspec;
  Uri url;
  Uri archiveUrl;
  String version;
  Uri newDartdocUrl;
  Uri packageUrl;
  int downloads;
  DateTime createdAt;
  final Set<String> libraries = new Set<String>();
  String uploader;

  Version();

  factory Version.fromJson(Map json) {
    return new Version()..loadFromJson(json);
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

  loadFromJson(Map json) {
    if (json == null) {
      return;
    }
    pubspec = new Pubspec.fromJson(json['pubspec']);

    final url = json['url'];
    if (url != null) this.url = Uri.parse(url);

    final archiveUrl = json['archive_url'];
    if (archiveUrl != null) this.archiveUrl = Uri.parse(archiveUrl);

    final version = json['version'];
    if (version != null) this.version = version;

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
  int get hashCode => version.hashCode;

  @override
  bool operator ==(other) {
    if (other == null) return false;
    if (identical(this, other)) return true;
    if (other is! Version) return false;
    return url == other.url && version == other.version;
  }
}

class PubDartlangPage {
  Uri prevUrl;
  Uri nextUrl;
  final List<PubPackage> packages = <PubPackage>[];
  int pages;

  static const supportedProps = const [
    'prev_url',
    'next_url',
    'pages',
    'packages'
  ];

  PubDartlangPage.fromJson(Map json) {
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
}

class PubPackage {
  String name;
  Uri url;
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

  factory PubPackage.fromJson(Map json) {
    return new PubPackage()..loadFromJson(json);
  }

  PubPackage();

  void loadFromJson(Map json) {
    if (json == null) return;

    name = json['name'];

    final url = json['url'];
    if (url != null) this.url = Uri.parse(url);

    final uploadersUrl = json['uploaders_url'];
    if (uploadersUrl != null) this.uploadersUrl = Uri.parse(uploadersUrl);

    final newVersionUrl = json['new_version_url'];
    if (newVersionUrl != null) this.newVersionUrl = Uri.parse(newVersionUrl);

    final versionUrl = json['version_url'];
    if (versionUrl != null) this.versionUrl = Uri.parse(versionUrl);

    latest = new Version.fromJson(json['latest']);

    final created = json['created'];
    if (created != null) this.createdAt = DateTime.parse(created);

    final downloads = json['downloads'];
    if (downloads != null) this.downloads = downloads;

    final uploaders = json['uploaders'];
    if (uploaders != null) this.uploaders.addAll(uploaders);

    final versions = json['versions'];
    if (versions != null) {
      this.versions.addAll(versions.map((v) => new Version.fromJson(v)));
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
}

class Pubspec {
  String version;
  String description;
  Map<String, String> dependencies;
  Map<String, String> devDependencies;
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

  Pubspec.fromJson(Map json) {
    if (json == null) return;

    version = json['version'];
    description = json['description'];
    dependencies = json['dependencies'];
    devDependencies = json['dev_dependencies'];
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
