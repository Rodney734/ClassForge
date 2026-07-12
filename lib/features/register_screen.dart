import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:glassmorphism/glassmorphism.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _lecturerCodeController = TextEditingController();
  final _levelController = TextEditingController();

  String _role = 'student';
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  final bool _isCheckingCode = false;
  final bool _isCodeValid = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    _lecturerCodeController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate student ID
    if (_role == 'student' && _studentIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Student ID'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    String? error = await auth.register(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      role: _role,
      level: int.tryParse(_levelController.text.trim()) ?? 1,
      studentId: _role == 'student' ? _studentIdController.text.trim() : null,
      lecturerCode: _role == 'lecturer'
          ? _lecturerCodeController.text.trim()
          : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      // On success, go back to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! You can now log in.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        color: isDarkMode
            ? const Color.fromARGB(255, 43, 42, 42)
            : const Color.fromARGB(255, 166, 163, 163),
        child: SafeArea(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00F5FF,
                                ).withValues(alpha: 0.2),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                              ),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1,
                              size: 32,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'Join the ClassForge community',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Glass Card
                        GlassmorphicContainer(
                          width: double.infinity,
                          height: _role == 'student' ? 580 : 640,
                          blur: 20,
                          borderRadius: 24,
                          linearGradient: LinearGradient(
                            colors: [
                              (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.12),
                              (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: 1,
                          borderGradient: LinearGradient(
                            colors: [
                              (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.2),
                              (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.2),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Role Selector
                              _buildRoleSelector(isDarkMode),
                              const SizedBox(height: 20),

                              // Full Name
                              _buildGlassTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.person_outline,
                                isDarkMode: isDarkMode,
                                validator: (value) => value!.isEmpty
                                    ? 'Please enter your full name'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Email
                              _buildGlassTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                icon: Icons.email_outlined,
                                isDarkMode: isDarkMode,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) =>
                                    value!.isEmpty || !value.contains('@')
                                    ? 'Please enter a valid email'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildGlassTextField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock_outline,
                                isDarkMode: isDarkMode,
                                isPassword: true,
                                validator: (value) => value!.length < 6
                                    ? 'Password must be at least 6 characters'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Student ID (only for students)
                              if (_role == 'student')
                                _buildGlassTextField(
                                  controller: _studentIdController,
                                  label: 'Student ID',
                                  icon: Icons.badge_outlined,
                                  isDarkMode: isDarkMode,
                                  validator: (value) => value!.isEmpty
                                      ? 'Please enter your Student ID'
                                      : null,
                                ),

                              // Lecturer Code (only for lecturers)
                              if (_role == 'lecturer') ...[
                                _buildGlassTextField(
                                  controller: _lecturerCodeController,
                                  label: 'Lecturer Registration Code',
                                  icon: Icons.vpn_key,
                                  isDarkMode: isDarkMode,
                                  validator: (value) => value!.isEmpty
                                      ? 'Please enter your registration code'
                                      : null,
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Level
                              _buildGlassTextField(
                                controller: _levelController,
                                label: 'Level (e.g., 4 for Level 400)',
                                icon: Icons.school_outlined,
                                isDarkMode: isDarkMode,
                                keyboardType: TextInputType.number,
                                validator: (value) => value!.isEmpty
                                    ? 'Please enter your level'
                                    : null,
                              ),
                              const SizedBox(height: 24),

                              // Register Button
                              Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00F5FF),
                                      Color(0xFF00D4FF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00F5FF,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.black,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text(
                                          "CREATE ACCOUNT",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: const Color(0xFF00F5FF),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Color(0xFF00F5FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child: Row(
        children: [
          _roleButton('student', 'Student', Icons.school_outlined, isDarkMode),
          const SizedBox(width: 8),
          _roleButton(
            'lecturer',
            'Lecturer',
            Icons.person_search_outlined,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _roleButton(
    String role,
    String label,
    IconData icon,
    bool isDarkMode,
  ) {
    final isSelected = _role == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.black
                    : (isDarkMode ? Colors.white60 : Colors.black54),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (isDarkMode ? Colors.white60 : Colors.black54),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDarkMode,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.05,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        keyboardType: keyboardType,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white60 : Colors.black54,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF00F5FF), size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                  },
                )
              : suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        validator: validator,
      ),
    );
  }
}
