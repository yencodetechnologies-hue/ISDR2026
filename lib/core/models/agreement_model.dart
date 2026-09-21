import 'package:equatable/equatable.dart';

class AgreementModel extends Equatable {
  final String id;
  final String conversationId;
  final String uploadedBy;
  final String uploadedByType;
  final String? uploadedByName;
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String fileType;
  final int version;
  final bool isActive;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AgreementModel({
    required this.id,
    required this.conversationId,
    required this.uploadedBy,
    required this.uploadedByType,
    this.uploadedByName,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.fileType,
    required this.version,
    required this.isActive,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AgreementModel.fromJson(Map<String, dynamic> json) {
    return AgreementModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      uploadedBy: json['uploadedBy']?.toString() ?? '',
      uploadedByType: json['uploadedByType']?.toString() ?? 'user',
      uploadedByName: json['uploadedByName']?.toString(),
      fileName: json['fileName']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? '',
      fileSize: json['fileSize'] is int
          ? json['fileSize']
          : int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0,
      fileType: json['fileType']?.toString() ?? 'application/octet-stream',
      version: json['version'] is int
          ? json['version']
          : int.tryParse(json['version']?.toString() ?? '1') ?? 1,
      isActive: json['isActive'] == true,
      description: json['description']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversationId': conversationId,
      'uploadedBy': uploadedBy,
      'uploadedByType': uploadedByType,
      'uploadedByName': uploadedByName,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'fileType': fileType,
      'version': version,
      'isActive': isActive,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Get formatted file size (e.g., "1.5 MB")
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Check if file is an image
  bool get isImage {
    return fileType.startsWith('image/');
  }

  /// Check if file is a PDF
  bool get isPdf {
    return fileType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');
  }

  /// Get file extension
  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  AgreementModel copyWith({
    String? id,
    String? conversationId,
    String? uploadedBy,
    String? uploadedByType,
    String? uploadedByName,
    String? fileName,
    String? fileUrl,
    int? fileSize,
    String? fileType,
    int? version,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgreementModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedByType: uploadedByType ?? this.uploadedByType,
      uploadedByName: uploadedByName ?? this.uploadedByName,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        uploadedBy,
        uploadedByType,
        uploadedByName,
        fileName,
        fileUrl,
        fileSize,
        fileType,
        version,
        isActive,
        description,
        createdAt,
        updatedAt,
      ];
}
