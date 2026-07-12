import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/forum_service.dart';
import 'package:glassmorphism/glassmorphism.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen>
    with SingleTickerProviderStateMixin {
  final ForumService _forumService = ForumService();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showAskDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.question_answer, color: Colors.redAccent),
            ),
            const SizedBox(width: 12),
            const Text("Ask a Question"),
          ],
        ),
        content: TextField(
          controller: _questionController,
          maxLines: 4,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "What's on your mind?",
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : Colors.grey[100],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _questionController.clear();
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = Provider.of<AuthService>(
                context,
                listen: false,
              ).currentUser;
              if (user != null && _questionController.text.isNotEmpty) {
                await _forumService.askQuestion(
                  text: _questionController.text,
                  user: user,
                );
                _questionController.clear();
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Post Question"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const NetworkImage(
              "https://images.pexels.com/photos/256468/pexels-photo-256468.jpeg?auto=compress&cs=tinysrgb&w=1600",
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.3),
              BlendMode.darken,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.9),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.95),
                    ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Glass AppBar
                _buildGlassAppBar(user, isDarkMode),

                // Questions List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _forumService.getQuestions(user?.level ?? 0),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 60,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Error loading questions",
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Please check your connection",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.redAccent,
                            ),
                          ),
                        );
                      }

                      final questions = snapshot.data!.docs;
                      if (questions.isEmpty) {
                        return _buildEmptyState(isDarkMode);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          final qDoc = questions[index];
                          final qData = qDoc.data() as Map<String, dynamic>;
                          return FadeTransition(
                            opacity: _animationController,
                            child: SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: Interval(
                                        index * 0.1,
                                        1.0,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                  ),
                              child: _buildQuestionCard(
                                qDoc.id,
                                qData,
                                user,
                                isDarkMode,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAskDialog,
        backgroundColor: Colors.redAccent,
        elevation: 8,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  Widget _buildGlassAppBar(user, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 80, // Adjusted height
        borderRadius: 30,
        blur: 20,
        linearGradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.12),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: 1,
        borderGradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.2),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.2),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Colors.redAccent,
                    Color.fromARGB(255, 206, 127, 127),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.forum, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Q&A Forum",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    "Ask questions, share knowledge",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.orange.shade700],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "🔥 ${user?.streak ?? 0}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.redAccent.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.question_answer,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Questions Yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to ask a question!",
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    String qId,
    Map<String, dynamic> data,
    user,
    bool isDarkMode,
  ) {
    bool isAsker = data['askerId'] == user?.uid;
    bool isResolved = data['isResolved'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 200, // Adjusted height, may need more if answers are long
        borderRadius: 24,
        blur: 20,
        linearGradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.08),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: 1,
        borderGradient: LinearGradient(
          colors: [
            isResolved
                ? Colors.green.withValues(alpha: 0.3)
                : (isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.2,
                  ),
            isResolved
                ? Colors.green.withValues(alpha: 0.3)
                : (isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.2,
                  ),
          ],
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isResolved
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isResolved ? Icons.check_circle : Icons.help_outline,
              color: isResolved ? Colors.green : Colors.redAccent,
              size: 24,
            ),
          ),
          title: Text(
            data['questionText'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black87,
              decoration: isResolved ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                "Asked by ${data['askerName']}",
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isResolved
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isResolved ? "✅ Resolved" : "❓ Open",
                  style: TextStyle(
                    fontSize: 10,
                    color: isResolved ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          children: [
            _buildAnswerList(qId, isAsker, user, isDarkMode),
            if (!isResolved)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _answerController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: "Write your answer...",
                            hintStyle: TextStyle(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.redAccent,
                              Color.fromARGB(255, 183, 105, 105),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () async {
                            if (_answerController.text.isNotEmpty &&
                                user != null) {
                              await _forumService.submitAnswer(
                                questionId: qId,
                                text: _answerController.text,
                                user: user,
                              );
                              _answerController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerList(String qId, bool isAsker, user, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _forumService.getAnswers(qId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final answers = snapshot.data!.docs;
        if (answers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                "No answers yet. Be the first to answer!",
                style: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: answers.length,
          itemBuilder: (context, index) {
            final aDoc = answers[index];
            final aData = aDoc.data() as Map<String, dynamic>;
            final status = aData['status'] ?? 'pending';

            Color? borderColor;
            if (status == 'correct') borderColor = Colors.green;
            if (status == 'incorrect') borderColor = Colors.red;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (isDarkMode ? Colors.white : Colors.black).withValues(
                      alpha: 0.05,
                    ),
                    (isDarkMode ? Colors.white : Colors.black).withValues(
                      alpha: 0.02,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: borderColor != null
                    ? Border.all(
                        color: borderColor.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.redAccent.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          (aData['answererName'] ?? 'A')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aData['answererName'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              _formatTime(
                                (aData['timestamp'] as Timestamp?)?.toDate(),
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDarkMode
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status != 'pending')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'correct'
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                status == 'correct'
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                size: 14,
                                color: status == 'correct'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status == 'correct' ? 'Correct' : 'Incorrect',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: status == 'correct'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    aData['answerText'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (isAsker && status == 'pending')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _forumService.evaluateAnswer(
                              questionId: qId,
                              answerId: aDoc.id,
                              answererId: aData['answererId'],
                              isCorrect: false,
                            ),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text("Incorrect"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _forumService.evaluateAnswer(
                              questionId: qId,
                              answerId: aDoc.id,
                              answererId: aData['answererId'],
                              isCorrect: true,
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text("Correct"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
