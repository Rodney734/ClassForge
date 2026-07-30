import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'chat_screen.dart';
import 'live_class_screen.dart';
import 'notices_screen.dart';
import 'assignments_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'ai_tutor_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _currentIndex = 0;
  Widget? _activeSubPage;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      StudentDashboardContent(onActionSelected: _setSubPage),
      const ChatScreen(),
      const DiscoverScreen(),
      const ProfileScreen(),
    ];
  }

  void _setSubPage(Widget? page) {
    setState(() {
      _activeSubPage = page;
      if (page != null) _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentIndex == 0 && _activeSubPage != null
            ? _activeSubPage!
            : _pages[_currentIndex],
      ),
      bottomNavigationBar: isKeyboardVisible
          ? const SizedBox.shrink()
          : _buildModernBottomNav(isDarkMode),
      floatingActionButton: isKeyboardVisible
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveClassScreen()),
              ),
              backgroundColor: const Color(0xFF00F5FF),
              child: const Icon(Icons.live_tv, color: Colors.black, size: 30),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildModernBottomNav(bool isDarkMode) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 75,
      borderRadius: 30,
      blur: 20,
      linearGradient: LinearGradient(
        colors: [
          (isDarkMode ? Colors.grey[900]! : Colors.white).withValues(
            alpha: 0.2,
          ),
          (isDarkMode ? Colors.grey[850]! : Colors.white70).withValues(
            alpha: 0.1,
          ),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: 1,
      borderGradient: LinearGradient(
        colors: [
          (isDarkMode ? const Color.fromARGB(255, 243, 243, 245) : Colors.black)
              .withValues(alpha: 0.2),
          (isDarkMode ? const Color.fromARGB(255, 242, 243, 245) : Colors.black)
              .withValues(alpha: 0.2),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_outlined, Icons.home, 0, isDarkMode),
          _navItem(Icons.chat_bubble_outline, Icons.chat_bubble, 1, isDarkMode),
          const SizedBox(width: 60),
          _navItem(Icons.explore_outlined, Icons.explore, 2, isDarkMode),
          _navItem(Icons.person_outline, Icons.person, 3, isDarkMode),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData outlinedIcon,
    IconData filledIcon,
    int index,
    bool isDarkMode,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = index;
        if (index == 0) {
          _activeSubPage = null;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? const Color(0xFF00F5FF).withValues(alpha: 0.2)
              : Colors.transparent,
        ),
        child: Icon(
          isSelected ? filledIcon : outlinedIcon,
          color: isSelected
              ? const Color(0xFF00F5FF)
              : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
          size: 26,
        ),
      ),
    );
  }
}

// ==================== Student Dashboard Content ====================
class StudentDashboardContent extends StatefulWidget {
  final Function(Widget?) onActionSelected;

  const StudentDashboardContent({super.key, required this.onActionSelected});

  @override
  State<StudentDashboardContent> createState() =>
      _StudentDashboardContentState();
}

