import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<ImageData> _images = [];
  String? _userId;
  drive.DriveApi? _driveApi;
  String? _googleDriveFolderId;
  bool _isUploading = false;

  // Google OAuth credentials
  static const String _clientId = '126041465108-6a080hmjvieif2ku4nukc7nf80bd4ool.apps.googleusercontent.com';
  static const List<String> _scopes = ['https://www.googleapis.com/auth/drive.file'];

  @override
  void initState() {
    super.initState();
    _loadUserAndImages();
    _initializeGoogleDrive();
  }

  Future<void> _initializeGoogleDrive() async {
    try {
      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(
        clientId: _clientId, // مهم للويب فقط
        scopes: _scopes,
      )
          : GoogleSignIn.standard(
        scopes: _scopes,
      );

      final account = await googleSignIn.signIn();

      if (account == null) {
        throw Exception('Google sign-in aborted');
      }

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);

      _driveApi = drive.DriveApi(authenticateClient);
      await _createOrGetFolder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive connected successfully!')),
        );
      }
    } catch (e) {
      print('Error initializing Google Drive: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to Google Drive: $e')),
        );
      }
    }
  }

  Future<void> _createOrGetFolder() async {
    if (_driveApi == null) return;

    try {
      final query = "name='My App Images' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final fileList = await _driveApi!.files.list(q: query);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        _googleDriveFolderId = fileList.files!.first.id;
      } else {
        final folder = drive.File()
          ..name = 'My App Images'
          ..mimeType = 'application/vnd.google-apps.folder';

        final createdFolder = await _driveApi!.files.create(folder);
        _googleDriveFolderId = createdFolder.id;
      }
    } catch (e) {
      print('Error creating/getting folder: $e');
    }
  }

  Future<void> _loadUserAndImages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('logged_user_id');

    if (_userId == null) return;

    List<String> imageDataJson = prefs.getStringList('saved_images_$_userId') ?? [];

    List<ImageData> existingImages = [];
    for (String jsonData in imageDataJson) {
      try {
        ImageData imageData = ImageData.fromJson(jsonData);

        if (kIsWeb) {
          existingImages.add(imageData);
        } else {
          if (await File(imageData.localPath).exists()) {
            existingImages.add(imageData);
          }
        }
      } catch (e) {
        print('Error parsing image data: $e');
      }
    }

    setState(() {
      _images = existingImages;
    });

    await _saveImagesToPrefs();
  }

  Future<void> _saveImagesToPrefs() async {
    if (_userId == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> imageDataJson = _images.map((img) => img.toJson()).toList();
    await prefs.setStringList('saved_images_$_userId', imageDataJson);
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });

      List<ImageData> newImages = [];

      for (var file in pickedFiles) {
        bool exists = _images.any((img) => img.localPath == file.path);
        if (!exists) {
          try {
            String? driveFileId = await _uploadToGoogleDrive(file);

            ImageData imageData = ImageData(
              localPath: file.path,
              driveFileId: driveFileId,
              fileName: file.name,
              uploadedAt: DateTime.now(),
            );

            newImages.add(imageData);
          } catch (e) {
            print('Error uploading ${file.name}: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload ${file.name}')),
            );
          }
        }
      }

      if (newImages.isNotEmpty) {
        setState(() {
          _images.addAll(newImages);
          _isUploading = false;
        });

        await _saveImagesToPrefs();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully uploaded ${newImages.length} images to Google Drive!')),
        );
      } else {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<String?> _uploadToGoogleDrive(XFile file) async {
    if (_driveApi == null || _googleDriveFolderId == null) {
      throw Exception('Google Drive not initialized');
    }

    try {
      Uint8List fileBytes;
      if (kIsWeb) {
        fileBytes = await file.readAsBytes();
      } else {
        fileBytes = await File(file.path).readAsBytes();
      }

      final driveFile = drive.File()
        ..name = file.name
        ..parents = [_googleDriveFolderId!];

      final media = drive.Media(
        Stream.fromIterable([fileBytes]),
        fileBytes.length,
      );

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      return result.id;
    } catch (e) {
      print('Error uploading to Google Drive: $e');
      rethrow;
    }
  }

  Future<void> _deleteFromGoogleDrive(String driveFileId) async {
    if (_driveApi == null) return;

    try {
      await _driveApi!.files.delete(driveFileId);
    } catch (e) {
      print('Error deleting from Google Drive: $e');
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_user_id');

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  void _deleteImage(int index) async {
    final imageData = _images[index];

    if (imageData.driveFileId != null) {
      await _deleteFromGoogleDrive(imageData.driveFileId!);
    }

    setState(() {
      _images.removeAt(index);
    });

    await _saveImagesToPrefs();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image deleted from local storage and Google Drive')),
    );
  }

  void _showImageDetails(ImageData imageData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(imageData.fileName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uploaded: ${imageData.uploadedAt.toString()}'),
            const SizedBox(height: 8),
            Text('Status: ${imageData.driveFileId != null ? 'Synced to Google Drive' : 'Local only'}'),
            if (imageData.driveFileId != null) ...[
              const SizedBox(height: 8),
              Text('Drive ID: ${imageData.driveFileId}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        centerTitle: true,
        title: SvgPicture.asset("assets/images/Logo-MOOH2.svg", height: 40),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          IconButton(
            icon: _isUploading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.add_photo_alternate),
            tooltip: 'Pick Images',
            onPressed: _isUploading ? null : _pickImages,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            if (_driveApi != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_done, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Connected to Google Drive', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            Expanded(
              child: _images.isEmpty
                  ? const Center(child: Text('No images selected.'))
                  : GridView.builder(
                itemCount: _images.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final ImageData imageData = _images[index];
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showImageDetails(imageData),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(
                            imageData.localPath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                              : Image.file(
                            File(imageData.localPath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: imageData.driveFileId != null
                                ? Colors.green.withOpacity(0.8)
                                : Colors.orange.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            imageData.driveFileId != null ? Icons.cloud_done : Icons.cloud_off,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () => _deleteImage(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom HTTP client adding auth headers for Google APIs
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
  }
}

class ImageData {
  final String localPath;
  final String? driveFileId;
  final String fileName;
  final DateTime uploadedAt;

  ImageData({
    required this.localPath,
    this.driveFileId,
    required this.fileName,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'localPath': localPath,
      'driveFileId': driveFileId,
      'fileName': fileName,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  static ImageData fromJson(String jsonStr) {
    final Map<String, dynamic> map = json.decode(jsonStr);
    return ImageData(
      localPath: map['localPath'],
      driveFileId: map['driveFileId'],
      fileName: map['fileName'],
      uploadedAt: DateTime.parse(map['uploadedAt']),
    );
  }
}