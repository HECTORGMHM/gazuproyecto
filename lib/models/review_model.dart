import 'package:cloud_firestore/cloud_firestore.dart';

enum ReviewTargetType { business, staff }

extension ReviewTargetTypeX on ReviewTargetType {
  String get value {
    switch (this) {
      case ReviewTargetType.business:
        return 'business';
      case ReviewTargetType.staff:
        return 'staff';
    }
  }

  static ReviewTargetType fromString(String? value) {
    switch (value) {
      case 'staff':
        return ReviewTargetType.staff;
      default:
        return ReviewTargetType.business;
    }
  }
}

class GazuReviewResponse {
  final String responderId;
  final String responderType;
  final String message;
  final DateTime respondedAt;

  const GazuReviewResponse({
    required this.responderId,
    required this.responderType,
    required this.message,
    required this.respondedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'responderId': responderId,
      'responderType': responderType,
      'message': message,
      'respondedAt': Timestamp.fromDate(respondedAt),
    };
  }

  factory GazuReviewResponse.fromMap(Map<String, dynamic> map) {
    return GazuReviewResponse(
      responderId: map['responderId'] as String? ?? '',
      responderType: map['responderType'] as String? ?? '',
      message: map['message'] as String? ?? '',
      respondedAt:
          (map['respondedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class GazuReview {
  final String? id;
  final String appointmentId;
  final String authorId;
  final ReviewTargetType targetType;
  final String targetId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final GazuReviewResponse? response;
  final bool flaggedOffensive;
  final bool flaggedCoordinatedAttack;

  const GazuReview({
    this.id,
    required this.appointmentId,
    required this.authorId,
    required this.targetType,
    required this.targetId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.response,
    this.flaggedOffensive = false,
    this.flaggedCoordinatedAttack = false,
  });

  static String uniqueId({
    required String appointmentId,
    required String authorId,
  }) {
    return '${appointmentId}_$authorId';
  }

  bool get isNegative => rating <= 2;

  Map<String, dynamic> toFirestore() {
    return {
      'appointmentId': appointmentId,
      'authorId': authorId,
      'targetType': targetType.value,
      'targetId': targetId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'flaggedOffensive': flaggedOffensive,
      'flaggedCoordinatedAttack': flaggedCoordinatedAttack,
      if (response != null) 'response': response!.toFirestore(),
    };
  }

  factory GazuReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawResponse = data['response'] as Map<String, dynamic>?;
    return GazuReview(
      id: doc.id,
      appointmentId: data['appointmentId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      targetType: ReviewTargetTypeX.fromString(data['targetType'] as String?),
      targetId: data['targetId'] as String? ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      flaggedOffensive: data['flaggedOffensive'] as bool? ?? false,
      flaggedCoordinatedAttack:
          data['flaggedCoordinatedAttack'] as bool? ?? false,
      response: rawResponse != null ? GazuReviewResponse.fromMap(rawResponse) : null,
    );
  }

  GazuReview copyWith({
    int? rating,
    String? comment,
    DateTime? updatedAt,
    GazuReviewResponse? response,
    bool? flaggedOffensive,
    bool? flaggedCoordinatedAttack,
  }) {
    return GazuReview(
      id: id,
      appointmentId: appointmentId,
      authorId: authorId,
      targetType: targetType,
      targetId: targetId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      response: response ?? this.response,
      flaggedOffensive: flaggedOffensive ?? this.flaggedOffensive,
      flaggedCoordinatedAttack:
          flaggedCoordinatedAttack ?? this.flaggedCoordinatedAttack,
    );
  }
}
