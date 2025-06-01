// repositories/image_repository.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/image_model.dart';

class ImageRepository {
  static const String _keyPrefix = 'saved_images_';

  Future<List<ImageModel>> getImages(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final imageDataJson = prefs.getStringList('$_keyPrefix$userId') ?? [];

    final List<ImageModel> existingImages = [];

    for (String jsonData in imageDataJson) {
      try {
        final imageData = ImageModel.fromJson(jsonData);
        // Check if file exists (skip for web)
        if (kIsWeb || await File(imageData.localPath).exists()) {
          existingImages.add(imageData);
        }
      } catch (e) {
        print('Error parsing image data: $e');
      }
    }

    return existingImages;
  }

  Future<void> saveImages(String userId, List<ImageModel> images) async {
    final prefs = await SharedPreferences.getInstance();
    final imageDataJson = images.map((img) => img.toJson()).toList();
    await prefs.setStringList('$_keyPrefix$userId', imageDataJson);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_user_id');
  }

  Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_user_id');
  }
}