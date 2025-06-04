import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const _scopes = [drive.DriveApi.driveFileScope];
  static const _folderId = '1CfNb9Qs0NdzYfuSgxvME8PmdLl5CwDTy'; // ID فولدر MOOH

  late AutoRefreshingAuthClient _client;
  late drive.DriveApi _driveApi;

  /// تهيئة Google Drive API
  Future<void> initialize() async {
    try {
      final credentials = await _loadServiceAccountCredentials();
      _client = await clientViaServiceAccount(credentials, _scopes);
      _driveApi = drive.DriveApi(_client);
    } catch (e) {
      print('❌ Failed to initialize Google Drive: $e');
      rethrow;
    }
  }

  /// تحميل بيانات حساب الخدمة من ملف JSON في assets
  Future<ServiceAccountCredentials> _loadServiceAccountCredentials() async {
    try {
      final jsonString = await rootBundle.loadString('assets/mooh-20804-180a157b4d00.json');
      final jsonMap = json.decode(jsonString);
      return ServiceAccountCredentials.fromJson(jsonMap);
    } catch (e) {
      print('❌ Failed to load service account credentials: $e');
      rethrow;
    }
  }

  /// رفع ملف إلى فولدر Drive
  Future<String?> uploadFile(String fileName, Uint8List fileBytes) async {
    try {
      final media = drive.Media(Stream.value(fileBytes), fileBytes.length);
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [_folderId];

      final result = await _driveApi.files.create(driveFile, uploadMedia: media);
      print('✅ File uploaded: ${result.name} (${result.id})');
      return result.id;
    } catch (e) {
      print('❌ Failed to upload file: $e');
      return null;
    }
  }

  /// حذف ملف من Google Drive
  Future<void> deleteFile(String fileId) async {
    try {
      await _driveApi.files.delete(fileId);
      print('🗑️ File deleted: $fileId');
    } catch (e) {
      print('❌ Failed to delete file: $e');
    }
  }

  /// تبسيط رسالة الخطأ لعرضها في الواجهة
  String getSimplifiedError(String error) {
    if (error.contains('403')) {
      return '🚫 Access denied. تأكد إن فولدر Drive متشارك مع Service Account.';
    }
    if (error.contains('401')) {
      return '🔒 Unauthorized. تأكد من ملف الـ JSON ومفتاح الخدمة.';
    }
    if (error.contains('SocketException')) {
      return '🌐 لا يوجد اتصال بالإنترنت.';
    }
    if (error.contains('TimeoutException')) {
      return '⏱️ انتهت المهلة. حاول مرة أخرى.';
    }
    return '❗ حدث خطأ غير معروف:\n$error';
  }
}