class _StudentDashboardContentState extends State<StudentDashboardContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Set<String> _markedSessions = {};
  Stream<QuerySnapshot>? _attendanceStream;
  Stream<QuerySnapshot>? _liveClassStream;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    _loadStudentAttendanceRecords();
    _attendanceStream = FirebaseFirestore.instance
        .collection('attendance_sessions')
        .where('status', isEqualTo: 'active')
        .snapshots();

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      _liveClassStream = FirebaseFirestore.instance
          .collection('scheduled_classes')
          .where('level', isEqualTo: user.level)
          .where('status', isEqualTo: 'live')
          .snapshots();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentAttendanceRecords() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final records = await FirebaseFirestore.instance
        .collection('attendance_records')
        .where('studentId', isEqualTo: user.uid)
        .get();

    if (!mounted) return;

    setState(() {
      _markedSessions = records.docs
          .map((doc) => doc['sessionId'] as String)
          .toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final isTablet = screenWidth > 600 && screenWidth <= 800;

    final bottomInset = MediaQuery.of(context).padding.bottom + 120;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: isDesktop ? 40 : (isTablet ? 30 : 20),
          right: isDesktop ? 40 : (isTablet ? 30 : 20),
          top: isDesktop ? 40 : (isTablet ? 30 : 20),
          bottom: bottomInset,
        ),
        child: FadeTransition(
          opacity: _animationController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : (isTablet ? 28 : 26),
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Let's make today productive",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: isDesktop ? 16 : (isTablet ? 14 : 12),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      // Navigate to profile
                    },
                    child: CircleAvatar(
                      radius: isDesktop ? 30 : (isTablet ? 28 : 25),
                      backgroundColor: const Color(0xFF00D4FF),
                      child: Text(
                        user?.fullName[0].toUpperCase() ?? "S",
                        style: TextStyle(
                          fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ============================================
              // GLASS MORPHISM LIVE CLASS NOTIFICATION
              // ============================================
              _buildLiveClassNotification(isDarkMode, isDesktop, isTablet),

              const SizedBox(height: 20),

              // Active Attendance Section
              _buildActiveAttendanceSection(isDarkMode),

              const SizedBox(height: 20),

              // Quick Access Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Quick Access",
                    style: TextStyle(
                      fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      "View All",
                      style: TextStyle(
                        color: const Color(0xFF00D4FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Responsive Quick Access Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth;
                  final crossAxisCount = cardWidth < 500
                      ? 2
                      : (cardWidth < 800 ? 3 : 4);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      final cards = _buildQuickAccessCards(
                        isDarkMode,
                        isDesktop,
                        isTablet,
                      );
                      return cards[index];
                    },
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // GLASS MORPHISM LIVE CLASS NOTIFICATION
  // ============================================
  Widget _buildLiveClassNotification(
    bool isDarkMode,
    bool isDesktop,
    bool isTablet,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return StreamBuilder<QuerySnapshot>(
      stream: _liveClassStream,
      builder: (context, snapshot) {
        final hasLiveClass = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final liveClassDoc = hasLiveClass ? snapshot.data!.docs.first : null;
        final classData = liveClassDoc != null
            ? liveClassDoc.data() as Map<String, dynamic>
            : null;

        return GestureDetector(
          onTap: hasLiveClass
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LiveClassScreen()),
                  );
                }
              : null,
          child: GlassmorphicContainer(
            width: double.infinity,
            height: isSmallScreen ? 100 : (isDesktop ? 120 : 110),
            borderRadius: 24,
            blur: 25,
            linearGradient: LinearGradient(
              colors: [
                (isDarkMode ? Colors.white : Colors.black).withValues(
                  alpha: 0.12,
                ),
                (isDarkMode ? Colors.white : Colors.black).withValues(
                  alpha: 0.06,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: 2,
            borderGradient: LinearGradient(
              colors: hasLiveClass
                  ? [
                      const Color(0xFF00F5FF).withValues(alpha: 0.6),
                      const Color(0xFF00D4FF).withValues(alpha: 0.3),
                    ]
                  : [
                      Colors.grey.withValues(alpha: 0.3),
                      Colors.grey.withValues(alpha: 0.1),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: hasLiveClass
                      ? [
                          const Color(0xFF00F5FF).withValues(alpha: 0.15),
                          const Color(0xFF00D4FF).withValues(alpha: 0.05),
                        ]
                      : [
                          Colors.grey.withValues(alpha: 0.05),
                          Colors.grey.withValues(alpha: 0.02),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // Animated Status Icon
                  _buildAnimatedStatusIcon(hasLiveClass, isDarkMode),

                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              hasLiveClass ? "CLASS OPEN" : "CLASS CLOSED",
                              style: TextStyle(
                                color: hasLiveClass
                                    ? const Color(0xFF00F5FF)
                                    : Colors.grey[400],
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (hasLiveClass)
                              Container(
                                margin: const EdgeInsets.only(left: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "LIVE",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (hasLiveClass && classData != null) ...[
                          Text(
                            classData['courseName'] ?? 'Class Session',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                              fontSize: isDesktop ? 15 : (isTablet ? 13 : 12),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '👨‍🏫 ${classData['lecturerName'] ?? 'Unknown'}',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                              fontSize: isDesktop ? 12 : (isTablet ? 11 : 10),
                            ),
                          ),
                        ] else
                          Text(
                            'No live class at the moment.\nCheck back later!',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                              fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Action Button
                  if (hasLiveClass)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00D4FF,
                            ).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.videocam,
                            color: Colors.black,
                            size: isDesktop ? 20 : 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Join Now',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: isDesktop ? 14 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // ANIMATED STATUS ICON
  // ============================================
  Widget _buildAnimatedStatusIcon(bool hasLiveClass, bool isDarkMode) {
    if (!hasLiveClass) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(
          Icons.sensors_off,
          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
          size: 28,
        ),
      );
    }

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Pulse Ring
            Container(
              width: 60 * value,
              height: 60 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(
                    0xFF00F5FF,
                  ).withValues(alpha: 0.3 * (1 - (value - 0.8) * 2.5)),
                  width: 2,
                ),
              ),
            ),
            // Middle Pulse Ring
            Container(
              width: 52 * value,
              height: 52 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(
                    0xFF00F5FF,
                  ).withValues(alpha: 0.2 * (1 - (value - 0.8) * 2.5)),
                  width: 1.5,
                ),
              ),
            ),
            // Main Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.sensors, color: Colors.white, size: 28),
            ),
          ],
        );
      },
    );
  }

  // Active Attendance Section
  Widget _buildActiveAttendanceSection(bool isDarkMode) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final activeSessions = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['courseId'] != null && user?.level != null;
        }).toList();

        if (activeSessions.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Colors.redAccent,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  "Active Attendance",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...activeSessions.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final sessionId = doc.id;
              final hasMarked = _markedSessions.contains(sessionId);
              final endTime = (data['endTime'] as Timestamp?)?.toDate();
              final isExpired =
                  endTime != null && endTime.isBefore(DateTime.now());

              if (hasMarked || isExpired) return const SizedBox.shrink();

              return _buildAttendanceCard(sessionId, data, isDarkMode);
            }),
          ],
        );
      },
    );
  }

  // Individual Attendance Card
  Widget _buildAttendanceCard(
    String sessionId,
    Map<String, dynamic> data,
    bool isDarkMode,
  ) {
    final endTime = (data['endTime'] as Timestamp).toDate();
    final remainingMinutes = endTime.difference(DateTime.now()).inMinutes;
    final remainingSeconds = endTime.difference(DateTime.now()).inSeconds % 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF00F5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'ATTENDANCE OPEN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data['lectureTitle'] ?? data['courseId'] ?? 'Class Session',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lecturer: ${data['lecturerName'] ?? 'Unknown'}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                'Attendance closes in: ${remainingMinutes}m ${remainingSeconds}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _markAttendance(sessionId, data),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF00D4FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'MARK ATTENDANCE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mark Attendance Method
  Future<void> _markAttendance(
    String sessionId,
    Map<String, dynamic> sessionData,
  ) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('📍 Getting your location...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final studentLocation = await LocationService.getCurrentLocation();

      final distance = await LocationService.calculateDistance(
        studentLocation.latitude,
        studentLocation.longitude,
        sessionData['latitude'],
        sessionData['longitude'],
      );

      final radius = (sessionData['radius'] ?? 100).toDouble();
      final status = distance <= radius ? 'present' : 'absent';

      await FirebaseFirestore.instance.collection('attendance_records').add({
        'sessionId': sessionId,
        'studentId': user?.uid,
        'studentName': user?.fullName,
        'latitude': studentLocation.latitude,
        'longitude': studentLocation.longitude,
        'distance': distance,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _markedSessions.add(sessionId);
        });
      }

      if (status == 'present') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✓ Attendance Marked Successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Distance: ${distance.toStringAsFixed(1)} meters (within ${radius.toStringAsFixed(0)}m radius)',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✗ Marked as Absent',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Distance: ${distance.toStringAsFixed(1)} meters (exceeds ${radius.toStringAsFixed(0)}m radius)',
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Build Quick Access Cards
  List<Widget> _buildQuickAccessCards(
    bool isDarkMode,
    bool isDesktop,
    bool isTablet,
  ) {
    final cards = [
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Chat',
        'color': const Color(0xFF00D4FF),
        'onTap': () => widget.onActionSelected(const ChatScreen()),
      },
      {
        'icon': Icons.assignment_outlined,
        'title': 'Assignments',
        'color': Colors.orange,
        'onTap': () => widget.onActionSelected(
          AssignmentsScreen(onBack: () => widget.onActionSelected(null)),
        ),
      },
      {
        'icon': Icons.notifications_none,
        'title': 'Notices',
        'color': Colors.purple,
        'onTap': () => widget.onActionSelected(
          NoticesScreen(onBack: () => widget.onActionSelected(null)),
        ),
      },
      {
        'icon': Icons.explore_outlined,
        'title': 'Discover',
        'color': Colors.teal,
        'onTap': () => widget.onActionSelected(const DiscoverScreen()),
      },
      {
        'icon': Icons.quiz,
        'title': 'AI Quiz',
        'color': Colors.pink,
        'onTap': () => widget.onActionSelected(const AITutorScreen()),
      },
      {
        'icon': Icons.video_library_outlined,
        'title': 'Recordings',
        'color': Colors.redAccent,
        'onTap': () => widget.onActionSelected(
          StudentAttendanceStatisticsScreen(
            onBack: () => widget.onActionSelected(null),
          ),
        ),
      },
    ];

    return cards
        .map(
          (card) => _glassCard(
            card['icon'] as IconData,
            card['title'] as String,
            card['color'] as Color,
            card['onTap'] as VoidCallback,
            isDarkMode,
            isDesktop,
            isTablet,
          ),
        )
        .toList();
  }

  Widget _glassCard(
    IconData icon,
    String title,
    Color accent,
    VoidCallback onTap,
    bool isDarkMode,
    bool isDesktop,
    bool isTablet,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: onTap,
        child: GlassmorphicContainer(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 16,
          blur: 15,
          linearGradient: LinearGradient(
            colors: [
              (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
              (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.05,
              ),
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
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 16 : (isTablet ? 14 : 12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: isDesktop ? 28 : (isTablet ? 26 : 24),
                    color: accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }
}

class StudentAttendanceStatisticsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const StudentAttendanceStatisticsScreen({super.key, required this.onBack});

  @override
  State<StudentAttendanceStatisticsScreen> createState() =>
      _StudentAttendanceStatisticsScreenState();
}

class _StudentAttendanceStatisticsScreenState
    extends State<StudentAttendanceStatisticsScreen> {
  late Future<List<_AttendancePoint>> _attendanceFuture;

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _loadAttendance();
  }

  Future<List<_AttendancePoint>> _loadAttendance() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('attendance_records')
        .where('studentId', isEqualTo: user.uid)
        .get();

    final points = snapshot.docs.map((doc) {
      final data = doc.data();
      final timestamp = data['timestamp'];
      return _AttendancePoint(
        status: data['status'] == 'present' ? 'present' : 'absent',
        date: timestamp is Timestamp ? timestamp.toDate() : null,
      );
    }).toList();
    points.sort((first, second) {
      final firstDate = first.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final secondDate = second.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return firstDate.compareTo(secondDate);
    });
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Statistics'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: FutureBuilder<List<_AttendancePoint>>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load your attendance statistics.',
                style: TextStyle(color: foreground),
              ),
            );
          }

          final records = snapshot.data ?? [];
          final present = records
              .where((item) => item.status == 'present')
              .length;
          final absent = records.length - present;
          final percentage = records.isEmpty ? 0 : present / records.length;

          if (records.isEmpty) {
            return Center(
              child: Text(
                'Your attendance statistics will appear here after you attend a class.',
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your attendance',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  percentage >= 0.75
                      ? 'You are keeping up well.'
                      : 'Your attendance is below 75%. Consider catching up.',
                  style: TextStyle(
                    color: percentage >= 0.75 ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'Attendance',
                        '${(percentage * 100).round()}%',
                        Colors.cyan,
                        foreground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Present',
                        '$present',
                        Colors.green,
                        foreground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Absent',
                        '$absent',
                        Colors.redAccent,
                        foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Recent attendance',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _AttendanceChartPainter(
                      records: records,
                      foreground: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot(Colors.green, 'Present', foreground),
                    const SizedBox(width: 20),
                    _legendDot(Colors.redAccent, 'Absent', foreground),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: foreground, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, Color foreground) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: foreground, fontSize: 12)),
      ],
    );
  }
}

