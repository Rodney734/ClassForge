import 'package:classforge/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/ai_tutor_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  bool _isLoading = false;
  bool _isQuizMode = false;
  bool _showScrollToBottom = false;
  int _lastMessageCount = 0;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  late AnimationController _typingAnimationController;

  final List<String> _suggestedTopics = [
    'Explain Flutter State Management',
    'Quiz me on SQL Joins',
    'Teach me about APIs',
    'Practice questions on Python',
    'What is recursion?',
    'Explain databases to me',
  ];

  final List<String> _quizTopics = ['Flutter', 'SQL', 'Python', 'JavaScript'];

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _scrollController.addListener(_handleScroll);
    _initSpeech();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (mounted) setState(() {});
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (force || maxScroll > 0) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final shouldShow = position.maxScrollExtent - position.pixels > 120;
    if (shouldShow != _showScrollToBottom && mounted) {
      setState(() => _showScrollToBottom = shouldShow);
    }
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
    } on AiCallableException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } on FirebaseFunctionsException catch (e) {
      final messageText =
          e.message ?? 'The AI request failed. Please try again.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageText),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to contact the AI service right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startQuizMode(String topic) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.role == 'lecturer') return;

    setState(() {
      _isQuizMode = true;
    });
    await _sendMessage('Quiz me on $topic');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quiz mode started: $topic'),
        backgroundColor: Colors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleMode() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.role == 'lecturer') return;

    setState(() {
      _isQuizMode = !_isQuizMode;
      _messageController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isQuizMode ? ' Switched to Quiz Mode' : ' Switched to Chat Mode',
        ),
        backgroundColor: _isQuizMode ? Colors.purple : const Color(0xFF00F5FF),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startListening() async {
    if (!_speechEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available on this device.'),
        ),
      );
      return;
    }

    if (await Permission.microphone.request().isGranted) {
      if (!mounted) return;
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _messageController.text = result.recognizedWords;
              if (result.finalResult) {
                _isListening = false;
              }
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
    }
  }

  void _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    }
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

    final canUseQuiz = user.role != 'lecturer';
    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF101418)
          : const Color(0xFFF5F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Glass AppBar
            _buildGlassAppBar(isDarkMode, canUseQuiz),

            // Mode Indicator
            if (canUseQuiz && _isQuizMode)
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
              child: Stack(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _aiService.getChatStream(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return canUseQuiz && _isQuizMode
                            ? _buildQuizWelcome(isDarkMode)
                            : _buildWelcomeMessage(isDarkMode);
                      }

                      final messages = snapshot.data!.docs;
                      final messageCount = messages.length;

                      if (messageCount != _lastMessageCount) {
                        _lastMessageCount = messageCount;
                        _scrollToBottom(force: true);
                      }

                      return ListView.builder(
                        scrollCacheExtent: ScrollCacheExtent.pixels(200),
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
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
                  if (_showScrollToBottom)
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: Material(
                        color: isDarkMode
                            ? const Color(0xFF263238)
                            : Colors.white,
                        elevation: 6,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Scroll to latest message',
                          onPressed: () => _scrollToBottom(force: true),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Quiz Topics (when in quiz mode)
            if (canUseQuiz && _isQuizMode)
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
                        backgroundColor: Colors.purple.withValues(alpha: 0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Input Bar
            _buildInputBar(isDarkMode, canUseQuiz),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00F5FF), Color(0xFF7B2FF7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _buildTypingDot(0, isDarkMode),
                const SizedBox(width: 4),
                _buildTypingDot(1, isDarkMode),
                const SizedBox(width: 4),
                _buildTypingDot(2, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int delay, bool isDarkMode) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final value = ((_typingAnimationController.value * 3) + delay) % 3;
        final opacity = value == 0 ? 1.0 : 0.35;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white : const Color(0xFF00F5FF),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(bool isDarkMode, bool canUseQuiz) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Row(
        children: [
          if (canUseQuiz)
            IconButton(
              onPressed: _toggleMode,
              icon: Icon(
                _isQuizMode ? Icons.chat_bubble_outline : Icons.quiz_outlined,
                color: _isQuizMode ? Colors.purple : const Color(0xFF00F5FF),
              ),
            ),
          if (_speechEnabled)
            IconButton(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : Colors.grey,
              ),
            ),
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: _isQuizMode
                    ? 'Ask a quiz question...'
                    : 'Ask your tutor...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : () => _sendMessage(),
            icon: const Icon(Icons.send_rounded, color: Color(0xFF00F5FF)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDate = DateTime(date.year, date.month, date.day);

    if (currentDate == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (currentDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildGlassAppBar(bool isDarkMode, bool canUseQuiz) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.12),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.15,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                color: (isDarkMode ? Colors.white : Colors.black).withValues(
                  alpha: 0.1,
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
                  canUseQuiz && _isQuizMode ? 'AI Quiz Tutor' : 'AI Tutor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  canUseQuiz && _isQuizMode
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
              color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
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
                    color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
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
                  backgroundColor: const Color(
                    0xFF00F5FF,
                  ).withValues(alpha: 0.1),
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
                    color: Colors.purple.withValues(alpha: 0.3),
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
                  backgroundColor: Colors.purple.withValues(alpha: 0.1),
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
    return Container(
      margin: EdgeInsets.only(
        bottom: isUser ? 16 : 24,
        left: isUser ? 0 : 0,
        right: isUser ? 0 : 0,
      ),
      child: isUser
          ? _buildUserMessage(text, isDarkMode, timestamp)
          : _buildAIMessage(text, isDarkMode, timestamp),
    );
  }

  /// User message — compact, right-aligned bubble with a subtle glow.
  Widget _buildUserMessage(String text, bool isDarkMode, DateTime? timestamp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (timestamp != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Text(
              _formatTime(timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.white38 : Colors.black38,
                letterSpacing: 0.3,
              ),
            ),
          ),
      ],
    );
  }

  /// AI message — minimal, full-width layout with a futuristic left accent.
  Widget _buildAIMessage(String text, bool isDarkMode, DateTime? timestamp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Futuristic AI avatar / accent bar
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 3,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF00F5FF), Color(0xFF7B2FF7)],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F5FF).withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI label
                  Row(
                    children: [
                      Text(
                        'AI TUTOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: isDarkMode
                              ? const Color(0xFF00F5FF).withValues(alpha: 0.8)
                              : const Color(0xFF0099CC),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F5FF).withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Markdown content — no bubble, just clean text
                  MarkdownBody(
                    data: text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                      h1: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      h2: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      h3: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      code: TextStyle(
                        backgroundColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        fontFamily: 'monospace',
                        fontSize: 13.5,
                        color: isDarkMode
                            ? const Color(0xFF00F5FF)
                            : const Color(0xFF007799),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.4)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      blockquote: TextStyle(
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                        fontStyle: FontStyle.italic,
                        fontSize: 14.5,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        border: Border(
                          left: BorderSide(
                            color: const Color(
                              0xFF00F5FF,
                            ).withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                      ),
                      listBullet: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 15,
                      ),
                      strong: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      em: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                      a: const TextStyle(
                        color: Color(0xFF00F5FF),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF00F5FF),
                      ),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.copy_rounded,
                        isActive: false,
                        isDarkMode: isDarkMode,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      if (timestamp != null)
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode ? Colors.white38 : Colors.black38,
                            letterSpacing: 0.3,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Small futuristic action button used in AI message footer.
  Widget _buildActionButton({
    required IconData icon,
    required bool isActive,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00F5FF).withValues(alpha: 0.15)
              : (isDarkMode ? Colors.white : Colors.black).withValues(
                  alpha: 0.05,
                ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00F5FF).withValues(alpha: 0.5)
                : (isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.08,
                  ),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive
              ? const Color(0xFF00F5FF)
              : (isDarkMode ? Colors.white54 : Colors.black45),
        ),
      ),
    );
  }
}
