import 'package:classforge/features/ai_tutor_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  // Sample Q&A data
  List<Map<String, dynamic>> _questions = [];

  // User streaks (in real app, this would be stored in backend)
  final Map<String, int> _userStreaks = {};

  @override
  void initState() {
    super.initState();
    _loadSampleQuestions();
  }

  void _loadSampleQuestions() {
    // Start with a fresh page for students
    _questions = [];
  }

  void _addQuestion(dynamic user) {
    if (_questionController.text.trim().isEmpty) return;

    setState(() {
      _questions.insert(0, {
        'id': DateTime.now().toString(),
        'question': _questionController.text.trim(),
        'askedBy': user?.fullName ?? 'Student',
        'askedByEmail': user?.email ?? '',
        'level': user?.level ?? 1,
        'askedAt': DateTime.now(),
        'answers': [],
        'isResolved': false,
      });
      _questionController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Question posted successfully!')),
    );
  }

  void _addAnswer(String questionId, String answer, dynamic user) {
    setState(() {
      final questionIndex = _questions.indexWhere((q) => q['id'] == questionId);
      if (questionIndex != -1) {
        _questions[questionIndex]['answers'].add({
          'answer': answer,
          'answeredBy': user?.fullName ?? 'Student',
          'answeredByEmail': user?.email ?? '',
          'answeredAt': DateTime.now(),
          'isAccepted': false,
          'streakGiven': false,
        });
      }
    });
  }

  void _acceptAnswer(String questionId, int answerIndex) {
    setState(() {
      final questionIndex = _questions.indexWhere((q) => q['id'] == questionId);
      if (questionIndex != -1) {
        // Mark question as resolved
        _questions[questionIndex]['isResolved'] = true;
        final List answers = _questions[questionIndex]['answers'];

        for (int i = 0; i < answers.length; i++) {
          final answer = answers[i];
          final answererEmail = answer['answeredByEmail'];

          if (i == answerIndex) {
            // Correct answer: +1 streak
            answer['isAccepted'] = true;
            _userStreaks[answererEmail] =
                (_userStreaks[answererEmail] ?? 0) + 1;
          } else {
            // Not correct: -1 streak
            answer['isAccepted'] = false;
            _userStreaks[answererEmail] =
                (_userStreaks[answererEmail] ?? 0) - 1;
          }
          answer['streakGiven'] = true;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Streaks updated based on correctness!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showAddAnswerDialog(String questionId, dynamic user) {
    final answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Your Answer'),
        content: TextField(
          controller: answerController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write your answer here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (answerController.text.trim().isNotEmpty) {
                _addAnswer(questionId, answerController.text.trim(), user);
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Answer posted!')));
              }
            },
            child: const Text('Post Answer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final isStudent = user?.role.toLowerCase() == 'student';
    final tabCount = isStudent ? 3 : 2;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isDesktop ? 30 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Discover & Learn",
                      style: TextStyle(
                        fontSize: isDesktop ? 36 : 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Level ${user?.level} • ${user?.role.toUpperCase()}",
                      style: TextStyle(
                        color: const Color(0xFF00F5FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TabBar(
                  labelColor: const Color(0xFF00F5FF),
                  unselectedLabelColor: isDarkMode
                      ? Colors.white70
                      : Colors.black54,
                  indicator: BoxDecoration(
                    color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    const Tab(text: "AI Quiz", icon: Icon(Icons.auto_awesome)),
                    if (isStudent)
                      const Tab(
                        text: "Q&A Forum",
                        icon: Icon(Icons.question_answer),
                      ),
                    const Tab(text: "Help Guide", icon: Icon(Icons.help)),
                  ],
                ),
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  children: [
                    // AI Quiz Tab
                    _buildAIQuizTab(isDarkMode, isDesktop, user),

                    // Q&A Forum Tab
                    if (isStudent) _buildQandATab(isDarkMode, isDesktop, user),

                    // Help Guide Tab
                    _buildHelpGuideTab(isDarkMode, isDesktop),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIQuizTab(bool isDarkMode, bool isDesktop, user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 30 : 20),
      child: Column(
        children: [
          // Streak Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 45,
                  color: Colors.white,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_userStreaks[user?.email] ?? 0} Day Streak 🔥",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        "Keep answering questions to earn streaks!",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // AI Quiz Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFFEFFED),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF00F5FF),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "AI Quiz Generator",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Test your knowledge on any topic",
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _topicController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "Enter topic (e.g. Flutter Navigation)",
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AITutorScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Open AI Tutor",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildQandATab(bool isDarkMode, bool isDesktop, dynamic user) {
    final now = DateTime.now();
    final filteredQuestions = _questions.where((q) {
      final askedAt = q['askedAt'] as DateTime;
      return q['level'] == user?.level &&
          askedAt.year == now.year &&
          askedAt.month == now.month &&
          askedAt.day == now.day;
    }).toList();

    return Column(
      children: [
        // Ask Question Input
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFFEFFED),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "Ask a question...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00F5FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _addQuestion(user),
                  icon: const Icon(Icons.send, color: Colors.black),
                ),
              ),
            ],
          ),
        ),

        // Questions List
        Expanded(
          child: filteredQuestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.question_answer,
                        size: 80,
                        color: isDarkMode ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No questions yet. Be the first to ask!",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredQuestions.length,
                  itemBuilder: (context, index) {
                    final question = filteredQuestions[index];
                    return _buildQuestionCard(question, isDarkMode, user);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    Map<String, dynamic> question,
    bool isDarkMode,
    dynamic user,
  ) {
    final isResolved = question['isResolved'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? (isResolved
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.1))
            : (isResolved ? Colors.green.shade50 : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isResolved
              ? Colors.green
              : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.shade200),
          width: isResolved ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isResolved ? Colors.green : const Color(0xFF00F5FF),
          child: Icon(
            isResolved ? Icons.check : Icons.help,
            color: Colors.black,
            size: 20,
          ),
        ),
        title: Text(
          question['question'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
            decoration: isResolved ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Asked by ${question['askedBy']} • ${_getTimeAgo(question['askedAt'])}",
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
            if (question['answers'].isNotEmpty)
              Text(
                "${question['answers'].length} answer(s)",
                style: TextStyle(fontSize: 12, color: const Color(0xFF00F5FF)),
              ),
          ],
        ),
        trailing: isResolved
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Answers Section
                const Text(
                  "Answers:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ...question['answers'].asMap().entries.map((entry) {
                  final answer = entry.value;
                  final answerIndex = entry.key;
                  return _buildAnswerCard(
                    answer,
                    answerIndex,
                    question['id'],
                    question['askedByEmail'],
                    isResolved,
                    isDarkMode,
                    user,
                  );
                }).toList(),

                const SizedBox(height: 16),

                // Add Answer Button (if not resolved)
                if (!isResolved)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showAddAnswerDialog(question['id'], user),
                      icon: const Icon(Icons.add_comment),
                      label: const Text("Add Answer"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00F5FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Widget _buildAnswerCard(
    Map<String, dynamic> answer,
    int answerIndex,
    String questionId,
    String questionAskedBy,
    bool isResolved,
    bool isDarkMode,
    dynamic user,
  ) {
    final isAccepted = answer['isAccepted'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAccepted
            ? Colors.green.withValues(alpha: 0.1)
            : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccepted ? Colors.green : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      answer['answeredBy'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      _getTimeAgo(answer['answeredAt']),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAccepted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "✓ ACCEPTED",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            answer['answer'],
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),

          // Accept Answer Button (only for question asker)
          if (!isResolved && !isAccepted && questionAskedBy == user?.email)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _acceptAnswer(questionId, answerIndex),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text("Accept as Correct"),
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHelpGuideTab(bool isDarkMode, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 30 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00F5FF), const Color(0xFF00D4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(Icons.school, size: 60, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  "Welcome to ClassForge!",
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your all-in-one learning platform",
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Getting Started Section
          _buildHelpSection(
            title: "🚀 Getting Started",
            icon: Icons.rocket_launch,
            color: Colors.orange,
            items: [
              "Complete your profile with your level and interests",
              "Join live classes from your dashboard",
              "Participate in AI-generated quizzes to test knowledge",
              "Ask questions in the Q&A Forum",
              "Help others and earn streak points!",
            ],
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 20),

          // Q&A Forum Guide
          _buildHelpSection(
            title: "💬 Q&A Forum Guide",
            icon: Icons.question_answer,
            color: const Color(0xFF00F5FF),
            items: [
              "📝 ASK: Post any school-related question",
              "💡 ANSWER: Help your peers by answering questions",
              "✅ ACCEPT: Question asker can accept correct answers",
              "🏆 EARN STREAKS: Get points when your answer is accepted",
              "🔍 SEARCH: Browse through resolved and open questions",
            ],
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 20),

          // Features Overview
          _buildHelpSection(
            title: "✨ Key Features",
            icon: Icons.star,
            color: Colors.purple,
            items: [
              "🎥 Live Classes: Join real-time lectures",
              "📚 Assignments: Submit and track your work",
              "📢 Notices: Stay updated with announcements",
              "🤖 AI Quiz: Generate custom quizzes on any topic",
              "💬 Chat: Connect with peers and lecturers",
              "📊 Progress: Track your learning journey",
            ],
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 20),

          // Tips & Tricks
          _buildHelpSection(
            title: "💡 Pro Tips",
            icon: Icons.tips_and_updates,
            color: Colors.teal,
            items: [
              "🎯 Set daily learning goals",
              "📅 Check notices regularly for updates",
              "🏆 Aim for long streaks in Q&A",
              "🤝 Collaborate with classmates",
              "📱 Use on any device - fully responsive!",
            ],
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 20),

          // Illustration Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIllustrationItem(Icons.quiz, "AI Quiz", isDarkMode),
                    _buildIllustrationItem(
                      Icons.question_answer,
                      "Q&A",
                      isDarkMode,
                    ),
                    _buildIllustrationItem(
                      Icons.video_call,
                      "Live",
                      isDarkMode,
                    ),
                    _buildIllustrationItem(
                      Icons.assignment,
                      "Work",
                      isDarkMode,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Need more help? Contact your lecturer or rodenybowa11.com",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHelpSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustrationItem(IconData icon, String label, bool isDarkMode) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF00F5FF), size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black87,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
