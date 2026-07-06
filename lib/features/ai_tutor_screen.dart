import 'package:classforge/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/ai_tutor_service.dart';

class AITutorScreen extends StatefulWidget {
  const AITutorScreen({super.key});

  @override
  State<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends State<AITutorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AITutorService _aiService = AITutorService();
  bool _isLoading = false;
  bool _isQuizMode = false;

  late AnimationController _typingAnimationController;

  final List<String> _suggestedTopics = [
    'Explain Flutter State Management',
    'Quiz me on SQL Joins',
    'Teach me about APIs',
    'Practice questions on Python',
    'What is recursion?',
    'Explain databases to me',
  ];

  final List<String> _quizTopics = [
    'Flutter',
    'SQL',
    'Python',
    'JavaScript',
    'APIs',
    'Database Design',
    'Networking',
    'Cybersecurity',
  ];

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? messageText]) async {
    final message = messageText ?? _messageController.text.trim();
    if (message.isEmpty) return;

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use AI Tutor')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    if (messageText == null) {
      _messageController.clear();
    }

    try {
      await _aiService.sendMessage(message: message, userId: user.uid);
      _scrollToBottom();
    } catch (e) {
      // Error is handled by the service
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startQuizMode(String topic) async {
    setState(() {
      _isQuizMode = true;
    });
    await _sendMessage('Quiz me on $topic');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 Quiz mode started: $topic'),
        backgroundColor: Colors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isQuizMode = !_isQuizMode;
      _messageController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isQuizMode ? '🎯 Switched to Quiz Mode' : '💬 Switched to Chat Mode',
        ),
        backgroundColor: _isQuizMode ? Colors.purple : const Color(0xFF00F5FF),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to use the AI Tutor.")),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                  : [const Color(0xFFF0F2F5), Colors.white],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Glass AppBar
                _buildGlassAppBar(isDarkMode),

                // Mode Indicator
                if (_isQuizMode)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.deepPurple],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.quiz, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Quiz Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Messages
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _aiService.getChatStream(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _isQuizMode
                            ? _buildQuizWelcome(isDarkMode)
                            : _buildWelcomeMessage(isDarkMode);
                      }

                      _scrollToBottom();
                      final messages = snapshot.data!.docs;

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isLoading && index == messages.length) {
                            return _buildTypingIndicator(isDarkMode);
                          }
                          final doc = messages[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildMessageBubble(
                            text: data['text'] ?? '',
                            isUser: data['isUser'] ?? false,
                            isDarkMode: isDarkMode,
                            timestamp: (data['timestamp'] as Timestamp?)
                                ?.toDate(),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Quiz Topics (when in quiz mode)
                if (_isQuizMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quizTopics.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              _quizTopics[index],
                              style: const TextStyle(color: Colors.white),
                            ),
                            onPressed: () => _startQuizMode(_quizTopics[index]),
                            backgroundColor: Colors.purple.withOpacity(0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Input Bar
                _buildInputBar(isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassAppBar(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.12),
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.white : Colors.black).withOpacity(
                  0.1,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isQuizMode ? 'AI Quiz Tutor' : 'AI Tutor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _isQuizMode
                      ? '📝 Answer questions to learn'
                      : 'Ask anything about your studies',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00F5FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Mistral",
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF00F5FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage(bool isDarkMode) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F5FF).withOpacity(0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 50,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Welcome to ClassForge AI!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Ask me anything about your studies.\nI'm here to help you learn!",
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestedTopics.map((topic) {
                return ActionChip(
                  label: Text(
                    topic,
                    style: const TextStyle(
                      color: Color(0xFF00F5FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _sendMessage(topic),
                  backgroundColor: const Color(0xFF00F5FF).withOpacity(0.1),
                  side: const BorderSide(color: Color(0xFF00F5FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizWelcome(bool isDarkMode) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.deepPurple],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(Icons.quiz, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              "🎯 Quiz Mode",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Select a topic below or type one in the chat!\nTap the quiz button to switch back to chat.",
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _quizTopics.map((topic) {
                return ActionChip(
                  label: Text(
                    topic,
                    style: const TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _startQuizMode(topic),
                  backgroundColor: Colors.purple.withOpacity(0.1),
                  side: const BorderSide(color: Colors.purple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
    required bool isDarkMode,
    DateTime? timestamp,
  }) {
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final color = isUser
        ? const Color(0xFF00D4FF)
        : (isDarkMode ? Colors.grey[800]! : Colors.grey[100]!);
    final textColor = isUser
        ? Colors.black
        : (isDarkMode ? Colors.white : Colors.black87);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isUser
                    ? const Radius.circular(18)
                    : const Radius.circular(4),
                bottomRight: isUser
                    ? const Radius.circular(4)
                    : const Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                    code: TextStyle(
                      backgroundColor: Colors.black.withOpacity(0.2),
                      fontFamily: 'monospace',
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    blockquote: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                    strong: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isUser
                            ? Colors.black54
                            : (isDarkMode ? Colors.white54 : Colors.black54),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDarkMode) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return FadeTransition(
              opacity: _typingAnimationController.drive(
                Tween<double>(begin: 0.3, end: 1.0).chain(
                  CurveTween(
                    curve: Interval(
                      index * 0.2,
                      (index + 1) * 0.2 + 0.4,
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00F5FF),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mode Switch Button (Chat/Quiz)
          GestureDetector(
            onTap: _toggleMode,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isQuizMode
                    ? Colors.purple.withOpacity(0.2)
                    : const Color(0xFF00F5FF).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isQuizMode ? Icons.quiz : Icons.chat,
                color: _isQuizMode ? Colors.purple : const Color(0xFF00F5FF),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isLoading,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: _isQuizMode
                    ? 'Enter a topic to quiz on...'
                    : 'Ask a question...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.black38,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(null),
            ),
          ),
          GestureDetector(
            onTap: _isLoading ? null : () => _sendMessage(null),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: _isQuizMode
                    ? const LinearGradient(
                        colors: [Colors.purple, Colors.deepPurple],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                      ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _isQuizMode
                        ? Colors.purple.withOpacity(0.3)
                        : const Color(0xFF00F5FF).withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                _isLoading ? Icons.stop : Icons.send_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);

    if (date == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
