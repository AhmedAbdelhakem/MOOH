// services/google_drive_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const String _clientId = '126041465108-2nua4t9t9r9sl125sj7etdvjul2ovjhp.apps.googleusercontent.com';
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.metadata'
  ];
  static const String _folderName = 'mooh';

  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  String? _folderId;

  bool get isConnected => _driveApi != null;
  String? get folderId => _folderId;

  Future<void> initialize() async {
    await _checkInternetConnection();
    await _signIn();
    await _initializeDriveApi();
    await _createOrGetFolder();
  }

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('No internet connection available');
      }
    } on SocketException {
      throw Exception('No internet connection available');
    }
  }

  Future<void> _signIn() async {
    _googleSignIn = GoogleSignIn(
      scopes: _scopes,
      clientId: kIsWeb ? _clientId : null,
    );

    if (_googleSignIn!.currentUser != null) {
      await _googleSignIn!.signOut();
    }

    final account = await _googleSignIn!.signIn();
    if (account == null) {
      throw Exception('Google sign-in was cancelled by user');
    }
  }

  Future<void> _initializeDriveApi() async {
    final account = _googleSignIn!.currentUser;
    if (account == null) throw Exception('No signed-in user');

    final authHeaders = await _getAuthHeaders(account);
    if (authHeaders == null) {
      throw Exception('Failed to obtain authentication credentials');
    }

    _driveApi = drive.DriveApi(_GoogleAuthClient(authHeaders));
    await _testConnection();
  }

  Future<Map<String, String>?> _getAuthHeaders(GoogleSignInAccount account) async {
    for (int retry = 0; retry < 3; retry++) {
      try {
        final authHeaders = await account.authHeaders;
        if (authHeaders.containsKey('Authorization') &&
            authHeaders['Authorization']!.startsWith('Bearer ')) {
          return authHeaders;
        }
        throw Exception('Invalid authorization token');
      } catch (e) {
        if (retry < 2) {
          await Future.delayed(Duration(seconds: (retry + 1) * 2));
          await account.authentication;
        }
      }
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (_driveApi == null) throw Exception('Drive API not initialized');

    try {
      await _driveApi!.about.get($fields: 'user').timeout(const Duration(seconds: 10));
      await _driveApi!.files.list(pageSize: 1, $fields: 'files(id, name)')
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (e.toString().contains('403')) {
        throw Exception('Google Drive API access denied. Check Google Cloud Console configuration.');
      }
      throw Exception('Failed to connect to Google Drive API: $e');
    }
  }

  Future<void> _createOrGetFolder() async {
    if (_driveApi == null) throw Exception('Drive API not initialized');

    final query = "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";

    final fileList = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
      pageSize: 1,
    ).timeout(const Duration(seconds: 15));

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      _folderId = fileList.files!.first.id;
    } else {
      final folder = drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi!.files.create(
        folder,
        $fields: 'id, name',
      ).timeout(const Duration(seconds: 15));

      _folderId = createdFolder.id;
    }

    if (_folderId == null) {
      throw Exception('Failed to create or retrieve Google Drive folder');
    }
  }

  Future<String?> uploadFile(XFile file) async {
    if (_driveApi == null || _folderId == null) return null;

    try {
      final fileBytes = kIsWeb
          ? await file.readAsBytes()
          : await File(file.path).readAsBytes();

      final driveFile = drive.File()
        ..name = file.name
        ..parents = [_folderId!]
        ..description = 'Uploaded from MOOH app';

      final media = drive.Media(Stream.value(fileBytes), fileBytes.length);
      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name',
      ).timeout(const Duration(seconds: 30));

      return result.id;
    } catch (e) {
      print('Failed to upload ${file.name}: $e');
      return null;
    }
  }

  Future<void> deleteFile(String fileId) async {
    if (_driveApi == null) return;

    try {
      await _driveApi!.files.delete(fileId);
    } catch (e) {
      print('Error deleting file from Google Drive: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      print('Error signing out from Google: $e');
    }
    _driveApi = null;
    _folderId = null;
  }

  String getSimplifiedError(String error) {
    if (error.contains('403')) return 'API not enabled or permissions missing';
    if (error.contains('401')) return 'Authentication failed';
    if (error.contains('400')) return 'Invalid request';
    if (error.contains('NetworkException') || error.contains('SocketException')) {
      return 'Network connection issue';
    }
    if (error.contains('cancelled')) return 'Sign-in was cancelled';
    if (error.contains('TimeoutException')) return 'Connection timeout';
    return 'Connection error - please try again';
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() => _client.close();
}