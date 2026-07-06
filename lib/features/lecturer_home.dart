import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'live_class_screen.dart';
import 'notices_screen.dart';
import 'assignments_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'schedule_class_screen.dart';
import 'attendance_monitor_screen.dart';
import 'create_attendance_screen.dart';
import '../services/student_id_management_screen.dart';

class LecturerHome extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const LecturerHome({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<LecturerHome> createState() => _LecturerHomeState();
}

class _LecturerHomeState extends State<LecturerHome>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;

  Widget? _activeSubPage;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      LecturerDashboardContent(
        toggleTheme: widget.toggleTheme,
        onActionSelected: _setSubPage,
      ),
      const ChatScreen(),
      const SizedBox(), // Live handled by floating button
      const DiscoverScreen(),
      ProfileScreen(toggleTheme: widget.toggleTheme),
    ];
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animationController.forward();
  }

  void _setSubPage(Widget? page) {
    setState(() {
      _activeSubPage = page;
      if (page != null) _currentIndex = 0;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      // Ensures the body shrinks to make room for the keyboard
      resizeToAvoidBottomInset: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentIndex == 0 && _activeSubPage != null
            ? _activeSubPage!
            : _pages[_currentIndex],
      ),
      // Hide the bottom nav when typing to give the flexible text box more room
      bottomNavigationBar: isKeyboardVisible
          ? const SizedBox.shrink()
          : _buildModernBottomNav(isDarkMode),
      floatingActionButton: isKeyboardVisible
          ? null
          : FloatingActionButton(
              onPressed: () => _setSubPage(
                LiveClassScreen(onLeave: () => _setSubPage(null)),
              ),
              backgroundColor: Colors.redAccent,
              elevation: 10,
              child: const Icon(Icons.live_tv, color: Colors.white, size: 32),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildModernBottomNav(bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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
          _navItem(Icons.home_outlined, Icons.home, "Home", 0, isDarkMode),
          _navItem(
            Icons.chat_bubble_outline,
            Icons.chat_bubble,
            "Chat",
            1,
            isDarkMode,
          ),
          const SizedBox(width: 60),
          _navItem(
            Icons.explore_outlined,
            Icons.explore,
            "Discover",
            3,
            isDarkMode,
          ),
          _navItem(
            Icons.person_outline,
            Icons.person,
            "Profile",
            4,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData outlinedIcon,
    IconData filledIcon,
    String label,
    int index,
    bool isDarkMode,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _activeSubPage = null; // Reset subpage when switching tabs
        });
        _animationController.reset();
        _animationController.forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? Colors.redAccent.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected
                  ? Colors.redAccent
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Colors.redAccent
                    : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Lecturer Dashboard Content ====================
class LecturerDashboardContent extends StatefulWidget {
  final VoidCallback toggleTheme;
  final Function(Widget?) onActionSelected;

  const LecturerDashboardContent({
    super.key,
    required this.toggleTheme,
    required this.onActionSelected,
  });

  @override
  State<LecturerDashboardContent> createState() =>
      _LecturerDashboardContentState();
}

class _LecturerDashboardContentState extends State<LecturerDashboardContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                ? const Color.fromARGB(
                    255,
                    213,
                    194,
                    194,
                  ).withValues(alpha: 0.7)
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
                  // Header Section
                  _buildHeader(user, isDarkMode, isDesktop, isTablet),
                  const SizedBox(height: 25),

                  // Stats Cards
                  _buildStatsSection(user, isDarkMode),
                  const SizedBox(height: 30),

                  // Quick Actions Section
                  _buildQuickActionsHeader(isDarkMode, isDesktop, isTablet),
                  const SizedBox(height: 12),
                  _buildQuickActionsGrid(isDarkMode, isDesktop, isTablet),
                  const SizedBox(height: 25),

                  // Upcoming Scheduled Classes
                  _buildUpcomingClassesSection(isDarkMode),
                  const SizedBox(height: 25),

                  // Recent Activity Section
                  _buildRecentActivitySection(isDarkMode),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(user, bool isDarkMode, bool isDesktop, bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: isDesktop ? 16 : (isTablet ? 14 : 13),
                ),
              ),
              Text(
                user?.fullName ?? "Lecturer",
                style: TextStyle(
                  fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.redAccent, Colors.red.shade700],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Level ${user?.level} • Lecturer",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            IconButton(
              onPressed: widget.toggleTheme,
              icon: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: isDesktop ? 45 : (isTablet ? 40 : 35),
                backgroundColor: Colors.redAccent,
                backgroundImage: user?.profilePicture != null
                    ? NetworkImage(user!.profilePicture!)
                    : null,
                child: user?.profilePicture == null
                    ? Text(
                        user?.fullName[0].toUpperCase() ?? "L",
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSection(user, bool isDarkMode) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOut,
            ),
          ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 500;
          return Row(
            children: [
              Expanded(
                child: _statCard(
                  "Total Students",
                  _buildStudentCountStream(user),
                  Icons.people,
                  Colors.blue,
                  isDarkMode,
                  isSmallScreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  "Notices",
                  _buildNoticeCountStream(user),
                  Icons.notifications,
                  Colors.orange,
                  isDarkMode,
                  isSmallScreen,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentCountStream(user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('level', isEqualTo: user?.level)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("...");
        return Text(snapshot.data!.docs.length.toString());
      },
    );
  }

  Widget _buildNoticeCountStream(user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .where('lecturerId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("...");
        return Text(snapshot.data!.docs.length.toString());
      },
    );
  }

  Widget _statCard(
    String title,
    Widget valueWidget,
    IconData icon,
    Color color,
    bool isDarkMode,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: isSmallScreen ? 18 : 20, color: color),
              ),
              valueWidget,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsHeader(
    bool isDarkMode,
    bool isDesktop,
    bool isTablet,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(
    bool isDarkMode,
    bool isDesktop,
    bool isTablet,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final crossAxisCount = cardWidth < 500 ? 2 : (cardWidth < 800 ? 3 : 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.2,
          ),
          itemCount: 7,
          itemBuilder: (context, index) {
            final actions = _buildQuickActionCards(
              isDarkMode,
              isDesktop,
              isTablet,
            );
            return actions[index];
          },
        );
      },
    );
  }

  List<Widget> _buildQuickActionCards(
    bool isDarkMode,
    bool isDesktop,
    bool isTablet,
  ) {
    final actions = [
      {
        'icon': Icons.schedule_outlined,
        'title': 'Schedule Class',
        'color': Colors.redAccent,
        'onTap': () => widget.onActionSelected(const ScheduleClassScreen()),
      },

      {
        'icon': Icons.qr_code_scanner,
        'title': 'Start Attendance',
        'color': Colors.purple,
        'onTap': () => widget.onActionSelected(const CreateAttendanceScreen()),
      },
      {
        'icon': Icons.live_tv,
        'title': 'Start Live',
        'color': Colors.orange,
        'onTap': () => widget.onActionSelected(
          LiveClassScreen(onLeave: () => widget.onActionSelected(null)),
        ),
      },
      {
        'icon': Icons.notifications_none,
        'title': 'Post Notice',
        'color': Colors.blue,
        'onTap': () => widget.onActionSelected(
          NoticesScreen(onBack: () => widget.onActionSelected(null)),
        ),
      },
      {
        'icon': Icons.verified_user,
        'title': 'Student IDs',
        'color': Colors.indigo,
        'onTap': () => widget.onActionSelected(
          StudentIdManagementScreen(
            onBack: () => widget.onActionSelected(null),
          ),
        ),
      },
      {
        'icon': Icons.assignment_outlined,
        'title': 'Assignment',
        'color': Colors.green,
        'onTap': () => widget.onActionSelected(
          AssignmentsScreen(onBack: () => widget.onActionSelected(null)),
        ),
      },
      {
        'icon': Icons.people_outline,
        'title': 'View Students',
        'color': Colors.teal,
        'onTap': () => _showStudentsList(),
      },
    ];

    return actions
        .map(
          (action) => _glassCard(
            action['icon'] as IconData,
            action['title'] as String,
            action['color'] as Color,
            action['onTap'] as VoidCallback,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(isDesktop ? 18 : (isTablet ? 16 : 14)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.08,
              ),
              (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.04,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.2),
                    accent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: isDesktop ? 30 : (isTablet ? 28 : 26),
                color: accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: isDesktop ? 14 : (isTablet ? 13 : 12),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectClassDialog() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.redAccent.withValues(alpha: 0.1),
                Colors.purple.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 50,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select Class for Attendance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose which class you want to take attendance for',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.maxFinite,
                height: 300,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('scheduled_classes')
                      .where('lecturerId', isEqualTo: user?.uid)
                      .orderBy('scheduledDate', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.class_, size: 50, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No classes scheduled yet'),
                            SizedBox(height: 8),
                            Text(
                              'Please schedule a class first',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    final classes = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final doc = classes[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final className = data['title'] ?? 'Untitled Class';
                        final scheduledDate =
                            (data['scheduledDate'] as Timestamp?)?.toDate();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.class_,
                                  color: Colors.redAccent,
                                ),
                              ),
                              title: Text(
                                className,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: scheduledDate != null
                                  ? Text(
                                      'Scheduled: ${_formatDateTime(scheduledDate)}',
                                    )
                                  : null,
                              trailing: const Icon(
                                Icons.arrow_forward,
                                color: Colors.redAccent,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LecturerAttendanceScreen(
                                      sessionId: doc.id,
                                      courseName: 'Course',
                                      lectureTitle: className,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScheduleClassScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Schedule New'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentsList() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withValues(alpha: 0.1),
                Colors.purple.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, size: 50, color: Colors.blue),
              const SizedBox(height: 12),
              const Text(
                'Enrolled Students',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.maxFinite,
                height: 400,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'student')
                      .where('level', isEqualTo: user?.level)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people, size: 50, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No students enrolled yet'),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final studentDoc = snapshot.data!.docs[index];
                        final student =
                            studentDoc.data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withValues(
                                alpha: 0.2,
                              ),
                              child: Text(
                                (student['fullName']?[0] ?? 'S').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              student['fullName'] ?? 'Unknown Student',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('Level: ${student['level']}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingClassesSection(bool isDarkMode) {
    final user = Provider.of<AuthService>(context).currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_today,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Upcoming Scheduled Classes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('scheduled_classes')
              .where('lecturerId', isEqualTo: user?.uid)
              .orderBy('scheduledDate', descending: false)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isDarkMode ? Colors.white : Colors.black).withValues(
                        alpha: 0.08,
                      ),
                      (isDarkMode ? Colors.white : Colors.black).withValues(
                        alpha: 0.04,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        "No scheduled classes yet",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScheduleClassScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text("Schedule a Class"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildClassCard(data, isDarkMode, doc.id);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildClassCard(
    Map<String, dynamic> data,
    bool isDarkMode,
    String classId,
  ) {
    final scheduledDate =
        (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isPast = scheduledDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.08),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPast
              ? Colors.grey.withValues(alpha: 0.3)
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPast
                  ? Colors.grey.withValues(alpha: 0.2)
                  : Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.video_library,
              color: isPast ? Colors.grey : Colors.redAccent,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? 'Untitled Class',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['description'] ?? 'No description',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(scheduledDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPast ? Colors.grey : Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!isPast)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "Upcoming",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!isPast)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.purple),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LecturerAttendanceScreen(
                      sessionId: classId,
                      courseName: 'Course',
                      lectureTitle: data['title'] ?? 'Class',
                    ),
                  ),
                );
              },
              tooltip: 'Take Attendance',
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(bool isDarkMode) {
    final user = Provider.of<AuthService>(context).currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.history,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Recent Activity",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('activities')
              .where('lecturerId', isEqualTo: user?.uid)
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isDarkMode ? Colors.white : Colors.black).withValues(
                        alpha: 0.08,
                      ),
                      (isDarkMode ? Colors.white : Colors.black).withValues(
                        alpha: 0.04,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        "No recent activities",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Activities will appear when you schedule classes,\npost notices, or start live sessions",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _activityItem(
                  data['title'] ?? 'Activity',
                  data['description'] ?? '',
                  _getActivityIcon(data['type']),
                  _getActivityColor(data['type']),
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  isDarkMode,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _activityItem(
    String title,
    String description,
    IconData icon,
    Color color,
    DateTime timestamp,
    bool isDarkMode,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.05),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatTimeAgo(timestamp),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'class_scheduled':
        return Icons.calendar_today;
      case 'notice_posted':
        return Icons.notifications;
      case 'assignment_posted':
        return Icons.assignment;
      case 'live_started':
        return Icons.live_tv;
      case 'attendance_started':
        return Icons.qr_code_scanner;
      default:
        return Icons.fiber_new;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'class_scheduled':
        return Colors.redAccent;
      case 'notice_posted':
        return Colors.blue;
      case 'assignment_posted':
        return Colors.orange;
      case 'live_started':
        return Colors.green;
      case 'attendance_started':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  String _formatDateTime(DateTime date) {
    return "${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _formatTimeAgo(DateTime dateTime) {
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
