// screens/library_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mooh/UI/profile_screen.dart';
import 'package:provider/provider.dart';
import '../Models/library_viewmodel.dart';
import '../models/image_model.dart';
import 'login_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late LibraryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = LibraryViewModel();
    _viewModel.initialize();
    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      // Handle UI updates based on ViewModel state changes
      if (_viewModel.driveStatus == DriveConnectionStatus.connected) {
        _showSuccessSnackBar('✅ Google Drive connected successfully!');
      } else if (_viewModel.driveStatus == DriveConnectionStatus.failed) {
        _showErrorSnackBar(
          '❌ Failed to connect to Google Drive: ${_viewModel.getSimplifiedDriveError()}',
        );
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _viewModel.retryDriveConnection,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _viewModel.logout();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  void _showImageDetails(ImageModel imageData) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(imageData.fileName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Uploaded: ${imageData.uploadedAt.toString()}'),
                const SizedBox(height: 8),
                Text(
                  'Status: ${imageData.isSyncedToDrive ? 'Synced to Google Drive' : 'Local only'}',
                ),
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
    return Consumer<LibraryViewModel>(
      builder: (context, viewModel, child) {
        switch (viewModel.driveStatus) {
          case DriveConnectionStatus.connected:
            return _buildStatusContainer(
              color: Colors.green,
              icon: Icons.cloud_done,
              title: 'Connected to Google Drive',
            );

          case DriveConnectionStatus.failed:
            return _buildStatusContainer(
              color: Colors.red,
              icon: Icons.cloud_off,
              title: 'Drive connection failed',
              subtitle: viewModel.getSimplifiedDriveError(),
              action: TextButton(
                onPressed: viewModel.retryDriveConnection,
                child: const Text('Retry'),
              ),
            );

          case DriveConnectionStatus.connecting:
            return _buildStatusContainer(
              color: Colors.orange,
              icon: null,
              title: 'Connecting to Google Drive...',
              isLoading: true,
            );
        }
      },
    );
  }

  Widget _buildStatusContainer({
    required Color color,
    IconData? icon,
    required String title,
    String? subtitle,
    Widget? action,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return Consumer<LibraryViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.images.isEmpty) {
          return const Center(
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
          );
        }

        return GridView.builder(
          itemCount: viewModel.images.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final imageData = viewModel.images[index];
            return _buildImageTile(imageData, index);
          },
        );
      },
    );
  }

  Widget _buildImageTile(ImageModel imageData, int index) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showImageDetails(imageData),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child:
                  kIsWeb
                      ? Image.network(
                        imageData.localPath,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                _buildErrorContainer(),
                      )
                      : Image.file(
                        File(imageData.localPath),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                _buildErrorContainer(),
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
              color:
                  imageData.isSyncedToDrive
                      ? Colors.green.withOpacity(0.8)
                      : Colors.orange.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              imageData.isSyncedToDrive ? Icons.cloud_done : Icons.cloud_off,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: () => _viewModel.deleteImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContainer() {
    return Container(color: Colors.grey[200], child: const Icon(Icons.error));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5F5),
          centerTitle: true,
          title: IconButton(
            icon: SvgPicture.asset("assets/images/Logo-MOOH2.svg", height: 40),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
            Consumer<LibraryViewModel>(
              builder: (context, viewModel, child) {
                return IconButton(
                  icon:
                      viewModel.isUploading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.add_photo_alternate),
                  tooltip: 'Pick Images',
                  onPressed:
                      viewModel.isUploading ? null : viewModel.pickImages,
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              _buildConnectionStatus(),
              Expanded(child: _buildImageGrid()),
            ],
          ),
        ),
      ),
    );
  }
}