class _AttendancePoint {
  final String status;
  final DateTime? date;

  const _AttendancePoint({required this.status, required this.date});
}

class _AttendanceChartPainter extends CustomPainter {
  final List<_AttendancePoint> records;
  final Color foreground;

  const _AttendanceChartPainter({
    required this.records,
    required this.foreground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartRecords = records.length > 12
        ? records.sublist(records.length - 12)
        : records;
    const bottomPadding = 28.0;
    final chartHeight = size.height - bottomPadding;
    final axisPaint = Paint()
      ..color = foreground.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );

    final barWidth = size.width / (chartRecords.length * 1.7);
    final gap = barWidth * 0.7;
    final barPaint = Paint();

    for (var index = 0; index < chartRecords.length; index++) {
      final record = chartRecords[index];
      final x = index * (barWidth + gap) + gap / 2;
      barPaint.color = record.status == 'present'
          ? Colors.green
          : Colors.redAccent;
      final barTop = record.status == 'present'
          ? chartHeight * 0.18
          : chartHeight * 0.58;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, barTop, barWidth, chartHeight - barTop),
          const Radius.circular(6),
        ),
        barPaint,
      );
      final label = record.date == null
          ? '-'
          : '${record.date!.day}/${record.date!.month}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: foreground, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceChartPainter oldDelegate) =>
      oldDelegate.records != records || oldDelegate.foreground != foreground;
}
