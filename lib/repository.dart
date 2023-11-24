import 'dart:async';

import 'package:pub_semver/pub_semver.dart';

/// Represents information about a specific version of a pub package.
class PackageVersion {
  final String packageName;
  final String versionString;
  final String pubspecYaml;

  late Version _cached;

  Version get version {
    _cached = _cached ?? Version.parse(versionString);
    return _cached;
  }

  PackageVersion(this.packageName, this.versionString, this.pubspecYaml);

  @override
  int get hashCode =>
      packageName.hashCode ^ versionString.hashCode ^ pubspecYaml.hashCode;

  @override
  bool operator ==(other) {
    return other is PackageVersion &&
        other.packageName == packageName &&
        other.versionString == versionString &&
        other.pubspecYaml == pubspecYaml;
  }

  @override
  String toString() => 'PackageVersion: $packageName/$versionString';
}

/// Information obtained when starting an asynchronous upload.
class AsyncUploadInfo {
  final Uri uri;
  final Map<String, String> fields;

  AsyncUploadInfo(this.uri, this.fields);
}

/// A marker interface that indicates a problem with the client-provided inputs.
abstract class ClientSideProblem implements Exception {}

/// Exception for unauthorized access attempts.
class UnauthorizedAccessException implements ClientSideProblem {
  final String message;

  UnauthorizedAccessException(this.message);

  @override
  String toString() => 'UnauthorizedAccess: $message';
}

/// Exception for removing the last uploader.
class LastUploaderRemoveException implements ClientSideProblem {
  LastUploaderRemoveException();

  @override
  String toString() =>
      'LastUploaderRemoved: Cannot remove last uploader of a package.';
}

/// Exception for adding an already-existent uploader.
class UploaderAlreadyExistsException implements ClientSideProblem {
  UploaderAlreadyExistsException();

  @override
  String toString() =>
      'UploaderAlreadyExists: Cannot add an already existent uploader.';
}

/// Generic exception during processing of the clients request.
class GenericProcessingException implements ClientSideProblem {
  final String message;

  GenericProcessingException(this.message);

  factory GenericProcessingException.validationError(String message) =>
      GenericProcessingException('ValidationError: $message');

  @override
  String toString() => message;
}

/// Represents a pub repository.
abstract class PackageRepository {
  Stream<PackageVersion> versions(String package);

  Future<PackageVersion> lookupVersion(String package, String version);

  bool get supportsUpload => false;

  Future<PackageVersion> upload(Stream<List<int>> data) =>
      Future.error(UnsupportedError('No upload support.'));

  bool get supportsAsyncUpload => false;

  Future<AsyncUploadInfo> startAsyncUpload(Uri redirectUrl) =>
      Future.error(UnsupportedError('No async upload support.'));

  Future<PackageVersion> finishAsyncUpload(Uri uri) =>
      Future.error(UnsupportedError('No async upload support.'));

  Future<Stream<List<int>>> download(String package, String version);

  bool get supportsDownloadUrl => false;

  Future<Uri> downloadUrl(String package, String version) =>
      Future.error(UnsupportedError('No download link support.'));

  bool get supportsUploaders => false;

  Future addUploader(String package, String userEmail) =>
      Future.error(UnsupportedError('No uploader support.'));

  Future removeUploader(String package, String userEmail) =>
      Future.error(UnsupportedError('No uploader support.'));
}
