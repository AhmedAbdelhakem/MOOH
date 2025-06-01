// models/image_model.dart
import 'dart:convert';

class ImageModel {
  final String localPath;
  final String? driveFileId;
  final String fileName;
  final DateTime uploadedAt;

  ImageModel({
    required this.localPath,
    this.driveFileId,
    required this.fileName,
    required this.uploadedAt,
  });

  bool get isSyncedToDrive => driveFileId != null;

  Map<String, dynamic> toMap() => {
    'localPath': localPath,
    'driveFileId': driveFileId,
    'fileName': fileName,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  String toJson() => json.encode(toMap());

  factory ImageModel.fromJson(String jsonStr) {
    final map = json.decode(jsonStr);
    return ImageModel(
      localPath: map['localPath'],
      driveFileId: map['driveFileId'],
      fileName: map['fileName'],
      uploadedAt: DateTime.parse(map['uploadedAt']),
    );
  }

  ImageModel copyWith({
    String? localPath,
    String? driveFileId,
    String? fileName,
    DateTime? uploadedAt,
  }) {
    return ImageModel(
      localPath: localPath ?? this.localPath,
      driveFileId: driveFileId ?? this.driveFileId,
      fileName: fileName ?? this.fileName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}