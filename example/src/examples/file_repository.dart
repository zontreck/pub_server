import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pub_server/repository.dart';
import 'package:yaml/yaml.dart';

final Logger _logger = Logger('pub_server.file_repository');

class FileRepository extends PackageRepository {
  final String baseDir;

  FileRepository(this.baseDir);

  @override
  Stream<PackageVersion> versions(String package) async* {
    var directory = Directory(p.join(baseDir, package));
    if (directory.existsSync()) {
      await for (var dir in directory.list(recursive: false)) {
        if (dir is Directory) {
          var version = p.basename(dir.path);
          var pubspecFile = File(pubspecFilePath(package, version));
          var tarballFile = File(packageTarballPath(package, version));
          if (pubspecFile.existsSync() && tarballFile.existsSync()) {
            var pubspec = await pubspecFile.readAsString();
            yield PackageVersion(package, version, pubspec);
          }
        }
      }
    }
  }

  @override
  Future<PackageVersion> lookupVersion(String package, String version) async {
    var matchingVersions = await versions(package)
        .where((pv) => pv.versionString == version)
        .toList();
    return matchingVersions.isNotEmpty ? matchingVersions.first : null;
  }

  @override
  bool get supportsUpload => true;

  @override
  Future<PackageVersion> upload(Stream<List<int>> data) async {
    _logger.info('Start uploading package.');
    var tarballBytes = await data
        .fold<List<int>>(<int>[], (combined, data) => combined..addAll(data));
    var tarBytes = GZipDecoder().decodeBytes(tarballBytes);
    var archive = TarDecoder().decodeBytes(tarBytes);
    var pubspecArchiveFile = archive.files.firstWhere(
        (file) => file.name == 'pubspec.yaml',
        orElse: () =>
            throw 'Did not find any pubspec.yaml file in upload. Aborting.');

    var pubspec =
        loadYaml(convert.utf8.decode(pubspecArchiveFile.content as List<int>));

    var package = pubspec['name'] as String;
    var version = pubspec['version'] as String;

    var packageVersionDir = Directory(p.join(baseDir, package, version));

    if (!packageVersionDir.existsSync()) {
      packageVersionDir.createSync(recursive: true);
    }

    var pubspecFile = File(pubspecFilePath(package, version));
    if (pubspecFile.existsSync()) {
      throw StateError('`$package` already exists at version `$version`.');
    }

    var pubspecContent =
        convert.utf8.decode(pubspecArchiveFile.content as List<int>);
    pubspecFile.writeAsStringSync(pubspecContent);
    File(packageTarballPath(package, version)).writeAsBytesSync(tarballBytes);

    _logger.info('Uploaded new $package/$version');

    return PackageVersion(package, version, pubspecContent);
  }

  @override
  bool get supportsDownloadUrl => false;

  @override
  Future<Stream<List<int>>> download(String package, String version) async {
    var pubspecFile = File(pubspecFilePath(package, version));
    var tarballFile = File(packageTarballPath(package, version));

    if (pubspecFile.existsSync() && tarballFile.existsSync()) {
      return tarballFile.openRead();
    } else {
      throw 'Package cannot be downloaded because it does not exist';
    }
  }

  String pubspecFilePath(String package, String version) =>
      p.join(baseDir, package, version, 'pubspec.yaml');

  String packageTarballPath(String package, String version) =>
      p.join(baseDir, package, version, 'package.tar.gz');
}
