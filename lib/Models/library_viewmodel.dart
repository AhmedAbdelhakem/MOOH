import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Services/google_drive_services.dart';
import '../models/image_model.dart';
import '../models/image_repository.dart';

enum DriveConnectionStatus { connecting, connected, failed }

class LibraryViewModel extends ChangeNotifier {
  final GoogleDriveService _driveService = GoogleDriveService();
  final ImageRepository _imageRepository = ImageRepository();
  final ImagePicker _imagePicker = ImagePicker();

  List<ImageModel> _images = [];
  String? _userId;
  bool _isUploading = false;
  DriveConnectionStatus _driveStatus = DriveConnectionStatus.connecting;
  String? _driveError;

  // Getters
  List<ImageModel> get images => _images;
  bool get isUploading => _isUploading;
  DriveConnectionStatus get driveStatus => _driveStatus;
  String? get driveError => _driveError;
  bool get isDriveConnected => _driveStatus == DriveConnectionStatus.connected;

  Future<void> initialize() async {
    await _loadUserAndImages();
    await _initializeDriveConnection();
  }

  Future<void> _loadUserAndImages() async {
    _userId = await _imageRepository.getUserId();
    if (_userId != null) {
      _images = await _imageRepository.getImages(_userId!);
      notifyListeners();
    }
  }

  Future<void> _initializeDriveConnection() async {
    try {
      _driveStatus = DriveConnectionStatus.connecting;
      _driveError = null;
      notifyListeners();

      await _driveService.initialize();

      _driveStatus = DriveConnectionStatus.connected;
      _driveError = null;
    } catch (e) {
      _driveStatus = DriveConnectionStatus.failed;
      _driveError = _driveService.getSimplifiedError(e.toString());
    }
    notifyListeners();
  }

  Future<void> pickImages() async {
    final pickedFiles = await _imagePicker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    _isUploading = true;
    notifyListeners();

    final List<ImageModel> newImages = [];

    for (var file in pickedFiles) {
      if (_images.any((img) => img.localPath == file.path)) continue;

      String? driveFileId;

      if (isDriveConnected) {
        try {
          final fileBytes = await file.readAsBytes();
          driveFileId = await _driveService.uploadFile(file.name, fileBytes);

          if (driveFileId != null) {
            newImages.add(
              ImageModel(
                localPath: file.path,
                driveFileId: driveFileId,
                fileName: file.name,
                uploadedAt: DateTime.now(),
              ),
            );
          }
        } catch (e) {
          print("Upload failed for ${file.name}: $e");
        }
      }
    }

    _isUploading = false;

    if (newImages.isNotEmpty) {
      _images.addAll(newImages);
      await _saveImages();
      notifyListeners();
    }
  }

  Future<void> deleteImage(int index) async {
    final imageData = _images[index];

    if (imageData.driveFileId != null && isDriveConnected) {
      try {
        await _driveService.deleteFile(imageData.driveFileId!);
      } catch (e) {
        print('Error deleting image from Drive: $e');
      }
    }

    _images.removeAt(index);
    await _saveImages();
    notifyListeners();
  }

  Future<void> retryDriveConnection() async {
    await _initializeDriveConnection();
  }

  Future<void> logout() async {
    await _imageRepository.clearUserId();
  }

  Future<void> _saveImages() async {
    if (_userId != null) {
      await _imageRepository.saveImages(_userId!, _images);
    }
  }

  String getUploadStatusMessage(List<ImageModel> newImages) {
    final uploadedCount =
        newImages.where((img) => img.driveFileId != null).length;
    final localCount = newImages.length - uploadedCount;

    if (uploadedCount > 0 && localCount > 0) {
      return '✅ Added ${newImages.length} image(s): $uploadedCount uploaded to Drive, $localCount saved locally';
    } else if (uploadedCount > 0) {
      return '✅ Uploaded $uploadedCount image(s) to Google Drive successfully!';
    } else {
      return '✅ Added $localCount image(s) locally (Drive not connected)';
    }
  }

  String getSimplifiedDriveError() {
    if (_driveError == null) return '';
    return _driveError!;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
