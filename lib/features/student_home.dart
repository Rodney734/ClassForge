import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'chat_screen.dart';
import 'live_class_screen.dart';
import 'notices_screen.dart';
import 'assignments_screen.dart';
import 'discover_screen.dart'; // DiscoverScreen is used in _pages
import 'profile_screen.dart';
import 'ai_tutor_screen.dart';

class StudentHome extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const StudentHome({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

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
      StudentDashboardContent(
        toggleTheme: widget.toggleTheme,
        onActionSelected: _setSubPage,
      ),
      const ChatScreen(),
      const DiscoverScreen(),
      ProfileScreen(toggleTheme: widget.toggleTheme),
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
    final isDarkMode = widget.isDarkMode;
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
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
    return Container(
      height: 75,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey[900]!.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_outlined, Icons.home, 0, isDarkMode),
          _navItem(Icons.chat_bubble_outline, Icons.chat_bubble, 1, isDarkMode),
          const SizedBox(width: 60), // Placeholder for FAB
          _navItem(
            Icons.explore_outlined,
            Icons.explore,
            2,
            isDarkMode,
          ), // Stays at index 2
          _navItem(
            Icons.person_outline,
            Icons.person,
            3,
            isDarkMode,
          ), // Corrected to index 3
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
        // If we tap on the home icon, we might want to clear the sub-page
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
  final VoidCallback toggleTheme;
  final Function(Widget?) onActionSelected;

  const StudentDashboardContent({
    super.key,
    required this.toggleTheme,
    required this.onActionSelected,
  });

  @override
  State<StudentDashboardContent> createState() =>
      _StudentDashboardContentState();
}

class _StudentDashboardContentState extends State<StudentDashboardContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Set<String> _markedSessions = {}; // Track sessions student has already marked

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    _loadStudentAttendanceRecords();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Load attendance records to prevent double marking
  Future<void> _loadStudentAttendanceRecords() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final records = await FirebaseFirestore.instance
        .collection('attendance_records')
        .where('studentId', isEqualTo: user.uid)
        .get();

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

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const NetworkImage(
            "https://images.pexels.com/photos/256468/pexels-photo-256468.jpeg?auto=compress&cs=tinysrgb&w=1600",
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            isDarkMode
                ? Colors.black.withOpacity(0.6)
                : Colors.white.withOpacity(0.3),
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
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.85),
                  ]
                : [
                    Colors.white.withOpacity(0.85),
                    Colors.white.withOpacity(0.95),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: isDesktop ? 40 : (isTablet ? 30 : 20),
              right: isDesktop ? 40 : (isTablet ? 30 : 20),
              top: isDesktop ? 40 : (isTablet ? 30 : 20),
              bottom: 100,
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
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                              fontSize: isDesktop ? 16 : (isTablet ? 14 : 12),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Theme Toggle Switch
                      Switch(
                        value: isDarkMode,
                        onChanged: (value) => widget.toggleTheme(),
                        activeTrackColor: const Color(
                          0xFF00F5FF,
                        ).withOpacity(0.5),
                        activeColor: const Color(0xFF00F5FF),
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade200,
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() {
                          // This is a placeholder for navigating to profile
                          // In a real app, you'd call a method to switch tabs
                        }),
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

                  const SizedBox(height: 30),

                  // Today's Classes Section
                  _buildTodayClassesSection(
                    isDarkMode,
                    user,
                    isDesktop,
                    isTablet,
                  ),

                  const SizedBox(height: 30),

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

                  const SizedBox(height: 12),

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
        ),
      ),
    );
  }

  // Today's Classes Section
  Widget _buildTodayClassesSection(
    bool isDarkMode,
    user,
    bool isDesktop,
    bool isTablet,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.15,
          ),
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
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.today,
                  color: Color(0xFF00D4FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Today's Classes",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Today's class card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D4FF).withValues(alpha: 0.15),
                  const Color(0xFF00F5FF).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.computer,
                    color: Color(0xFF00D4FF),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Mobile Application Development",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Level ${user?.level} • Dr. Adebayo • 10:30 AM",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Waiting",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
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

  // Active Attendance Section
  Widget _buildActiveAttendanceSection(bool isDarkMode) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('status', isEqualTo: 'active')
          .snapshots(),
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

    // Show loading
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
      // Get student's current location
      final studentLocation = await LocationService.getCurrentLocation();

      // Calculate distance from lecturer
      final distance = await LocationService.calculateDistance(
        studentLocation.latitude,
        studentLocation.longitude,
        sessionData['latitude'],
        sessionData['longitude'],
      );

      // Determine status based on radius
      final radius = (sessionData['radius'] ?? 100).toDouble();
      final status = distance <= radius ? 'present' : 'absent';

      // Save attendance record
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

      // Add to marked sessions
      if (mounted) {
        setState(() {
          _markedSessions.add(sessionId);
        });
      }

      // Show result based on status
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
        'onTap': () {},
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 16 : (isTablet ? 14 : 12)),
        decoration: BoxDecoration(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.06,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isDarkMode ? Colors.white : Colors.black).withValues(
              alpha: 0.1,
            ),
          ),
        ),
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
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }
}
