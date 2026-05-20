import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'review_submission_screen.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.title,
  });

  final ReviewTargetType targetType;
  final String targetId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('openReviewSubmissionFab'),
        backgroundColor: const Color(AppColors.primaryOrange),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReviewSubmissionScreen()),
        ),
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Dejar reseña'),
      ),
      body: StreamBuilder<List<GazuReview>>(
        stream: firestoreService.reviewsForTargetStream(
          targetType: targetType,
          targetId: targetId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews = snapshot.data ?? [];
          if (reviews.isEmpty) {
            return const Center(
              child: Text(
                'Aún no hay reseñas.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final avg = reviews
                  .map((r) => r.rating)
                  .fold<int>(0, (a, b) => a + b) /
              reviews.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF2C2C2C),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(
                    '${avg.toStringAsFixed(1)} / 5.0',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${reviews.length} reseña(s)',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...reviews.map((review) => _ReviewCard(review: review)),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final GazuReview review;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${review.rating} ⭐',
                  style: const TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  review.createdAt.toIso8601String().split('T').first,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review.comment, style: const TextStyle(color: Colors.white)),
            if (review.flaggedOffensive || review.flaggedCoordinatedAttack) ...[
              const SizedBox(height: 8),
              const Text(
                '⚠️ En moderación',
                style:
                    TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 8),
            if (review.response != null)
              _ResponseBox(response: review.response!)
            else if (review.isNegative && review.id != null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: Key('respondToReviewButton_${review.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
                  onPressed: () => _showRespondDialog(context),
                  icon: const Icon(Icons.reply_outlined),
                  label: const Text('Responder reseña'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRespondDialog(BuildContext context) async {
    final controller = TextEditingController();
    try {
      final message = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Responder reseña'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Escribe una respuesta'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );

      if (message == null || message.isEmpty || review.id == null) return;
      if (!context.mounted) return;

      final authService = context.read<AuthService>();
      final uid = authService.currentUser?.uid;
      if (uid == null) return;

      final userRole = await _loadCurrentRole(context, uid);
      if (!context.mounted) return;

      await context.read<FirestoreService>().respondToReview(
            reviewId: review.id!,
            response: GazuReviewResponse(
              responderId: uid,
              responderType: responderTypeFromRole(userRole),
              message: message,
              respondedAt: DateTime.now(),
            ),
          );
    } finally {
      controller.dispose();
    }
  }

  Future<UserRole> _loadCurrentRole(BuildContext context, String uid) async {
    final user = await context.read<FirestoreService>().getUser(uid);
    return user?.role ?? UserRole.user;
  }
}

class _ResponseBox extends StatelessWidget {
  const _ResponseBox({required this.response});

  final GazuReviewResponse response;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Respuesta (${response.responderType})',
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(response.message, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
