import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<XFile> _images = [];

  @override
  void initState() {
    super.initState();
    _loadSavedImages();
  }

  Future<void> _loadSavedImages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> paths = prefs.getStringList('saved_images') ?? [];

    List<XFile> existingFiles = [];
    for (var path in paths) {
      if (kIsWeb) {
        // للويب، المسار هو URL مباشر
        existingFiles.add(XFile(path));
      } else {
        if (await File(path).exists()) {
          existingFiles.add(XFile(path));
        }
      }
    }

    setState(() {
      _images = existingFiles;
    });

    // حدّث SharedPreferences لتشمل الصور الموجودة فقط
    await prefs.setStringList('saved_images', existingFiles.map((e) => e.path).toList());
  }

  Future<void> _saveImagesToPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> paths = _images.map((img) => img.path).toList();
    await prefs.setStringList('saved_images', paths);
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      // تأكد أن الصور الجديدة ليست مكررة
      List<XFile> newFiles = [];
      for (var file in pickedFiles) {
        bool exists = _images.any((img) => img.path == file.path);
        if (!exists) {
          newFiles.add(file);
        }
      }

      if (newFiles.isNotEmpty) {
        setState(() {
          _images.addAll(newFiles);
        });

        await _saveImagesToPrefs();
      }
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  void _deleteImage(int index) async {
    setState(() {
      _images.removeAt(index);
    });
    await _saveImagesToPrefs();
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
            icon: const Icon(Icons.add_photo_alternate),
            tooltip: 'Pick Images',
            onPressed: _pickImages,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
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
            final XFile file = _images[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(
                    file.path,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                      : Image.file(
                    File(file.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
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
    );
  }
}