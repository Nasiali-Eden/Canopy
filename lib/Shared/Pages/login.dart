import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Shared/theme/app_theme.dart';
import '../../Services/Authentication/auth.dart';
import '../../Services/Authentication/community_auth.dart';
import '../../Community/Home/community_home.dart';
import '../../Organization/Home/org_home.dart';
import '../../Shared/Authentication/join_community.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isObscure = true;
  bool visible = false;
  final _formkey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Allow back navigation to welcome screen
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Image.asset('pngs/logotext.png', width: 150, height: 90),
                  const SizedBox(height: 20),
                  Text(
                    "Sign In to Canopy",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Track your community contributions",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formkey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              cursorColor: AppTheme.primary,
                              cursorWidth: 0.5,
                              controller: emailController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppTheme.primary,
                                    width: 2,
                                  ),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                                labelText: 'Email',
                                labelStyle: const TextStyle(
                                  color: Color(0xFF1a1a1a),
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF1a1a1a),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return "Email cannot be empty";
                                }
                                if (!RegExp(
                                        "^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+.[a-z]")
                                    .hasMatch(value)) {
                                  return "Please enter a valid email";
                                }
                                return null;
                              },
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              cursorColor: AppTheme.primary,
                              cursorWidth: 0.5,
                              controller: passwordController,
                              obscureText: _isObscure,
                              style: const TextStyle(color: Colors.black),
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
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF1a1a1a),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppTheme.primary,
                                    width: 2,
                                  ),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              validator: (value) {
                                RegExp regex = RegExp(r'^.{6,}$');
                                if (value!.isEmpty) {
                                  return "Password cannot be empty";
                                }
                                if (!regex.hasMatch(value)) {
                                  return "Please enter a valid password with at least 6 characters";
                                }
                                return null;
                              },
                              onFieldSubmitted: (value) {
                                if (_formkey.currentState!.validate()) {
                                  signIn(emailController.text,
                                      passwordController.text);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                          MaterialButton(
                            onPressed: () {
                              setState(() {
                                visible = true;
                              });
                              signIn(emailController.text,
                                  passwordController.text);
                            },
                            color: AppTheme.primary,
                            minWidth: double.infinity,
                            height: 56,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: visible
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Sign In",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // TODO: Implement forgot password
                              },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Divider with "OR"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.black26,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.black45),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.black26,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Social sign-in buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google button
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black12,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // TODO: Implement Google sign-in
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Image.asset(
                                  'images/google.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Apple button
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black12,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // TODO: Implement Apple sign-in
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Image.asset(
                                  'images/apple.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void signIn(String email, String password) async {
    if (_formkey.currentState!.validate()) {
      try {
        if (kDebugMode) {
          print('===== SIGN IN ATTEMPT =====');
          print('Email: $email');
        }

        final user = await _authService.signIn(email, password);

        if (user != null) {
          if (kDebugMode) {
            print('Sign in successful, uid: ${user.uid}');
          }

          // Wait a moment for auth state to propagate
          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) return;

          // Route user based on their collection
          await route(user);
        } else {
          if (!mounted) return;
          setState(() {
            visible = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Sign in error: $e');
        }
        if (!mounted) return;
        setState(() {
          visible = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> route(User user) async {
    if (kDebugMode) {
      print('===== LOGIN ROUTE START =====');
      print('Routing user with ID: ${user.uid}');
    }

    try {
      // First check members collection
      final memberSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .doc(user.uid)
          .get();

      if (kDebugMode) {
        print(
            '[LOGIN] Checked members collection - exists: ${memberSnapshot.exists}');
      }

      if (memberSnapshot.exists) {
        if (kDebugMode) {
          print('[LOGIN] User FOUND in members collection');
        }
        await _routeUser(user, memberSnapshot, 'members');
        return;
      }

      // User not in members, check org_rep collection
      if (kDebugMode) {
        print('[LOGIN] User NOT in members, checking org_rep...');
      }

      final orgSnapshot = await FirebaseFirestore.instance
          .collection('org_rep')
          .doc(user.uid)
          .get();

      if (kDebugMode) {
        print(
            '[LOGIN] Checked org_rep collection - exists: ${orgSnapshot.exists}');
      }

      if (orgSnapshot.exists) {
        if (kDebugMode) {
          print('[LOGIN] User FOUND in org_rep collection');
        }
        await _routeUser(user, orgSnapshot, 'org_rep');
        return;
      }

      // User not found in either collection
      if (kDebugMode) {
        print(
            '[LOGIN] User not found in members or org_rep collections - redirecting to join');
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const JoinCommunityScreen()),
        (route) => false,
      );
    } catch (error) {
      if (kDebugMode) {
        print("[LOGIN] Error fetching user data: $error");
      }

      if (!mounted) return;

      setState(() {
        visible = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user data: $error')),
      );
    }
  }

  Future<void> _routeUser(
      User user, DocumentSnapshot userDoc, String collectionName) async {
    // Determine role based on which collection user was found in
    final role = collectionName == 'org_rep' ? 'Org Rep' : 'Member';

    if (kDebugMode) {
      print('[LOGIN ROUTE] ========================================');
      print('[LOGIN ROUTE] Collection: $collectionName');
      print('[LOGIN ROUTE] Role determined: $role');
      print('[LOGIN ROUTE] User UID: ${user.uid}');
      print('[LOGIN ROUTE] Skipping guidelines check for login');
      print('[LOGIN ROUTE] ========================================');
    }

    if (!mounted) {
      print('[LOGIN ROUTE] ⚠️ Widget not mounted, aborting navigation');
      return;
    }

    // Route to appropriate home based on role (skip guidelines check for login)
    if (role == 'Org Rep') {
      if (kDebugMode) {
        print('[LOGIN ROUTE] ✅ Role is Org Rep - routing to OrganizationHome');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const OrganizationHome()),
        (route) => false,
      );
    } else {
      if (kDebugMode) {
        print(
            '[LOGIN ROUTE] ✅ Role is Member - routing to CommunityHomeScreen');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const CommunityHomeScreen()),
        (route) => false,
      );
    }
  }
}
