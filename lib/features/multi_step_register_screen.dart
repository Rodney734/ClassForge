import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/academic_structure_service.dart';
import '../models/academic_year_model.dart';
import '../models/academic_field_model.dart';
import '../models/bachelor_model.dart';

class MultiStepRegisterScreen extends StatefulWidget {
  const MultiStepRegisterScreen({super.key});

  @override
  State<MultiStepRegisterScreen> createState() =>
      _MultiStepRegisterScreenState();
}

class _MultiStepRegisterScreenState extends State<MultiStepRegisterScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _role = 'student';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Step 1: Personal Information
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _lecturerCodeController = TextEditingController();

  // Step 2: Academic Field(s)
  List<AcademicField> _availableFields = [];
  bool _isLoadingFields = true;
  String? _academicFieldsError;
  String? _selectedFieldId;
  final List<String> _selectedFieldIds = [];

  // Step 3: Bachelor Programme(s)
  List<Bachelor> _availableBachelors = [];
  String? _selectedBachelorId;

  // Academic Year
  List<AcademicYear> _availableYears = [];
  AcademicYear? _selectedYear;
  final List<String> _selectedTeachingYearIds = [];

  // Services
  late AcademicStructureService _academicService;

  // Step Labels
  final List<String> _stepLabels = [
    'Personal Info',
    'Academic Year',
    'Academic Field',
    'Degree Programme',
  ];

  final List<IconData> _stepIcons = [
    Icons.person_outline,
    Icons.calendar_month_outlined,
    Icons.school_outlined,
    Icons.assignment_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _academicService = AcademicStructureService();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _loadAcademicYears();
    _loadAcademicFields();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    _lecturerCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAcademicYears() async {
    final years = await _academicService.getAcademicYears();
    if (mounted) {
      setState(() {
        _availableYears = years;
      });
    }
  }

  Future<void> _loadAcademicFields() async {
    try {
      final fields = await _academicService.getAcademicFields();
      if (mounted) {
        setState(() {
          _availableFields = fields;
          _academicFieldsError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _academicFieldsError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFields = false);
      }
    }
  }

  Future<void> _loadBachelors() async {
    if (_role == 'student' && _selectedFieldId != null) {
      final bachelors = await _academicService.getBachelorsByField(
        _selectedFieldId!,
      );
      if (mounted) {
        setState(() => _availableBachelors = bachelors);
      }
    } else if (_role == 'lecturer' && _selectedFieldIds.isNotEmpty) {
      final allBachelors = <Bachelor>[];
      for (final fieldId in _selectedFieldIds) {
        final bachelors = await _academicService.getBachelorsByField(fieldId);
        allBachelors.addAll(bachelors);
      }
      if (mounted) {
        setState(() => _availableBachelors = allBachelors);
      }
    }
  }

  Future<void> _completeRegistration() async {
    final missingField = _missingRequiredField();
    if (missingField != null) {
      await _showMissingFieldDialog(missingField);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);

      String? error = await auth.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _role,
        level: _selectedYear?.level ?? _selectedYearForRegistration?.level ?? 1,
        studentId: _role == 'student' ? _studentIdController.text.trim() : null,
        academicYearId: _selectedYearForRegistration?.id,
        academicFieldId: _role == 'student'
            ? _selectedFieldId
            : (_selectedFieldIds.isNotEmpty ? _selectedFieldIds.first : null),
        bachelorId: _selectedBachelorId,
        lecturerCode: _role == 'lecturer'
            ? _lecturerCodeController.text.trim()
            : null,
        teachingYearIds: _selectedTeachingYearIds,
      );

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful. Please log in.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _missingRequiredField() {
    if (_nameController.text.trim().isEmpty) return 'Full Name';
    if (_emailController.text.trim().isEmpty) return 'Email Address';
    if (_passwordController.text.isEmpty) return 'Password';
    if (_passwordController.text.length < 6) {
      return 'Password (at least 6 characters)';
    }
    if (_role == 'student' && _studentIdController.text.trim().isEmpty) {
      return 'Student ID';
    }
    if (_role == 'lecturer' && _lecturerCodeController.text.trim().isEmpty) {
      return 'Lecturer Code';
    }
    if (_role == 'student' && _selectedFieldId == null) {
      return 'Academic Field';
    }
    if (_role == 'lecturer' && _selectedFieldIds.isEmpty) {
      return 'Academic Field';
    }
    if (_role == 'student' && _selectedYear == null) {
      return 'Academic Year';
    }
    if (_role == 'lecturer' && _selectedTeachingYearIds.isEmpty) {
      return 'Teaching Year';
    }
    if (_selectedBachelorId == null) return 'Degree Programme';
    return null;
  }

  AcademicYear? get _selectedYearForRegistration {
    if (_role == 'student') return _selectedYear;
    if (_selectedTeachingYearIds.isEmpty) return null;
    return _availableYears.firstWhere(
      (year) => year.id == _selectedTeachingYearIds.first,
      orElse: () => _availableYears.first,
    );
  }

  Future<void> _showMissingFieldDialog(String fieldName) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missing required field'),
        content: Text('Please complete "$fieldName" before continuing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _nextStep() async {
    if (_currentStep == 1 &&
        (_role == 'student'
            ? _selectedYear == null
            : _selectedTeachingYearIds.isEmpty)) {
      await _showMissingFieldDialog(
        _role == 'student' ? 'Academic Year' : 'Teaching Year',
      );
      return;
    }

    if (_currentStep == 2) {
      if ((_role == 'student' && _selectedFieldId == null) ||
          (_role == 'lecturer' && _selectedFieldIds.isEmpty)) {
        await _showMissingFieldDialog('Academic Field');
        return;
      }
      await _loadBachelors();
    }

    if (!mounted) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF00F5FF);
    const totalSteps = 4;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? const [Color(0xFF071B30), Color(0xFF0D2A4A)]
                    : const [Color(0xFF1A3A6B), Color(0xFF4A7CC7)],
              ),
            ),
          ),
          // Decorative Blobs
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header with Progress
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Close Button
                        Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Step Indicator
                              ...List.generate(totalSteps, (index) {
                                final isActive = index <= _currentStep;
                                final isCurrent = index == _currentStep;
                                return Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive
                                              ? accentColor
                                              : Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                          border: isCurrent
                                              ? Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                )
                                              : null,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            _stepIcons[index],
                                            color: isActive
                                                ? Colors.black
                                                : Colors.white54,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      if (index < totalSteps - 1)
                                        Expanded(
                                          child: Container(
                                            height: 2,
                                            color: isActive
                                                ? accentColor
                                                : Colors.white.withValues(
                                                    alpha: 0.2,
                                                  ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _stepLabels[_currentStep],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_currentStep + 1}/$totalSteps',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Page Content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) =>
                          setState(() => _currentStep = index),
                      children: [
                        _buildPersonalInfoStep(isDarkMode, accentColor),
                        _buildAcademicYearStep(isDarkMode, accentColor),
                        _buildFieldSelectionStep(isDarkMode, accentColor),
                        _buildBachelorSelectionStep(isDarkMode, accentColor),
                      ],
                    ),
                  ),
                  // Navigation Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: !_isLoading
                                    ? () {
                                        if (_currentStep > 0) {
                                          _previousStep();
                                        } else {
                                          Navigator.pushNamedAndRemoveUntil(
                                            context,
                                            '/login',
                                            (route) => false,
                                          );
                                        }
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Back',
                                      style: TextStyle(
                                        color: !_isLoading
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isLoading
                                    ? null
                                    : (_currentStep == 3
                                          ? _completeRegistration
                                          : _nextStep),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black,
                                            ),
                                          )
                                        : Text(
                                            _currentStep == 3
                                                ? 'Complete'
                                                : 'Continue',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // ==================== STEP BUILDERS ====================

  Widget _buildPersonalInfoStep(bool isDarkMode, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                _buildRoleSelector(isDarkMode),
                const SizedBox(height: 16),
                _buildGlassTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),
                _buildGlassTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  isDarkMode: isDarkMode,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildGlassTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isDarkMode: isDarkMode,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                if (_role == 'student')
                  _buildGlassTextField(
                    controller: _studentIdController,
                    label: 'Student ID',
                    icon: Icons.badge_outlined,
                    isDarkMode: isDarkMode,
                  )
                else
                  _buildGlassTextField(
                    controller: _lecturerCodeController,
                    label: 'Lecturer Code',
                    icon: Icons.vpn_key,
                    isDarkMode: isDarkMode,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldSelectionStep(bool isDarkMode, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _role == 'student'
                      ? 'Choose Your Field'
                      : 'Choose Your Fields',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _role == 'student'
                      ? 'Select your academic field of study'
                      : 'Select the fields you teach',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                _isLoadingFields
                    ? const Center(child: CircularProgressIndicator())
                    : _academicFieldsError != null
                    ? Center(
                        child: Text(
                          'Unable to load academic fields. Please try again.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _availableFields.isEmpty
                    ? const Center(
                        child: Text(
                          'No academic fields are available yet.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        children: [
                          for (final field in _availableFields)
                            _buildSelectionTile(
                              isDarkMode,
                              accentColor,
                              field.name,
                              _role == 'student'
                                  ? _selectedFieldId == field.id
                                  : _selectedFieldIds.contains(field.id),
                              () {
                                setState(() {
                                  if (_role == 'student') {
                                    _selectedFieldId = field.id;
                                    _selectedBachelorId = null;
                                    _availableBachelors = [];
                                  } else {
                                    if (_selectedFieldIds.contains(field.id)) {
                                      _selectedFieldIds.remove(field.id);
                                    } else {
                                      _selectedFieldIds.add(field.id);
                                    }
                                    _availableBachelors = [];
                                  }
                                });
                              },
                              isMultiSelect: _role == 'lecturer',
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicYearStep(bool isDarkMode, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: _buildAcademicYearSelection(isDarkMode, accentColor),
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicYearSelection(bool isDarkMode, Color accentColor) {
    final selectedIds = _role == 'student'
        ? (_selectedYear == null ? <String>{} : {_selectedYear!.id})
        : _selectedTeachingYearIds.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _role == 'student'
              ? 'Select Your Year of Study'
              : 'Select Teaching Years',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _role == 'student'
              ? 'Choose the year you are currently studying.'
              : 'Choose every year in which you will teach.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        if (_availableYears.isEmpty)
          const Text(
            'No academic years are available yet.',
            style: TextStyle(color: Colors.white70),
          )
        else
          for (final year in _availableYears)
            _buildSelectionTile(
              isDarkMode,
              accentColor,
              year.name,
              selectedIds.contains(year.id),
              () {
                setState(() {
                  if (_role == 'student') {
                    _selectedYear = year;
                  } else if (_selectedTeachingYearIds.contains(year.id)) {
                    _selectedTeachingYearIds.remove(year.id);
                  } else {
                    _selectedTeachingYearIds.add(year.id);
                  }
                });
              },
              isMultiSelect: _role == 'lecturer',
            ),
      ],
    );
  }

  Widget _buildBachelorSelectionStep(bool isDarkMode, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Your Degree',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your degree programme',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                _availableBachelors.isEmpty
                    ? const Center(
                        child: Text(
                          'No degree programmes loaded yet. You can continue browsing and complete this selection before registering.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        children: [
                          for (final bach in _availableBachelors)
                            _buildSelectionTile(
                              isDarkMode,
                              accentColor,
                              bach.name,
                              _selectedBachelorId == bach.id,
                              () {
                                setState(() {
                                  _selectedBachelorId = bach.id;
                                });
                              },
                              isMultiSelect: false,
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildRoleSelector(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
        onTap: () {
          setState(() {
            _role = role;
            _selectedYear = null;
            _selectedTeachingYearIds.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionTile(
    bool isDarkMode,
    Color accentColor,
    String title,
    bool isSelected,
    VoidCallback onTap, {
    required bool isMultiSelect,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: isMultiSelect ? BoxShape.rectangle : BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: isMultiSelect ? BorderRadius.circular(6) : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
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
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
