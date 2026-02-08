import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../Services/Authentication/community_auth.dart';
import '../../Shared/theme/app_theme.dart';
import '../Pages/community_guidelines.dart';
import '../Pages/login.dart';

class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key});

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Org-specific controllers
  final _orgNameController = TextEditingController();
  final _backgroundController = TextEditingController();
  final List<TextEditingController> _functionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  // Organization designation list
  final List<Map<String, String>> _organizationDesignations = [
    {
      "acronym": "NGO",
      "fullForm": "Non-Governmental Organization",
      "description":
          "Big charity groups that help with health, education, and community needs."
    },
    {
      "acronym": "NPO",
      "fullForm": "Non-Profit Organization",
      "description":
          "Groups that don't work for profit, they focus on helping people."
    },
    {
      "acronym": "CBO",
      "fullForm": "Community-Based Organization",
      "description":
          "Local groups formed by community members to solve local problems."
    },
    {
      "acronym": "PBO",
      "fullForm": "Public Benefit Organization",
      "description": "Officially registered groups that serve the public good."
    },
    {
      "acronym": "Trust",
      "fullForm": "Charitable Trust",
      "description":
          "Organizations that manage funds or property to support community projects."
    },
    {
      "acronym": "Society",
      "fullForm": "Registered Society",
      "description":
          "Associations for cultural, religious, or social activities."
    },
    {
      "acronym": "CLG",
      "fullForm": "Company Limited by Guarantee",
      "description":
          "Non-profit companies often running schools, clinics, or foundations."
    },
    {
      "acronym": "FBO",
      "fullForm": "Faith-Based Organization",
      "description":
          "Churches, mosques, or religious groups that provide social services."
    },
    {
      "acronym": "SHG",
      "fullForm": "Self-Help Group",
      "description":
          "Small groups where members save money together and support each other."
    },
    {
      "acronym": "CFA",
      "fullForm": "Community Forest Association",
      "description":
          "Groups that take care of local forests and natural resources."
    },
  ];

  String _role = 'Member';
  String? _selectedOrgDesignation;
  bool _submitting = false;
  bool _isObscure = true;
  bool _isObscureConfirm = true;
  XFile? _profilePhoto;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _orgNameController.dispose();
    _backgroundController.dispose();
    for (var controller in _functionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return (words[0][0] + words[words.length - 1][0]).toUpperCase();
  }

  Future<void> _pickProfilePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profilePhoto = image;
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
    });

    try {
      print('[JoinCommunity] submit start, role=$_role');
      final communityAuth = CommunityAuthService();

      if (_role == 'Org Rep') {
        // Register as organization representative
        final functions = _functionControllers
            .map((c) => c.text.trim())
            .where((f) => f.isNotEmpty)
            .toList();

        if (functions.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please add at least one main function'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _submitting = false;
          });
          return;
        }

        if (_selectedOrgDesignation == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please select an organization designation'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _submitting = false;
          });
          return;
        }

        final user = await communityAuth.registerAsOrganization(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          orgName: _orgNameController.text.trim(),
          orgRepName: _nameController.text.trim(),
          background: _backgroundController.text.trim(),
          mainFunctions: functions,
          orgDesignation: _selectedOrgDesignation!,
          profilePhoto: _profilePhoto,
        );

        if (!mounted) return;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Could not create organization. Please try again.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        print('[JoinCommunity] org registration completed, user=${user.uid}');
        // Redirect to guidelines after signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const CommunityGuidelinesScreen()),
        );
      } else {
        // Register as Member or Volunteer
        final user = await communityAuth.registerWithEmail(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _role,
        );

        if (!mounted) return;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Could not create your account. Please try again.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        print('[JoinCommunity] registration completed, user=${user.uid}');
        // Redirect to guidelines after signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const CommunityGuidelinesScreen()),
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      print('[JoinCommunity] error: $e');
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(_nameController.text);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Create Account',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar with initials
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Role selection
                  Row(
                    children: [
                      Icon(Icons.badge_outlined,
                          size: 20, color: AppTheme.darkGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Choose Your Role',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGreen,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _RoleChip(
                        label: 'Member',
                        icon: Icons.people_outline,
                        description: 'Participate in activities',
                        selected: _role == 'Member',
                        onTap: () => setState(() => _role = 'Member'),
                      ),
                      _RoleChip(
                        label: 'Volunteer',
                        icon: Icons.volunteer_activism_outlined,
                        description: 'Lead contributions',
                        selected: _role == 'Volunteer',
                        onTap: () => setState(() => _role = 'Volunteer'),
                      ),
                      _RoleChip(
                        label: 'Org Rep',
                        icon: Icons.business_outlined,
                        description: 'Represent organization',
                        selected: _role == 'Org Rep',
                        onTap: () => setState(() => _role = 'Org Rep'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Name field
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your name',
                      helperText: 'This will be your display name',
                      helperStyle: TextStyle(
                        color: AppTheme.darkGreen.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(Icons.person_outline,
                          color: const Color(0xFF1a1a1a)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.lightGreen.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.lightGreen.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    cursorColor: AppTheme.primary,
                    cursorWidth: 0.5,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.lightGreen.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(
                        color: Color(0xFF1a1a1a),
                      ),
                      helperText: 'Used to sign in',
                      helperStyle: TextStyle(
                        color: AppTheme.darkGreen.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Color(0xFF1a1a1a),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Email cannot be empty";
                      }
                      if (!RegExp("^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+.[a-z]")
                          .hasMatch(value)) {
                        return "Please enter a valid email";
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    cursorColor: AppTheme.primary,
                    cursorWidth: 0.5,
                    controller: _passwordController,
                    obscureText: _isObscure,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF1a1a1a),
                        ),
                        onPressed: () {
                          setState(() {
                            _isObscure = !_isObscure;
                          });
                        },
                      ),
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                        color: Color(0xFF1a1a1a),
                      ),
                      helperText: 'At least 6 characters',
                      helperStyle: TextStyle(
                        color: AppTheme.darkGreen.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF1a1a1a),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.lightGreen.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    validator: (value) {
                      RegExp regex = RegExp(r'^.{6,}$');
                      if (value!.isEmpty) {
                        return "Password cannot be empty";
                      }
                      if (!regex.hasMatch(value)) {
                        return "At least 6 characters required";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password field
                  TextFormField(
                    cursorColor: AppTheme.primary,
                    cursorWidth: 0.5,
                    controller: _confirmPasswordController,
                    obscureText: _isObscureConfirm,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF1a1a1a),
                        ),
                        onPressed: () {
                          setState(() {
                            _isObscureConfirm = !_isObscureConfirm;
                          });
                        },
                      ),
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(
                        color: Color(0xFF1a1a1a),
                      ),
                      helperText: 'Must match password above',
                      helperStyle: TextStyle(
                        color: AppTheme.darkGreen.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF1a1a1a),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.lightGreen.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Please confirm your password";
                      }
                      if (value != _passwordController.text) {
                        return "Passwords do not match";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Conditional org fields
                  if (_role == 'Org Rep') ...[
                    Divider(
                      color: AppTheme.lightGreen.withOpacity(0.3),
                      thickness: 1,
                      height: 24,
                    ),
                    Row(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 20, color: AppTheme.darkGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Organization Details',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkGreen,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Profile Photo
                    GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: _profilePhoto != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(_profilePhoto!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 40,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to add profile photo',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Organization Designation Dropdown
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedOrgDesignation,
                        items: _organizationDesignations.map((org) {
                          return DropdownMenuItem<String>(
                            value: org['acronym'],
                            child: Text(org['acronym']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedOrgDesignation = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Organization Designation',
                          labelStyle: const TextStyle(
                            color: Color(0xFF1a1a1a),
                          ),
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            color: Color(0xFF1a1a1a),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppTheme.lightGreen.withOpacity(0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppTheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null) {
                            return 'Please select an organization designation';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Display full form and description
                    if (_selectedOrgDesignation != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.lightGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _organizationDesignations.firstWhere((org) =>
                                  org['acronym'] ==
                                  _selectedOrgDesignation)['fullForm']!,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkGreen,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _organizationDesignations.firstWhere((org) =>
                                  org['acronym'] ==
                                  _selectedOrgDesignation)['description']!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.darkGreen.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Organization Name
                    TextFormField(
                      controller: _orgNameController,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Organization Name',
                        hintText: 'Enter organization name',
                        prefixIcon:
                            Icon(Icons.business, color: AppTheme.accent),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.lightGreen.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.lightGreen.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter organization name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Background
                    TextFormField(
                      controller: _backgroundController,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Organization Background',
                        hintText:
                            'Tell us about your organization (max 150 words)',
                        prefixIcon: Icon(Icons.info_outline,
                            color: const Color(0xFF1a1a1a)),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.lightGreen.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.lightGreen.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter organization background';
                        }
                        final wordCount =
                            value.trim().split(RegExp(r'\s+')).length;
                        if (wordCount > 150) {
                          return 'Maximum 150 words allowed (${wordCount} words)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Main Functions
                    Row(
                      children: [
                        Icon(Icons.checklist,
                            size: 20, color: AppTheme.darkGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Main Functions (5)',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkGreen,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._functionControllers.asMap().entries.map((entry) {
                      int index = entry.key;
                      TextEditingController controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: controller,
                          style: const TextStyle(
                              color: Colors.black, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Function ${index + 1}',
                            hintText: 'e.g., Community outreach',
                            prefixIcon: Icon(Icons.check_circle_outline,
                                color: const Color(0xFF1a1a1a)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppTheme.lightGreen.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppTheme.lightGreen.withOpacity(0.5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],

                  // Submit Button
                  FilledButton(
                    onPressed: _submitting ? null : _submitRegistration,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      shadowColor: AppTheme.primary.withOpacity(0.4),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : AppTheme.lightGreen.withOpacity(0.4),
            width: selected ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary
                    : AppTheme.lightGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              selected ? AppTheme.primary : AppTheme.darkGreen,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.darkGreen.withOpacity(0.7),
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
