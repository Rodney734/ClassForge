import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/live_class_service.dart';
import '../services/livekit_service.dart';

class LiveClassScreen extends StatefulWidget {
  final String? className;
  final bool isHost;
  final VoidCallback? onLeave;

  const LiveClassScreen({
    super.key,
    this.className = "Mobile Development",
    this.isHost = false,
    this.onLeave,
  });

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends State<LiveClassScreen>
    with SingleTickerProviderStateMixin {
  Room? _room;
  bool _isConnected = false;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isScreenSharing = false;
  bool _isLeaving = false;
  bool _showChat = false;
  bool _showReactions = false;
  //bool _isFullScreen = false;

  EventsListener<RoomEvent>? _roomListener;
  late AnimationController _animationController;
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();

  final List<Map<String, dynamic>> _activeReactions = [];
  final Set<String> _processedReactionIds = {};

  Timer? _dataSyncTimer;
  // Reactions
  final List<String> _reactions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🎉',
    '🙌',
    '👏',
  ];
  String? _selectedReaction;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animationController.forward();
    _initLiveKit();
    _startDataSync();
  }

  @override
  void dispose() {
    _roomListener?.dispose();
    _room?.disconnect();
    _animationController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _dataSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLiveKit() async {
    final granted = await _requestPermissions();
    if (granted) {
      await _connectToLiveKit();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Camera and microphone permissions denied. Live class cannot start.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    bool allGranted = true;
    if (statuses[Permission.camera] != PermissionStatus.granted) {
      allGranted = false;
    }
    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      allGranted = false;
    }

    if (!allGranted && mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Permissions Required"),
          content: const Text(
            "Camera and microphone permissions are essential for live classes. Please grant them in app settings.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
    }
    return allGranted;
  }

  void _startDataSync() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    _dataSyncTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isConnected || !mounted || user == null) return;

      try {
        final data = await LiveClassService().getLiveClassData(user.level);

        if (mounted) {
          setState(() {
            // Update chat messages
            final newMessages = (data['chatMessages'] as List)
                .cast<Map<String, dynamic>>();
            _chatMessages.clear();
            _chatMessages.addAll(newMessages);

            // Handle reactions (e.g., show animations)
            final newReactions = (data['reactions'] as List)
                .cast<Map<String, dynamic>>();
            _handleIncomingReactions(newReactions);
          });
        }
      } catch (e) {
        print("Data sync error: $e");
      }
    });
  }

  void _handleIncomingReactions(List<Map<String, dynamic>> reactions) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Remove old reactions
    _activeReactions.removeWhere((r) => now - (r['startTime'] as int) > 3000);

    for (final reaction in reactions) {
      final reactionId = reaction['id'] as String?;
      if (reactionId != null && !_processedReactionIds.contains(reactionId)) {
        setState(() {
          _activeReactions.add({...reaction, 'startTime': now});
          _processedReactionIds.add(reactionId);
        });
      }
    }
  }

  Future<void> _connectToLiveKit() async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final level = user?.level ?? 4;
      final isLecturer = widget.isHost || user?.role == "lecturer";

      final roomName = "level_${level}_class";

      _room = await LiveKitService().createOrJoinRoom(
        roomName: roomName,
        identity: user?.uid ?? "user_${DateTime.now().millisecondsSinceEpoch}",
        name: user?.fullName ?? "User",
        isHost: isLecturer,
      );

      _setupListeners();
      setState(() => _isConnected = true);
      await _setupLocalTracks();

      if (isLecturer) {
        await LiveClassService().startLiveClass(
          level: level,
          className: widget.className ?? "Mobile Application Development",
          lecturerId: user?.uid ?? "",
          lecturerName: user?.fullName ?? "Lecturer",
        );
      } else {
        await LiveClassService().joinClass(
          level: level,
          studentId: user?.uid ?? "",
          studentName: user?.fullName ?? "Student",
        );
      }
    } catch (e) {
      print("LiveKit Connection Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupListeners() {
    if (_room == null) return;

    _roomListener = _room!.createListener();
    _roomListener!
      ..on<RoomDisconnectedEvent>((event) {
        if (mounted && !_isLeaving) Navigator.pop(context);
      })
      ..on<ParticipantConnectedEvent>((event) => setState(() {}))
      ..on<ParticipantDisconnectedEvent>((event) => setState(() {}))
      ..on<TrackSubscribedEvent>((event) => setState(() {}))
      ..on<TrackUnsubscribedEvent>((event) => setState(() {}))
      ..on<TrackMutedEvent>((event) => setState(() {}))
      ..on<TrackUnmutedEvent>((event) => setState(() {}))
      ..on<TrackPublishedEvent>((event) => setState(() {}))
      ..on<TrackUnpublishedEvent>((event) => setState(() {}))
      ..on<LocalTrackPublishedEvent>((event) => setState(() {}))
      ..on<LocalTrackUnpublishedEvent>((event) => setState(() {}));
  }

  Future<void> _setupLocalTracks() async {
    final room = _room;
    if (room == null || room.localParticipant == null) return;

    try {
      await room.localParticipant!.setCameraEnabled(_isCameraOn);
      await room.localParticipant!.setMicrophoneEnabled(_isMicOn);
    } catch (e) {
      print("Error setting up tracks: $e");
    }
  }

  Future<void> _toggleMic() async {
    final newState = !_isMicOn;
    await _room?.localParticipant?.setMicrophoneEnabled(newState);
    setState(() => _isMicOn = newState);
  }

  Future<void> _toggleCamera() async {
    final newState = !_isCameraOn;
    await _room?.localParticipant?.setCameraEnabled(newState);
    setState(() => _isCameraOn = newState);
  }

  Future<void> _toggleScreenShare() async {
    final room = _room;
    if (room == null || room.localParticipant == null) return;

    try {
      final newState = !_isScreenSharing;
      await room.localParticipant!.setScreenShareEnabled(newState);
      setState(() => _isScreenSharing = newState);
    } catch (e) {
      print("Screen share error: $e");
    }
  }

  Future<void> _sendReaction(String reaction) async {
    setState(() {
      _selectedReaction = reaction;
      _showReactions = false;
    });

    // Show floating reaction animation
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    await LiveClassService().sendReaction(
      level: user?.level ?? 4,
      reaction: reaction,
      userId: user?.uid ?? "",
      userName: user?.fullName ?? "User",
    );

    // Clear reaction after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _selectedReaction = null;
        });
      }
    });
  }

  Future<void> _sendChatMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final message = _chatController.text.trim();
    _chatController.clear();

    final chatMessage = {
      'message': message,
      'userName': user?.fullName ?? 'User',
      'timestamp': Timestamp.now(),
      'userId': user?.uid,
    };

    setState(() {
      _chatMessages.add(chatMessage);
    });

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Send to Firestore
    await LiveClassService().sendChatMessage(
      level: user?.level ?? 4,
      message: message,
      userId: user?.uid ?? "",
      userName: user?.fullName ?? "User",
    );
  }

  Future<void> _leaveClass() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final level = user?.level ?? 4;
    final isLecturer = widget.isHost || user?.role == "lecturer";

    setState(() => _isLeaving = true);

    if (isLecturer) {
      await LiveClassService().endLiveClass(level);
    } else {
      await LiveClassService().leaveClass(
        level: level,
        userId: user?.uid ?? "",
      );
    }

    await _room?.disconnect();
    _room = null;
    _roomListener?.dispose();
    _roomListener = null;

    if (!mounted) return;

    if (widget.onLeave != null) {
      widget.onLeave!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Leave Class?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to leave the live class?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveClass();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Leave"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isLecturer = widget.isHost || user?.role == "lecturer";

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showChat = false),
        child: Stack(
          children: [
            // Main Video Grid
            _buildVideoGrid(),

            // Top Bar - Glass Morphism
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildGlassTopBar(isLecturer),
            ),

            // Bottom Controls - Glass Morphism
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  _buildFloatingReactions(),
                  // Floating Reaction Display
                  if (_selectedReaction != null) _buildFloatingReaction(),

                  // Reactions Row
                  if (_showReactions) _buildReactionsRow(),

                  // Controls
                  _buildGlassBottomControls(isLecturer),
                ],
              ),
            ),

            // Chat Panel
            if (_showChat)
              Positioned(
                right: 0,
                top: 80,
                bottom: 180,
                child: _buildChatPanel(),
              ),

            // Chat Button
            Positioned(right: 20, bottom: 100, child: _buildChatButton()),

            // Reaction Button
            Positioned(right: 80, bottom: 100, child: _buildReactionButton()),

            // Connection Status
            if (!_isConnected)
              Container(
                color: Colors.black.withValues(alpha: 0.9),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00F5FF),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Connecting to live class...",
                        style: TextStyle(color: Colors.white, fontSize: 16),
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

  Widget _buildVideoGrid() {
    final room = _room;
    if (room == null || !_isConnected) return _buildPlaceholder();

    final List<Participant> allParticipants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    VideoTrack? screenShareTrack;
    String? screenShareName;
    final cameraTracks =
        <
          ({
            VideoTrack track,
            String name,
            bool isLocal,
            bool isMicOn,
            bool isCameraOn,
            String identity,
          })
        >[];

    for (var p in allParticipants) {
      final isLocal = p is LocalParticipant;
      final isMicOn = p.isMicrophoneEnabled();
      final isCameraOn = p.isCameraEnabled();

      for (var pub in p.videoTrackPublications) {
        if (pub.track is VideoTrack && pub.track != null) {
          final track = pub.track as VideoTrack;
          final name = p.name.isNotEmpty
              ? p.name
              : (p.identity.isNotEmpty ? p.identity : "User");
          final identity = p.identity;

          if (pub.source == TrackSource.screenShareVideo) {
            screenShareTrack = track;
            screenShareName = name;
          } else {
            cameraTracks.add((
              track: track,
              name: name,
              isLocal: isLocal,
              isMicOn: isMicOn,
              isCameraOn: isCameraOn,
              identity: identity,
            ));
          }
        }
      }
    }

    // If no camera tracks, show placeholder for each participant
    if (cameraTracks.isEmpty && screenShareTrack == null) {
      return _buildParticipantsPlaceholder(allParticipants);
    }

    // Screen Share Mode
    if (screenShareTrack != null) {
      return Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildVideoTile(
              screenShareTrack,
              "$screenShareName (Screen)",
              isScreenShare: true,
              isMicOn: false,
            ),
          ),
          if (cameraTracks.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: cameraTracks.length,
                itemBuilder: (context, index) {
                  final item = cameraTracks[index];
                  return SizedBox(
                    width: 160,
                    child: _buildVideoTile(
                      item.track,
                      item.name,
                      isLocal: item.isLocal,
                      isMicOn: item.isMicOn,
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }

    // Camera Grid
    if (cameraTracks.isNotEmpty) {
      final count = cameraTracks.length;
      final crossAxisCount = count > 1 ? (count > 4 ? 3 : 2) : 1;

      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 16 / 9,
        ),
        itemCount: cameraTracks.length,
        itemBuilder: (context, index) {
          final item = cameraTracks[index];
          return _buildVideoTile(
            item.track,
            item.name,
            isLocal: item.isLocal,
            isMicOn: item.isMicOn,
            isCameraOn: item.isCameraOn,
          );
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildParticipantsPlaceholder(List<Participant> participants) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length > 1 ? 2 : 1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 16 / 9,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        final isLocal = p is LocalParticipant;
        final isMicOn = p.isMicrophoneEnabled();
        final name = p.name.isNotEmpty
            ? p.name
            : (p.identity.isNotEmpty ? p.identity : "User");

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
            border: isLocal
                ? Border.all(color: const Color(0xFF00F5FF), width: 3)
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00F5FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mic,
                      size: 14,
                      color: isMicOn ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoTile(
    VideoTrack track,
    String label, {
    bool isLocal = false,
    bool isScreenShare = false,
    bool isMicOn = true,
    bool isCameraOn = true,
  }) {
    return Container(
      key: ValueKey(track.sid ?? track.hashCode.toString()),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: isLocal
            ? Border.all(color: const Color(0xFF00F5FF), width: 2)
            : null,
      ),
      child: Stack(
        children: [
          if (isCameraOn)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FittedBox(
                  fit: isScreenShare ? BoxFit.contain : BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: 1280,
                    height: 720,
                    child: VideoTrackRenderer(
                      track,
                      key: ValueKey('${track.sid ?? track.hashCode}_renderer'),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          label[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00F5FF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

          // Participant Label
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic,
                    size: 12,
                    color: isMicOn ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  if (isLocal)
                    const Text(
                      "You",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    )
                  else
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    final user = Provider.of<AuthService>(context).currentUser;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user?.fullName[0].toUpperCase() ?? "U",
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00F5FF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            user?.fullName ?? "User",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Camera is off",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tap the camera button to start video",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTopBar(bool isLecturer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showLeaveDialog(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.className ?? "Live Class",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${(_room?.remoteParticipants.length ?? 0) + 1} participants",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          if (isLecturer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi,
                  size: 12,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? "Connected" : "Connecting...",
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBottomControls(bool isLecturer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildGlassControlButton(
            icon: _isMicOn ? Icons.mic : Icons.mic_off,
            isActive: _isMicOn,
            onTap: _toggleMic,
            isDestructive: !_isMicOn,
          ),
          const SizedBox(width: 16),
          _buildGlassControlButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            isActive: _isCameraOn,
            onTap: _toggleCamera,
            isDestructive: !_isCameraOn,
          ),
          if (isLecturer) ...[
            const SizedBox(width: 16),
            _buildGlassControlButton(
              icon: Icons.screen_share,
              isActive: _isScreenSharing,
              onTap: _toggleScreenShare,
            ),
          ],
          const SizedBox(width: 16),
          // Leave button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Material(
              color: Colors.red,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => _showLeaveDialog(),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.call_end, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Material(
        color: isDestructive
            ? Colors.red
            : (isActive ? const Color(0xFF00F5FF) : Colors.grey[800]),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isDestructive || !isActive ? Colors.white : Colors.black,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingReactions() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return SizedBox(
      height: 200,
      child: Stack(
        children: _activeReactions.map((reaction) {
          final elapsedTime = now - (reaction['startTime'] as int);
          final progress = (elapsedTime / 3000.0).clamp(0.0, 1.0);

          // Animate from bottom to top and fade out
          final bottom = 150 * progress;
          final opacity = 1.0 - progress;

          // Random horizontal position
          final horizontalPosition =
              (reaction['userId'].hashCode % 80) + 10.0; // % of screen width

          return Positioned(
            bottom: bottom,
            left:
                MediaQuery.of(context).size.width * (horizontalPosition / 100),
            child: Opacity(
              opacity: opacity,
              child: Text(
                reaction['reaction'] as String,
                style: const TextStyle(
                  fontSize: 32,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFloatingReaction() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 80),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (context, double value, child) {
          return Transform.scale(
            scale: 0.5 + (0.5 * value),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedReaction ?? '',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 8),
              const Text(
                "Reacted",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _reactions.map((reaction) {
          return GestureDetector(
            onTap: () => _sendReaction(reaction),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(reaction, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatButton() {
    return GestureDetector(
      onTap: () => setState(() => _showChat = !_showChat),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF00F5FF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
              blurRadius: 15,
            ),
          ],
        ),
        child: Icon(
          _showChat ? Icons.close : Icons.chat,
          color: Colors.black,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildReactionButton() {
    return GestureDetector(
      onTap: () => setState(() => _showReactions = !_showReactions),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.emoji_emotions_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        border: Border(
          left: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Color(0xFF00F5FF), size: 20),
                const SizedBox(width: 12),
                const Text(
                  "Live Chat",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  "${_chatMessages.length} messages",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final user = Provider.of<AuthService>(
                  context,
                  listen: false,
                ).currentUser;
                final msg = _chatMessages[index];
                final isMe = msg['userId'] == user?.uid;

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF00F5FF) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(
                            msg['userName'] ?? 'User',
                            style: const TextStyle(
                              color: Color(0xFF00F5FF),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          msg['message'],
                          style: TextStyle(
                            color: isMe ? Colors.black : Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _formatTime((msg['timestamp'] as Timestamp).toDate()),
                          style: TextStyle(
                            color: isMe ? Colors.black54 : Colors.white54,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Chat Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendChatMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00F5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.black,
                      size: 20,
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
