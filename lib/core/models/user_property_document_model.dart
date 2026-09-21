import 'package:equatable/equatable.dart';

class UserPropertyDocumentSubmissionModel extends Equatable {
  final String? id;
  final String fileUrl;
  final String fileName;
  final String fileType;
  final DateTime? uploadedAt;

  const UserPropertyDocumentSubmissionModel({
    this.id,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    this.uploadedAt,
  });

  bool get isPdf => fileType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');
  bool get isImage => fileType.startsWith('image/');

  factory UserPropertyDocumentSubmissionModel.fromJson(Map<String, dynamic> json) {
    return UserPropertyDocumentSubmissionModel(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      fileUrl: json['fileUrl'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileType: json['fileType'] as String? ?? '',
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.tryParse(json['uploadedAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [id, fileUrl, fileName, fileType, uploadedAt];
}

class UserPropertyDocumentItemModel extends Equatable {
  final String requirementId;
  final String requirementName;
  final String documentType;
  final UserPropertyDocumentSubmissionModel? submission;

  const UserPropertyDocumentItemModel({
    required this.requirementId,
    required this.requirementName,
    required this.documentType,
    this.submission,
  });

  bool get isUploaded => submission != null && submission!.fileUrl.isNotEmpty;
  bool get isPdf => documentType == 'pdf';
  bool get isImage => documentType == 'image';

  factory UserPropertyDocumentItemModel.fromJson(Map<String, dynamic> json) {
    final submissionJson = json['submission'];
    return UserPropertyDocumentItemModel(
      requirementId: json['requirementId']?.toString() ?? '',
      requirementName: json['requirementName'] as String? ?? '',
      documentType: json['documentType'] as String? ?? 'image',
      submission: submissionJson != null
          ? UserPropertyDocumentSubmissionModel.fromJson(
              submissionJson as Map<String, dynamic>,
            )
          : null,
    );
  }

  @override
  List<Object?> get props =>
      [requirementId, requirementName, documentType, submission];
}
