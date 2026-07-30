import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'attendance_monitor_screen.dart';

class CreateAttendanceScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CreateAttendanceScreen({super.key, this.onBack});

  @override
  State<CreateAttendanceScreen> createState() => _CreateAttendanceScreenState();
}

class _CreateAttendanceScreenState extends State<CreateAttendanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _courseNameController = TextEditingController();
  final TextEditingController _lectureTitleController = TextEditingController();
  int _durationMinutes = 10;
  double _radius = 100;
  bool _isLoading = false;

  @override
  void dispose() {
    _courseNameController.dispose();
    _lectureTitleController.dispose();
    super.dispose();
  }

  Future<void> _startAttendance() async {
    if (!_formKey.currentState!.validate()) return;
    if (_courseNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a course')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;

      // Get lecturer's current location
      final lecturerLocation = await LocationService.getCurrentLocation();

      // Calculate end time
      final endTime = DateTime.now().add(Duration(minutes: _durationMinutes));

      // Create attendance session in Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .add({
            'courseId': _courseNameController.text.trim(),
            'courseName': _courseNameController.text.trim(),
            'lectureTitle': _lectureTitleController.text.trim(),
            'lecturerId': user?.uid,
            'lecturerName': user?.fullName,
            'startTime': FieldValue.serverTimestamp(),
            'endTime': Timestamp.fromDate(endTime),
            'latitude': lecturerLocation.latitude,
            'longitude': lecturerLocation.longitude,
            'radius': _radius,
            'status': 'active',
          });

      // Add to activities
      await FirebaseFirestore.instance.collection('activities').add({
        'type': 'attendance_started',
        'title': 'Attendance Started',
        'description':
            'You started attendance for ${_courseNameController.text.trim()} - ${_lectureTitleController.text.trim()}',
        'lecturerId': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Navigate to monitoring screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LecturerAttendanceScreen(
              sessionId: docRef.id,
              courseName: _courseNameController.text.trim(),
              lectureTitle: _lectureTitleController.text.trim(),
              onSessionEnded: widget.onBack,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Start Attendance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            // Removed the gradient to allow global background to show
          ),
        ),
      ),
      body: SafeArea(
        // This SafeArea will now directly sit on the transparent Scaffold
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent.withValues(alpha: 0.2),
                        Colors.purple.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.redAccent,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GPS Attendance',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Students will be marked based on their location',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Course Selection
                _buildGlassCard(
                  title: 'Course Name',
                  icon: Icons.school_outlined,
                  child: TextFormField(
                    controller: _courseNameController,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g., Computer Science 101',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Please enter course name'
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // Lecture Title
                _buildGlassCard(
                  title: 'Lecture Title',
                  icon: Icons.title,
                  child: TextFormField(
                    controller: _lectureTitleController,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g., Introduction to Flutter',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Please enter lecture title'
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // Duration Selection
                _buildGlassCard(
                  title: 'Attendance Duration',
                  icon: Icons.timer,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _durationButton(5, '5 min', isDarkMode),
                          const SizedBox(width: 12),
                          _durationButton(10, '10 min', isDarkMode),
                          const SizedBox(width: 12),
                          _durationButton(15, '15 min', isDarkMode),
                          const SizedBox(width: 12),
                          _durationButton(30, '30 min', isDarkMode),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Radius Selection
                _buildGlassCard(
                  title: 'Attendance Radius',
                  icon: Icons.radar,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_radius.toStringAsFixed(0)} meters',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _radius <= 100 ? 'Tight Range' : 'Wide Range',
                              style: TextStyle(
                                fontSize: 10,
                                color: _radius <= 100
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _radius,
                        min: 50,
                        max: 500,
                        divisions: 9,
                        label: '${_radius.toStringAsFixed(0)} meters',
                        onChanged: (value) {
                          setState(() {
                            _radius = value;
                          });
                        },
                        activeColor: Colors.redAccent,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Students must be within this radius to be marked present',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Start Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.redAccent,
                        Color.fromARGB(255, 156, 52, 52),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _startAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'START ATTENDANCE',
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
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.redAccent.withValues(alpha: 0.2)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _durationButton(int minutes, String label, bool isDarkMode) {
    final isSelected = _durationMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _durationMinutes = minutes),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Colors.redAccent,
                      Color.fromARGB(255, 146, 70, 70),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.redAccent
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
