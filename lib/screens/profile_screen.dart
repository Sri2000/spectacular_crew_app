import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:retail_failure_simulator/providers/notification_provider.dart';
import 'package:retail_failure_simulator/providers/prediction_provider.dart';
import 'package:retail_failure_simulator/providers/tab_provider.dart';
import 'package:retail_failure_simulator/models/failure_risk.dart';
import 'package:retail_failure_simulator/services/excel_parser.dart';
import 'package:retail_failure_simulator/services/storage_service.dart';
import 'package:retail_failure_simulator/screens/login_screen.dart';
import 'dart:math';
import 'dart:ui';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _deptController = TextEditingController();
  RiskCategory _selectedCategory = RiskCategory.demandMismatch;
  String? _selectedFileName;
  String? _selectedFileContent;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    _nameController.text = StorageService.getUserName() ?? '';
    _emailController.text = StorageService.getUserEmail() ?? '';
    _phoneController.text = StorageService.getUserPhone() ?? '';
    _roleController.text = StorageService.getUserRole() ?? '';
    _deptController.text = StorageService.getUserDepartment() ?? '';
    String? categoryStr = StorageService.getUserRiskCategory();
    if (categoryStr != null) {
      for (var value in RiskCategory.values) {
        String categoryName = value.toString().split('.').last;
        if (categoryName.toLowerCase() == categoryStr.toLowerCase() ||
            categoryStr == value.toString().split('.').last) {
          _selectedCategory = value;
          break;
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _lastS3Url;

  Future<void> _handleFilePick() async {
    final data = await ExcelParser.pickAndParse();
    if (data != null) {
      setState(() {
        _selectedFileName = data['fileName'];
        _selectedFileContent = data['content'] as String;
        _lastS3Url = data['s3Url'] as String?;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected: $_selectedFileName (Stored in S3)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handleSubmitAll() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter name and email to proceed.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final propagationScore = 78 + Random().nextInt(18);
      final exposure = 180000.0 + Random().nextInt(400000);

      // 1. Save Profile to Local & DynamoDB (including S3 URL and Metrics)
      await StorageService.saveProfile(
        _nameController.text,
        _emailController.text,
        _selectedCategory.toString().split('.').last,
        phone: _phoneController.text,
        role: _roleController.text,
        department: _deptController.text,
        s3Url: _lastS3Url,
        metrics: {
          "propagationScore": propagationScore.toString(),
          "exposure": exposure.toStringAsFixed(2),
        },
      );

      // 2. Process File & Generate Risk if selected
      if (_selectedFileContent != null) {
        final newRisk = FailureRisk(
          id: 'USER-${Random().nextInt(99999)}',
          title: 'PROFILE RISK SUBMISSION',
          subTitle: _selectedFileName ?? 'Uploaded Data',
          propagationScore: propagationScore,
          urgencyWindow: 'New User Alert',
          updatedTime: 'Just Now',
          category: _selectedCategory,
          exposure: exposure,
          impactPoints: [
            ImpactPoint(
              title: 'DATA UPLOAD DETECTED',
              description:
                  'Profile information submitted for ${_nameController.text}. Risk analysis triggered based on uploaded spreadsheet.',
              isCritical: true,
            ),
          ],
          mitigationActions: [
            MitigationAction(
              title: 'Risk Profile Verification',
              description:
                  'AI is analyzing the risk based on the user profile.',
              recoveryLabel: 'Active',
            ),
          ],
        );

        await context.read<NotificationProvider>().generateRiskAlert(newRisk);
        await context.read<PredictionProvider>().generatePrediction(
          _selectedFileContent!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile & Metrics backed up to DynamoDB!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }

      if (mounted) {
        if (_selectedFileContent != null) {
          context.read<TabProvider>().setTab(3);
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleLogout() async {
    await StorageService.clearProfile();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'USER ONBOARDING',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 32),
                _buildGlassCard(
                  title: 'CREATE USER / PROFILE',
                  child: Column(
                    children: [
                      _buildBetterTextField(
                        'Full Name',
                        LucideIcons.user,
                        _nameController,
                      ),
                      const SizedBox(height: 20),
                      _buildBetterTextField(
                        'Work Email',
                        LucideIcons.mail,
                        _emailController,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBetterTextField(
                              'Phone',
                              LucideIcons.phone,
                              _phoneController,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildBetterTextField(
                              'Role',
                              LucideIcons.briefcase,
                              _roleController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildBetterTextField(
                        'Department',
                        LucideIcons.building,
                        _deptController,
                      ),
                      const SizedBox(height: 24),
                      _buildRiskFocusSelector(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildGlassCard(
                  title: 'UPLOAD RISK DATA',
                  child: _buildFileUploadArea(),
                ),
                const SizedBox(height: 40),
                _buildSubmitButton(),
                const SizedBox(height: 32),
                Center(child: _buildLogoutButton()),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0052FF), Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0052FF).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(LucideIcons.user, color: Colors.white, size: 40),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Setup',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Complete your entry below',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassCard({required String title, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBetterTextField(
    String label,
    IconData icon,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white30, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRiskFocusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT RISK FOCUS',
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<RiskCategory>(
              value: _selectedCategory,
              isExpanded: true,
              icon: const Icon(LucideIcons.chevronDown, color: Colors.white30),
              dropdownColor: const Color(0xFF1E293B),
              onChanged: (value) {
                if (value != null) setState(() => _selectedCategory = value);
              },
              items: RiskCategory.values.map((category) {
                String name = category.toString().split('.').last;
                name = name
                    .replaceAllMapped(
                      RegExp(r'[A-Z]'),
                      (match) => ' ${match.group(0)}',
                    )
                    .trim()
                    .toUpperCase();
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadArea() {
    return Column(
      children: [
        InkWell(
          onTap: _handleFilePick,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  LucideIcons.uploadCloud,
                  color: Color(0xFF10B981),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedFileName != null
                      ? 'NEW FILE LOADED'
                      : 'Select Excel File',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedFileName == null)
                  Text(
                    'Supports .xlsx, .xls',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  )
                else
                  Text(
                    'Ready for analysis',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmitAll,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0052FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: const Color(0xFF0052FF).withOpacity(0.5),
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SUBMIT & ANALYZE RISKS',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(LucideIcons.arrowRight, color: Colors.white),
                ],
              ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: _handleLogout,
      icon: const Icon(LucideIcons.logOut, color: Colors.white38, size: 18),
      label: Text(
        'LOGOUT ACCOUNT',
        style: GoogleFonts.outfit(
          color: Colors.white38,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
