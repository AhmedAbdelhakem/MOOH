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
  bool _isDriveConnected = false;
  String? _driveConnectionError;
  GoogleSignIn? _googleSignIn;

  // Replace with your actual client ID from Google Cloud Console
  static const String _clientId =
      '126041465108-2nua4t9t9r9sl125sj7etdvjul2ovjhp.apps.googleusercontent.com';

  // Updated scopes with proper Google Drive permissions
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.metadata'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAndImages();
    // Delay Google Drive initialization to allow UI to settle
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _initializeGoogleDrive();
      }
    });
  }

  @override
  void dispose() {
    _googleSignIn?.signOut();
    super.dispose();
  }

  Future<void> _initializeGoogleDrive() async {
    if (!mounted) return;

    try {
      setState(() {
        _isDriveConnected = false;
        _driveConnectionError = null;
      });

      // Check internet connectivity first
      if (!await _hasInternetConnection()) {
        throw Exception('No internet connection available');
      }

      // Initialize GoogleSignIn with proper configuration
      _googleSignIn = GoogleSignIn(
        scopes: _scopes,
        // For web, clientId is handled differently
        clientId: kIsWeb ? _clientId : null,
      );

      print('🔄 Starting Google Sign-In...');

      // Clear any existing sign-in state
      if (_googleSignIn!.currentUser != null) {
        await _googleSignIn!.signOut();
      }

      // Attempt to sign in
      GoogleSignInAccount? account = await _googleSignIn!.signIn();

      if (account == null) {
        throw Exception('Google sign-in was cancelled by user');
      }

      print('✅ Google Sign-In successful: ${account.email}');

      // Get authentication headers with improved error handling
      Map<String, String>? authHeaders = await _getAuthHeaders(account);

      if (authHeaders == null || authHeaders.isEmpty) {
        throw Exception('Failed to obtain authentication credentials');
      }

      print('✅ Authentication headers obtained');

      // Initialize Drive API with authenticated client
      final authenticateClient = GoogleAuthClient(authHeaders);
      _driveApi = drive.DriveApi(authenticateClient);

      // Test the API connection
      await _testDriveConnection();

      // Create or get the folder
      await _createOrGetFolder();

      if (_googleDriveFolderId == null) {
        throw Exception('Failed to create or retrieve Google Drive folder');
      }

      if (mounted) {
        setState(() {
          _isDriveConnected = true;
          _driveConnectionError = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Google Drive connected successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error initializing Google Drive: $e');

      if (mounted) {
        setState(() {
          _isDriveConnected = false;
          _driveConnectionError = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Failed to connect to Google Drive: ${_getSimplifiedError(e.toString())}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _initializeGoogleDrive,
            ),
          ),
        );
      }
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<Map<String, String>?> _getAuthHeaders(
      GoogleSignInAccount account) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final authHeaders = await account.authHeaders;

        // Validate that we have the necessary authorization header
        if (authHeaders.containsKey('Authorization') &&
            authHeaders['Authorization']!.startsWith('Bearer ')) {
          return authHeaders;
        } else {
          throw Exception('Invalid or missing authorization token');
        }
      } catch (e) {
        print('⚠️ Retry $retryCount: Failed to get auth headers: $e');
        retryCount++;

        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: retryCount * 2));

          // Try to refresh the authentication
          try {
            await account.authentication;
          } catch (authError) {
            print('Failed to refresh authentication: $authError');
          }
        }
      }
    }

    return null;
  }

  String _getSimplifiedError(String error) {
    if (error.contains('403') || error.contains('Permission denied')) {
      return 'API not enabled or permissions missing - check Google Cloud Console';
    }
    if (error.contains('401')) return 'Authentication failed - please sign in again';
    if (error.contains('400')) return 'Invalid request - check API configuration';
    if (error.contains('NetworkException') ||
        error.contains('SocketException') ||
        error.contains('No internet connection')) {
      return 'Network connection issue - check your internet';
    }
    if (error.contains('cancelled')) return 'Sign-in was cancelled';
    if (error.contains('ClientId') || error.contains('Invalid client')) {
      return 'Invalid client ID configuration';
    }
    if (error.contains('API_NOT_AVAILABLE')) {
      return 'Google Play Services not available';
    }
    return 'Connection error - please try again';
  }

  Future<void> _testDriveConnection() async {
    if (_driveApi == null) throw Exception('Drive API not initialized');

    try {
      print('🔍 Testing Drive API connection...');

      // Test with a simple about request with timeout
      final about =
      await _driveApi!.about.get($fields: 'user').timeout(const Duration(seconds: 10));

      print(
          '✅ Drive API connection test successful - User: ${about.user?.displayName}');

      // Also test files.list to ensure we have the right permissions
      final fileList = await _driveApi!.files.list(
        pageSize: 1,
        $fields: 'files(id, name)',
      ).timeout(const Duration(seconds: 10));

      print('✅ Files list test successful - Found ${fileList.files?.length ?? 0} files');
    } catch (e) {
      print('❌ Drive API connection test failed: $e');

      // Provide more specific error information
      if (e.toString().contains('403')) {
        throw Exception('Google Drive API access denied. Please:\n'
            '1. Enable Google Drive API in Google Cloud Console\n'
            '2. Configure OAuth consent screen properly\n'
            '3. Add test users if app is in testing mode\n'
            '4. Verify OAuth client configuration');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('Connection timeout - check your internet connection');
      }

      throw Exception('Failed to connect to Google Drive API: ${e.toString()}');
    }
  }

  Future<void> _createOrGetFolder() async {
    if (_driveApi == null) {
      throw Exception('Drive API not initialized');
    }

    try {
      const folderName = 'mooh';
      print('🔍 Searching for existing folder: $folderName');

      // Search for existing folder with proper query and timeout
      final query =
          "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";

      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, parents)',
        pageSize: 10,
      ).timeout(const Duration(seconds: 15));

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        _googleDriveFolderId = fileList.files!.first.id;
        print('📁 Found existing folder: ${fileList.files!.first.name} (ID: $_googleDriveFolderId)');
      } else {
        print('📁 Creating new folder: $folderName');

        final folder = drive.File()
          ..name = folderName
          ..mimeType = 'application/vnd.google-apps.folder';

        final createdFolder = await _driveApi!.files.create(
          folder,
          $fields: 'id, name',
        ).timeout(const Duration(seconds: 15));

        _googleDriveFolderId = createdFolder.id;
        print('✅ Created folder "$folderName" with ID: $_googleDriveFolderId');
      }

      if (_googleDriveFolderId == null || _googleDriveFolderId!.isEmpty) {
        throw Exception('Folder ID is null or empty after creation/retrieval');
      }
    } catch (e) {
      print('❌ Error in _createOrGetFolder: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Timeout creating/accessing Google Drive folder - check your connection');
      }
      throw Exception('Failed to create or access Google Drive folder: $e');
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
        if (kIsWeb || await File(imageData.localPath).exists()) {
          existingImages.add(imageData);
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
      setState(() => _isUploading = true);
      List<ImageData> newImages = [];

      for (var file in pickedFiles) {
        if (!_images.any((img) => img.localPath == file.path)) {
          String? driveFileId;

          if (_isDriveConnected) {
            driveFileId = await _uploadToGoogleDrive(file);
          }

          newImages.add(ImageData(
            localPath: file.path,
            driveFileId: driveFileId,
            fileName: file.name,
            uploadedAt: DateTime.now(),
          ));
        }
      }

      setState(() => _isUploading = false);

      if (newImages.isNotEmpty) {
        setState(() => _images.addAll(newImages));
        await _saveImagesToPrefs();

        final uploadedCount = newImages.where((img) => img.driveFileId != null).length;
        final localCount = newImages.length - uploadedCount;

        String message = '';
        if (uploadedCount > 0 && localCount > 0) {
          message =
          '✅ Added ${newImages.length} image(s): $uploadedCount uploaded to Drive, $localCount saved locally';
        } else if (uploadedCount > 0) {
          message = '✅ Uploaded ${uploadedCount} image(s) to Google Drive successfully!';
        } else {
          message = '✅ Added ${localCount} image(s) locally (Drive not connected)';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    }
  }

  Future<String?> _uploadToGoogleDrive(XFile file) async {
    if (_driveApi == null || _googleDriveFolderId == null || !_isDriveConnected) {
      print('❌ Cannot upload: Drive not connected or folder not available');
      return null;
    }

    try {
      print('📤 Uploading ${file.name} to Google Drive...');

      Uint8List fileBytes =
      kIsWeb ? await file.readAsBytes() : await File(file.path).readAsBytes();

      final driveFile = drive.File()
        ..name = file.name
        ..parents = [_googleDriveFolderId!]
        ..description = 'Uploaded from MOOH app';

      final media = drive.Media(Stream.value(fileBytes), fileBytes.length);
      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name, size',
      ).timeout(const Duration(seconds: 30)); // Add timeout for uploads

      print('✅ File uploaded: ${file.name} → ID: ${result.id}');
      return result.id;
    } catch (e) {
      print('❌ Failed to upload ${file.name}: $e');

      // Show user-friendly error message
      if (mounted) {
        String errorMessage = e.toString().contains('TimeoutException')
            ? 'Upload timeout - file may be too large or connection slow'
            : _getSimplifiedError(e.toString());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload ${file.name}: $errorMessage'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _logout() async {
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      print('Error signing out from Google: $e');
    }

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
    if (imageData.driveFileId != null && _isDriveConnected) {
      try {
        await _driveApi?.files.delete(imageData.driveFileId!);
        print('✅ Deleted from Google Drive: ${imageData.fileName}');
      } catch (e) {
        print('Error deleting from Google Drive: $e');
      }
    }
    setState(() => _images.removeAt(index));
    await _saveImagesToPrefs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image deleted')),
      );
    }
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
            Text(
                'Status: ${imageData.driveFileId != null ? 'Synced to Google Drive' : 'Local only'}'),
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

  Widget _buildConnectionStatus() {
    if (_isDriveConnected) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.cloud_done, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connected to Google Drive',
                style:
                TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    } else if (_driveConnectionError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Drive connection failed',
                    style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getSimplifiedError(_driveConnectionError!),
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _initializeGoogleDrive,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Connecting to Google Drive...',
              style:
              TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
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
            _buildConnectionStatus(),
            Expanded(
              child: _images.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No images selected.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the + button to add images',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : GridView.builder(
                itemCount: _images.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final imageData = _images[index];
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showImageDetails(imageData),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: kIsWeb
                                ? Image.network(
                              imageData.localPath,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.error),
                                );
                              },
                            )
                                : Image.file(
                              File(imageData.localPath),
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.error),
                                );
                              },
                            ),
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
                            imageData.driveFileId != null
                                ? Icons.cloud_done
                                : Icons.cloud_off,
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
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child:
                            const Icon(Icons.close, size: 16, color: Colors.white),
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

  Map<String, dynamic> toMap() => {
    'localPath': localPath,
    'driveFileId': driveFileId,
    'fileName': fileName,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  String toJson() => json.encode(toMap());

  static ImageData fromJson(String jsonStr) {
    final map = json.decode(jsonStr);
    return ImageData(
      localPath: map['localPath'],
      driveFileId: map['driveFileId'],
      fileName: map['fileName'],
      uploadedAt: DateTime.parse(map['uploadedAt']),
    );
  }
}