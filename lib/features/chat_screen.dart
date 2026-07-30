import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Replaced external emoji picker with a lightweight in-app grid
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  bool _isUploading = false;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  StreamSubscription? _typingSubscription;

  // Typing indicator
  Timer? _typingTimer;
  bool _isTyping = false;
  String _typingUser = '';
  final Map<String, Timer> _typingTimers = {};

  // Reply to message
  Map<String, dynamic>? _replyingTo;
  List<Map<String, dynamic>> _localMessages = [];

  // Reactions
  final List<String> _availableReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animationController.forward();
    _setupTypingListeners();
    _loadLocalMessages();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _sendTypingStatus(true);
        _scrollToBottom();
      } else {
        _sendTypingStatus(false);
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _typingSubscription?.cancel();
    _typingTimers.forEach((key, timer) => timer.cancel());
    _typingTimers.clear();
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setupTypingListeners() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    // Use course-based typing status if available, otherwise fall back to level-based
    final courseId = user.activeCourseId;

    _typingSubscription = FirebaseFirestore.instance
        .collection('typing_status')
        .where(
          courseId != null ? 'courseId' : 'level',
          isEqualTo: courseId ?? user.level,
        )
        .snapshots()
        .listen((snapshot) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userId = data['userId'];
            final isTyping = data['isTyping'];

            if (userId != user.uid && isTyping) {
              final userName = data['userName'] ?? 'Someone';
              setState(() {
                _typingUser = userName;
              });

              // Auto-clear after 3 seconds if no update
              if (_typingTimers.containsKey(userId)) {
                _typingTimers[userId]?.cancel();
              }
              _typingTimers[userId] = Timer(const Duration(seconds: 3), () {
                if (mounted && _typingUser == userName) {
                  setState(() {
                    _typingUser = '';
                  });
                }
              });
            }
          }
        });
  }

  String _chatStorageKey(user) {
    final room = user.activeCourseId != null
        ? 'course_${user.activeCourseId}'
        : 'level_${user.level}';
    return 'chat_history_$room';
  }

  Future<void> _loadLocalMessages() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final preferences = await SharedPreferences.getInstance();
    final encodedMessages = preferences.getString(_chatStorageKey(user));
    if (encodedMessages == null) return;

    try {
      final decoded = jsonDecode(encodedMessages) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _localMessages = decoded
            .whereType<Map>()
            .map((message) => Map<String, dynamic>.from(message))
            .toList();
      });
    } catch (_) {
      await preferences.remove(_chatStorageKey(user));
    }
  }

  Future<void> _cacheMessage(
    String messageId,
    Map<String, dynamic> data,
  ) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final normalized = Map<String, dynamic>.from(data);
    normalized['messageId'] = messageId;
    final rawTimestamp = normalized['timestamp'];
    normalized['timestamp'] = rawTimestamp is Timestamp
        ? rawTimestamp.millisecondsSinceEpoch
        : rawTimestamp is int
        ? rawTimestamp
        : DateTime.now().millisecondsSinceEpoch;
    normalized.remove('expiresAt');

    final messagesById = <String, Map<String, dynamic>>{
      for (final message in _localMessages)
        if (message['messageId'] != null)
          message['messageId'] as String: message,
    };
    messagesById[messageId] = normalized;
    final cachedMessages = messagesById.values.toList()
      ..sort(
        (first, second) =>
            (second['timestamp'] as int).compareTo(first['timestamp'] as int),
      );
    final limitedMessages = cachedMessages.take(200).toList();
    final changed = jsonEncode(_localMessages) != jsonEncode(limitedMessages);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _chatStorageKey(user),
      jsonEncode(limitedMessages),
    );
    if (mounted && changed) {
      setState(() => _localMessages = limitedMessages);
    }
  }

  List<Map<String, dynamic>> _messagesForDisplay(
    List<QueryDocumentSnapshot> remoteDocuments,
  ) {
    final messagesById = <String, Map<String, dynamic>>{
      for (final message in _localMessages)
        if (message['messageId'] != null)
          message['messageId'] as String: message,
    };

    for (final document in remoteDocuments) {
      final data = Map<String, dynamic>.from(document.data() as Map);
      final expiresAt = data['expiresAt'];
      if (expiresAt is Timestamp &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        continue;
      }
      final rawTimestamp = data['timestamp'];
      data['timestamp'] = rawTimestamp is Timestamp
          ? rawTimestamp.millisecondsSinceEpoch
          : rawTimestamp is int
          ? rawTimestamp
          : DateTime.now().millisecondsSinceEpoch;
      data['messageId'] = document.id;
      messagesById[document.id] = data;
      _cacheMessage(document.id, data);
    }

    final messages = messagesById.values.toList()
      ..sort(
        (first, second) =>
            (second['timestamp'] as int).compareTo(first['timestamp'] as int),
      );
    return messages;
  }

  Future<void> _sendTypingStatus(bool isTyping) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final courseId = user.activeCourseId;
    final docRef = FirebaseFirestore.instance
        .collection('typing_status')
        .doc(
          courseId != null
              ? 'course_${courseId}_${user.uid}'
              : 'level_${user.level}_${user.uid}',
        );

    if (isTyping) {
      await docRef.set({
        'userId': user.uid,
        'userName': user.fullName,
        'level': user.level,
        'courseId': ?courseId,
        'isTyping': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.delete();
    }
  }

  void _handleTyping() {
    if (_typingTimer != null) {
      _typingTimer!.cancel();
    }

    if (!_isTyping) {
      _isTyping = true;
      _sendTypingStatus(true);
    }

    _typingTimer = Timer(const Duration(milliseconds: 1500), () {
      _isTyping = false;
      _sendTypingStatus(false);
    });
  }

  Future<void> _sendReaction(
    String messageId,
    String reaction,
    String senderId,
    String senderName,
  ) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final reactionRef = FirebaseFirestore.instance
        .collection('message_reactions')
        .doc('${messageId}_${user.uid}');

    await reactionRef.set({
      'messageId': messageId,
      'userId': user.uid,
      'userName': user.fullName,
      'reaction': reaction,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _removeReaction(String messageId) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final reactionRef = FirebaseFirestore.instance
        .collection('message_reactions')
        .doc('${messageId}_${user.uid}');

    await reactionRef.delete();
  }

  Future<void> _showReactionPicker(
    String messageId,
    String senderId,
    String senderName,
  ) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    // Check if user already reacted
    final existingReaction = await FirebaseFirestore.instance
        .collection('message_reactions')
        .doc('${messageId}_${user.uid}')
        .get();

    final hasReacted = existingReaction.exists;
    final currentReaction = hasReacted
        ? existingReaction.data()!['reaction']
        : null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Reaction',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _availableReactions.map((reaction) {
                final isSelected = currentReaction == reaction;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    if (isSelected) {
                      await _removeReaction(messageId);
                    } else {
                      await _sendReaction(
                        messageId,
                        reaction,
                        senderId,
                        senderName,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(reaction, style: const TextStyle(fontSize: 32)),
                  ),
                );
              }).toList(),
            ),
            if (hasReacted) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _removeReaction(messageId);
                },
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Remove Reaction'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Stream<Map<String, dynamic>> _getReactionsForMessage(String messageId) {
    return FirebaseFirestore.instance
        .collection('message_reactions')
        .where('messageId', isEqualTo: messageId)
        .snapshots()
        .map((snapshot) {
          final reactions = <String, List<String>>{};
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final reaction = data['reaction'] as String;
            final userName = data['userName'] as String;
            if (!reactions.containsKey(reaction)) {
              reactions[reaction] = [];
            }
            reactions[reaction]!.add(userName);
          }
          return reactions;
        });
  }

  void _setReplyingTo(Map<String, dynamic> message) {
    setState(() {
      _replyingTo = message;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false, // Bottom navigation handles its own safe area
        child: Column(
          children: [
            // Glass AppBar
            _buildGlassAppBar(user, isDarkMode, isDesktop),

            // Reply Bar
            if (_replyingTo != null) _buildReplyBar(isDarkMode),

            // Chat Messages - Wrap with Expanded
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: (user == null)
                    ? const Stream.empty()
                    : user.activeCourseId != null
                    ? FirebaseFirestore.instance
                          .collection('messages')
                          .where('courseId', isEqualTo: user.activeCourseId)
                          .orderBy('timestamp', descending: true)
                          .snapshots()
                    : FirebaseFirestore.instance
                          .collection('messages')
                          .where('level', isEqualTo: user.level)
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                builder: (context, snapshot) {
                  if (user == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    // This will now print the REAL error (like Missing Index)
                    // to the console instead of just crashing the debugger.
                    print("❌ Firestore Stream Error: ${snapshot.error}");
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF00F5FF),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Loading messages...",
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = _messagesForDisplay(snapshot.data!.docs);

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No messages yet.\nBe the first to say hello!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.only(
                      left: isDesktop ? 20 : 12,
                      right: isDesktop ? 20 : 12,
                      top: isDesktop ? 20 : 12,
                      bottom: 20, // Add extra bottom padding
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final data = messages[index];
                      final msg = data;

                      final isMe = data['senderId'] == user.uid;

                      return Column(
                        children: [
                          // Reply indicator if this message is a reply
                          if (msg['replyToId'] != null)
                            _buildReplyIndicator(msg, isDarkMode),

                          GestureDetector(
                            onLongPress: () => _setReplyingTo(msg),
                            child: _buildMessageBubble(
                              msg,
                              isMe,
                              isDarkMode,
                              isDesktop,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Typing Indicator
            if (_typingUser.isNotEmpty)
              _buildTypingIndicator(isDarkMode, _typingUser),

            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 8 : 0),
              child: _buildInputBar(user, isDarkMode, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: const Color(0xFF00F5FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingTo?['senderName']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF00F5FF),
                  ),
                ),
                Text(
                  _replyingTo?['message'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(Map<String, dynamic> msg, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(left: 50, right: 20, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.05,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Reply to ${msg['replyToSender']}: ${msg['replyToMessage']}',
              style: TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar(user, bool isDarkMode, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundImage:
                user?.profilePicture != null && user!.profilePicture!.isNotEmpty
                ? MemoryImage(base64Decode(user.profilePicture!))
                : null as ImageProvider?,
            backgroundColor: const Color(0xFF00F5FF),
            child: user?.profilePicture == null
                ? Text(
                    user?.fullName[0].toUpperCase() ?? "C",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Level ${user?.level} Chat",
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: user?.level == null
                      ? const Stream.empty()
                      : FirebaseFirestore.instance
                            .collection('users')
                            .where('level', isEqualTo: user.level)
                            .snapshots(),
                  builder: (context, snapshot) {
                    final studentCount = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;
                    return Text(
                      "Real-time • $studentCount Students",
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF00F5FF),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "Live",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    bool isDarkMode,
    bool isDesktop,
  ) {
    final type = msg['type'] ?? 'text';
    final timestamp = msg['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                CircleAvatar(
                  radius: 16,
                  backgroundImage: msg['senderProfilePicture'] != null
                      ? NetworkImage(msg['senderProfilePicture'])
                      : null,
                  backgroundColor: const Color(0xFF00F5FF),
                  child: msg['senderProfilePicture'] == null
                      ? Text(
                          (msg['senderName'] ?? "U")[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(
                          msg['senderName'] ?? "Unknown",
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF00F5FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: type == 'doc' ? 16 : 12,
                        vertical: type == 'doc' ? 12 : 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isMe
                              ? [
                                  const Color(0xFF00F5FF),
                                  const Color(0xFF00D4FF),
                                ]
                              : (isDarkMode
                                    ? [Colors.grey[800]!, Colors.grey[700]!]
                                    : [Colors.white, Colors.grey[100]!]),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isMe ? 20 : 4),
                          topRight: Radius.circular(isMe ? 4 : 20),
                          bottomLeft: const Radius.circular(20),
                          bottomRight: const Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (type == 'doc' && msg['fileUrl'] != null)
                            GestureDetector(
                              onTap: () async {
                                final url = msg['fileUrl'];
                                if (await canLaunchUrl(Uri.parse(url))) {
                                  await launchUrl(
                                    Uri.parse(url),
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              child: Container(
                                width: 250,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isMe ? Colors.black : Colors.white)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        (isMe
                                                ? Colors.black
                                                : const Color(0xFF00F5FF))
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _getFileIcon(msg['fileName']),
                                          color: isMe
                                              ? Colors.black
                                              : const Color(0xFF00F5FF),
                                          size: 32,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                msg['fileName'] ?? "Document",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe
                                                      ? Colors.black
                                                      : (isDarkMode
                                                            ? Colors.white
                                                            : Colors.black87),
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Tap to view",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isMe
                                                      ? Colors.black54
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            (isMe
                                                    ? Colors.black
                                                    : const Color(0xFF00F5FF))
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.open_in_new,
                                            size: 14,
                                            color: isMe
                                                ? Colors.black
                                                : const Color(0xFF00F5FF),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Open Document",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isMe
                                                  ? Colors.black
                                                  : const Color(0xFF00F5FF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (type == 'text')
                            Text(
                              msg['message'],
                              style: TextStyle(
                                color: isMe
                                    ? Colors.black
                                    : (isDarkMode
                                          ? Colors.white
                                          : Colors.black87),
                                fontSize: isDesktop ? 15 : 14,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(time),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: (isMe ? Colors.black54 : Colors.grey),
                                ),
                              ),
                              if (isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.done_all,
                                    size: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Reactions Row
                    _MessageReactionsWidget(
                      messageId: msg['messageId'],
                      isDarkMode: isDarkMode,
                      onShowPicker: () => _showReactionPicker(
                        msg['messageId'],
                        msg['senderId'],
                        msg['senderName'],
                      ),
                    ),
                  ],
                ),
              ),
              // Reaction Button
              GestureDetector(
                onTap: () => _showReactionPicker(
                  msg['messageId'],
                  msg['senderId'],
                  msg['senderName'],
                ),
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_emotions_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              // Reply Button
              GestureDetector(
                onTap: () => _setReplyingTo(msg),
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.reply, size: 14, color: Colors.grey),
                ),
              ),
              if (isMe) const SizedBox(width: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDarkMode, String typingUser) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF00F5FF),
            child: Text(
              typingUser[0].toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
                const SizedBox(width: 8),
                Text(
                  "$typingUser is typing...",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int delay) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = (_animationController.value * 3 + delay).toInt() % 3;
        return Opacity(
          opacity: value == 0 ? 1.0 : 0.3,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF00F5FF),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(user, bool isDarkMode, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ... rest of your input bar code remains the same
          IconButton(
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isUploading
                    ? Colors.grey.withValues(alpha: 0.3)
                    : const Color(0xFF00F5FF).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.attach_file,
                      color: Color(0xFF00F5FF),
                      size: 24,
                    ),
            ),
            onPressed: _isUploading ? null : () => _uploadDocument(user),
          ),
          IconButton(
            icon: Icon(
              Icons.emoji_emotions_outlined,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => _showEmojiPicker(),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.white : Colors.black).withValues(
                  alpha: 0.05,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  onChanged: (_) {
                    _handleTyping();
                    _scrollToBottom();
                  },
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: _replyingTo != null
                        ? "Type your reply..."
                        : "Type...",
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black38,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(user),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => _sendMessage(user),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(user) async {
    if (user == null ||
        user.level == null ||
        _messageController.text.trim().isEmpty) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    // Stop typing indicator
    _sendTypingStatus(false);

    final messageData = {
      'senderId': user?.uid,
      'senderName': user?.fullName,
      'senderProfilePicture': user?.profilePicture,
      'message': messageText,
      'type': 'text',
      'level': user?.level,
      if (user?.activeCourseId != null) 'courseId': user?.activeCourseId,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 10)),
      ),
    };

    // Add reply data if replying to a message
    if (_replyingTo != null) {
      messageData['replyToId'] = _replyingTo!['messageId'];
      messageData['replyToMessage'] = _replyingTo!['message'];
      messageData['replyToSender'] = _replyingTo!['senderName'];
      _cancelReply();
    }

    // Send to Firebase
    await FirebaseFirestore.instance.collection('messages').add(messageData);
  }

  Future<void> _uploadDocument(user) async {
    setState(() => _isUploading = true);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'jpg',
          'jpeg',
          'png',
          'gif',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F5FF)),
                ),
                const SizedBox(height: 16),
                Text("Uploading ${file.name}..."),
              ],
            ),
          ),
        );

        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_docs/level_${user?.level}')
            .child('${DateTime.now().millisecondsSinceEpoch}_${file.name}');

        String downloadUrl;
        if (file.bytes != null) {
          await ref.putData(file.bytes!);
        } else if (file.path != null) {
          await ref.putFile(File(file.path!));
        } else {
          throw Exception("No file data available");
        }
        downloadUrl = await ref.getDownloadURL();

        final messageData = {
          'senderId': user?.uid,
          'senderName': user?.fullName,
          'senderProfilePicture': user?.profilePicture,
          'message': "Shared a document",
          'type': 'doc',
          'fileName': file.name,
          'fileUrl': downloadUrl,
          'level': user?.level,
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 10)),
          ),
          'filePath': ref.fullPath,
        };

        if (_replyingTo != null) {
          messageData['replyToId'] = _replyingTo!['messageId'];
          messageData['replyToMessage'] = _replyingTo!['message'];
          messageData['replyToSender'] = _replyingTo!['senderName'];
          _cancelReply();
        }

        await FirebaseFirestore.instance
            .collection('messages')
            .add(messageData);

        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${file.name} uploaded and sent!"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showEmojiPicker() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Lightweight emoji grid to avoid dependency/API mismatch
    final emojis = <String>[
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😍',
      '😘',
      '😗',
      '😙',
      '😚',
      '😋',
      '😜',
      '🤪',
      '😝',
      '🤑',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '🤥',
      '😴',
      '🤤',
      '😪',
      '🤯',
      '😷',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🤧',
      '🥵',
      '🥶',
      '🥴',
      '🤠',
      '🧐',
      '🤓',
      '😎',
      '🤡',
      '👻',
      '💩',
      '👽',
      '🤖',
      '💀',
      '☠️',
      '😺',
      '😸',
      '😹',
      '😻',
      '😼',
      '😽',
      '🙀',
      '😿',
      '😾',
      '👍',
      '👎',
      '👏',
      '🙌',
      '🙏',
      '💪',
      '🤝',
      '👋',
      '🤙',
      '✌️',
      '👌',
      '🤞',
      '🤟',
      '🖖',
      '✍️',
      '💅',
      '🤳',
      '💋',
      '💘',
      '💝',
      '💖',
      '💗',
      '💓',
      '💞',
      '💕',
      '💌',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.45,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              final emoji = emojis[index];
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  final newText = '${_messageController.text}$emoji';
                  _messageController.text = newText;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: newText.length),
                  );
                  _handleTyping();
                },
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file;
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
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

class _MessageReactionsWidget extends StatelessWidget {
  final String messageId;
  final bool isDarkMode;
  final VoidCallback onShowPicker;

  const _MessageReactionsWidget({
    required this.messageId,
    required this.isDarkMode,
    required this.onShowPicker,
  });

  Stream<Map<String, List<String>>> _getReactions(String messageId) {
    return FirebaseFirestore.instance
        .collection('message_reactions')
        .where('messageId', isEqualTo: messageId)
        .snapshots()
        .map((snapshot) {
          final reactions = <String, List<String>>{};
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final reaction = data['reaction'] as String;
            final userName = data['userName'] as String;
            reactions.putIfAbsent(reaction, () => []).add(userName);
          }
          return reactions;
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, List<String>>>(
      // Note: In a production app, this stream should be memoized or
      // part of a provider to prevent redundant rebuilding.
      stream: _getReactions(messageId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final reactions = snapshot.data!;
        return GestureDetector(
          onTap: onShowPicker,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: reactions.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    '${entry.key} ${entry.value.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
