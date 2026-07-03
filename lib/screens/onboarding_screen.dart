import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/linkedin_oauth_config.dart';
import 'linkedin_webview.dart';
import '../utils/image_helper.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import '../state_manager.dart';
import '../services/user_service.dart';
import '../utils/app_logo.dart';

enum OnboardingView {
  slides,
  signIn,
  signUpStep1, // Name, Email, Password, Profile Photo
  signUpStep2, // Job Title, Company, Skills, Experience, Bio, Interests, Locations, Travel preferences
}

class OnboardingScreen extends StatefulWidget {
  final bool completionMode;
  const OnboardingScreen({super.key, this.completionMode = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isLoading = false;
  late OnboardingView _currentView;
  bool _obscurePassword = true;

  // Form Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _headlineController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _expertiseController = TextEditingController();
  final TextEditingController _industryController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _profileImageUrlController =
      TextEditingController();
  final TextEditingController _linkedinUrlController = TextEditingController();
  String _emailErrorText = '';
  String _passwordErrorText = '';
  List<({String label, bool met})> _passwordReqs = [];


  // Career & Education timelines state
  final List<Map<String, dynamic>> _careerTimeline = [];
  final List<Map<String, dynamic>> _educationTimeline = [];

  // Career form inputs
  final TextEditingController _workRoleController = TextEditingController();
  final TextEditingController _workCompanyController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();
  final TextEditingController _workStartDateController =
      TextEditingController();
  final TextEditingController _workEndDateController = TextEditingController();
  final TextEditingController _workDescController = TextEditingController();
  String _workEmploymentType = 'Full-time';

  // Education form inputs
  final TextEditingController _eduDegreeController = TextEditingController();
  final TextEditingController _eduSchoolController = TextEditingController();
  final TextEditingController _eduStartDateController = TextEditingController();
  final TextEditingController _eduEndDateController = TextEditingController();

  String? _selectedIndustry;
  String? _selectedTravelFrequency;

  // Home Base dependent states
  String _homeBaseCountry = '';
  String _homeBaseState = '';
  String _homeBaseCity = '';

  // Current Location dependent states
  String _currentLocationCountry = '';
  String _currentLocationState = '';
  String _currentLocationCity = '';

  final List<String> _industries = [
    'Technology',
    'Finance',
    'Healthcare',
    'Education',
    'Consulting',
    'Real Estate',
    'Automotive',
    'Entertainment',
    'Other',
  ];

  final List<String> _travelFrequencies = [
    'Rarely',
    'Occasional',
    'Frequent',
    'Never',
  ];

  final List<String> _interestOptions = [
    'Networking',
    'Socializing',
    'Learning',
    'Investing',
    'Fundraising',
    'Hiring Talents',
    'Job Opportunity',
  ];
  String? _selectedInterest;

  final List<Map<String, String>> _onboardingData = [
    {
      'image': 'assets/images/boarding_pass_illustration.png',
      'title': 'Welcome to\nNexMeet',
      'subtitle':
          'Connect with professionals, discover events, and build meaningful business relationships wherever work takes you.',
    },
    {
      'image': 'assets/images/boarding_pass_illustration_2.png',
      'title': 'Meet The\nRight People',
      'subtitle':
          'Discover professionals based on industry, interests, and location.',
    },
    {
      'image': 'assets/images/boarding_pass_illustration_3.png',
      'title': 'Connections\nNear You',
      'subtitle':
          'Find relevant professionals and networking opportunities around your current destination.',
    },
    {
      'image': 'assets/images/boarding_pass_illustration_4.png',
      'title': 'Attend Exclusive\nEvents',
      'subtitle':
          'Join conferences, networking sessions, and industry gatherings tailored to your interests.',
    },
    {
      'image': 'assets/images/boarding_pass_illustration_5.png',
      'title': 'Host Your\nOwn Events',
      'subtitle':
          'Create networking experiences and invite professionals to connect.',
    },
    {
      'image': 'assets/images/boarding_pass_illustration_6.png',
      'title': 'Build Your\nProfessional Identity',
      'subtitle':
          'Showcase your industry, role, company, and travel preferences.',
    },
    {
      'image': 'assets/images/boarding_pass_illustration_7.png',
      'title': 'Personalize Your\nExperience',
      'subtitle':
          'Select industries and interests to receive relevant connections and event recommendations.',
    },
    {
      'image': 'assets/images/boarding_pass_illustration_8.png',
      'title': 'You\'re Ready\nto Network',
      'subtitle':
          'Join a global community of professionals and unlock meaningful opportunities.',
    },
  ];

  bool get _isLinkedInUser {
    final profile = AppStateManager().currentUserProfile;
    if (profile != null) {
      return (profile.linkedinId != null && profile.linkedinId!.isNotEmpty) ||
          profile.linkedinSynced;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      return email.startsWith('linkedin_') && email.endsWith('@boardingpass.com');
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _currentView = widget.completionMode
        ? OnboardingView.signUpStep2
        : OnboardingView.slides;

    if (widget.completionMode) {
      final profile = AppStateManager().currentUserProfile;
      if (profile != null) {
        _nameController.text = profile.name;
        _emailController.text = profile.email;
        _profileImageUrlController.text = profile.profileImageUrl ?? '';
        _roleController.text = profile.role ?? '';
        _companyController.text = profile.company ?? '';
        _headlineController.text = profile.headline ?? '';
        _bioController.text = profile.bio ?? '';
        _experienceController.text = profile.experience ?? '';
        _linkedinUrlController.text = profile.linkedinProfileUrl ?? '';
        if (profile.expertise.isNotEmpty) {
          _expertiseController.text = profile.expertise.join(', ');
        }
        if (profile.industry != null && profile.industry!.isNotEmpty) {
          _selectedIndustry = profile.industry;
        }
        if (profile.travelFrequency != null &&
            profile.travelFrequency!.isNotEmpty) {
          _selectedTravelFrequency = profile.travelFrequency;
        }
      }
    }

    // Add listeners for real-time progress update
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
    _profileImageUrlController.addListener(_onFieldChanged);
    _linkedinUrlController.addListener(_onFieldChanged);
    _roleController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _headlineController.addListener(_onFieldChanged);
    _expertiseController.addListener(_onFieldChanged);
    _experienceController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _industryController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _profileImageUrlController.removeListener(_onFieldChanged);
    _linkedinUrlController.removeListener(_onFieldChanged);
    _roleController.removeListener(_onFieldChanged);
    _companyController.removeListener(_onFieldChanged);
    _headlineController.removeListener(_onFieldChanged);
    _expertiseController.removeListener(_onFieldChanged);
    _experienceController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _industryController.removeListener(_onFieldChanged);

    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _headlineController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    _expertiseController.dispose();
    _industryController.dispose();
    _experienceController.dispose();
    _profileImageUrlController.dispose();
    _linkedinUrlController.dispose();
    _workRoleController.dispose();
    _workCompanyController.dispose();
    _workLocationController.dispose();
    _workStartDateController.dispose();
    _workEndDateController.dispose();
    _workDescController.dispose();
    _eduDegreeController.dispose();
    _eduSchoolController.dispose();
    _eduStartDateController.dispose();
    _eduEndDateController.dispose();
    super.dispose();
  }

  void _handleLinkedInSignIn() async {
    final String redirectUri = LinkedInOAuthConfig.redirectUri;
    final String authUrl = LinkedInOAuthConfig.authorizationUrl(
      redirectUri: redirectUri,
    );

    debugPrint('--- LinkedIn Auth Debug Info ---');
    debugPrint('App Client ID: ${LinkedInOAuthConfig.clientId}');
    debugPrint('Generated redirect_uri: "$redirectUri"');
    debugPrint('Full authorizationUrl: $authUrl');
    debugPrint('---------------------------------');

    final String? authCode = await showLinkedInWebView(context, authUrl);

    if (authCode == null) {
      return;
    }

    if (authCode.startsWith('error:')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'LinkedIn login failed: ${authCode.replaceFirst('error:', '')}',
            ),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().signInWithLinkedIn(
        authCode,
        redirectUri: redirectUri,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'LinkedIn login failed'),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LinkedIn login failed: $e'),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  void _handleEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
          backgroundColor: Color(0xFF7A432D),
        ),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Color(0xFF7A432D),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First try normal email/password sign-in
      await AuthService().signInWithEmail(email: email, password: password);
    } on FirebaseAuthException catch (firstError) {
      // If normal sign-in fails with invalid credential, check if this is a
      // LinkedIn user who set a password (their Firebase email is still
      // synthetic: linkedin_{sub}@boardingpass.com but their real email is
      // stored in Firestore). Retry with the synthetic email + same password.
      if (firstError.code == 'invalid-credential' ||
          firstError.code == 'wrong-password' ||
          firstError.code == 'user-not-found') {
        try {
          // Look up the Firestore user record whose real email matches
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            final linkedinId = data['linkedinId'] as String?;
            if (linkedinId != null && linkedinId.isNotEmpty) {
              // This is a LinkedIn user — retry with synthetic Firebase email
              final syntheticEmail = 'linkedin_$linkedinId@boardingpass.com';
              await AuthService().signInWithEmail(
                email: syntheticEmail,
                password: password,
              );
              // Success — exit without showing any error
              return;
            }
          }
        } on FirebaseAuthException catch (retryError) {
          // Synthetic email retry also failed — show a clear message
          if (mounted) {
            String msg = 'Incorrect password. Please try again.';
            if (retryError.code == 'wrong-password' ||
                retryError.code == 'invalid-credential') {
              msg = 'Incorrect password. Please try again.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: const Color(0xFF7A432D),
              ),
            );
          }
          return;
        } catch (_) {
          // Fallthrough to show the original error
        }
      }
      // Show the original Firebase error
      if (mounted) {
        String msg = firstError.message ?? 'Authentication failed';
        if (firstError.code == 'invalid-credential' ||
            firstError.code == 'wrong-password') {
          msg = 'Incorrect email or password.';
        } else if (firstError.code == 'user-not-found') {
          msg = 'No account found with that email.';
        } else if (firstError.code == 'user-disabled') {
          msg = 'This account has been disabled.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleEmailSignUp() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Color(0xFF7A432D),
        ),
      );
      return;
    }

    final password = _passwordController.text;
    if (!_isPasswordValid(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters with uppercase, lowercase, number & special character.'),
          backgroundColor: Color(0xFF7A432D),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final headline = _headlineController.text.trim();
    final company = _companyController.text.trim();
    final role = _roleController.text.trim();
    final bio = _bioController.text.trim();

    final industry = _selectedIndustry == 'Other'
        ? _industryController.text.trim()
        : _selectedIndustry;
    final experience = _experienceController.text.trim();
    final homeBaseSegments = [
      if (_homeBaseCity.isNotEmpty) _homeBaseCity,
      if (_homeBaseState.isNotEmpty) _homeBaseState,
      if (_homeBaseCountry.isNotEmpty) _homeBaseCountry,
    ];
    final homeBase = homeBaseSegments.join(', ');

    final currentLocSegments = [
      if (_currentLocationCity.isNotEmpty) _currentLocationCity,
      if (_currentLocationState.isNotEmpty) _currentLocationState,
      if (_currentLocationCountry.isNotEmpty) _currentLocationCountry,
    ];
    final currentLocationName = currentLocSegments.join(', ');
    final travelFrequency = _selectedTravelFrequency;
    final profileImageUrl = _profileImageUrlController.text.trim();

    // Parse expertise
    final expertiseStr = _expertiseController.text.trim();
    final List<String> expertiseList = expertiseStr.isNotEmpty
        ? expertiseStr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : [];

    // Validate fields before sign up
    if (role.isEmpty ||
        company.isEmpty ||
        experience.isEmpty ||
        bio.isEmpty ||
        expertiseList.isEmpty ||
        _selectedIndustry == null ||
        _selectedInterest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all professional details, skills, experience, bio, and select a sector and primary interest.',
          ),
          backgroundColor: Color(0xFF7A432D),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      AppStateManager().isRegistering = true;
      await AuthService().signUpWithEmail(
        email: email,
        password: password,
        name: name,
        headline: headline.isNotEmpty ? headline : '$role at $company',
        company: company.isNotEmpty ? company : null,
        role: role.isNotEmpty ? role : null,
        bio: bio.isNotEmpty ? bio : null,
        industry: industry != null && industry.isNotEmpty
            ? industry
            : 'Technology',
        experience: experience.isNotEmpty ? experience : null,
        homeBase: homeBase.isNotEmpty ? homeBase : null,
        currentLocationName: currentLocationName.isNotEmpty
            ? currentLocationName
            : null,
        travelFrequency: travelFrequency,
        profileImageUrl: profileImageUrl.isNotEmpty ? profileImageUrl : null,
        expertise: expertiseList,
        intents: [_selectedInterest!],
        skills: expertiseList,
        interests: [_selectedInterest!],
        careerTimeline: _careerTimeline,
        educationTimeline: _educationTimeline,
        linkedinProfileUrl: _linkedinUrlController.text.trim().isNotEmpty
            ? _linkedinUrlController.text.trim()
            : null,
      );
      final user = FirebaseAuth.instance.currentUser;
      AppStateManager().isRegistering = false;
      if (user != null) {
        await AppStateManager().syncSignedInUser(user);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Welcome!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      AppStateManager().isRegistering = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Sign up failed'),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
    } catch (e) {
      AppStateManager().isRegistering = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: $e'),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleProfileCompletion() async {
    final role = _roleController.text.trim();
    final company = _companyController.text.trim();
    final headline = _headlineController.text.trim();
    final bio = _bioController.text.trim();
    final experience = _experienceController.text.trim();
    final industry = _selectedIndustry == 'Other'
        ? _industryController.text.trim()
        : _selectedIndustry;
    final homeBaseSegments = [
      if (_homeBaseCity.isNotEmpty) _homeBaseCity,
      if (_homeBaseState.isNotEmpty) _homeBaseState,
      if (_homeBaseCountry.isNotEmpty) _homeBaseCountry,
    ];
    final homeBase = homeBaseSegments.join(', ');

    final currentLocSegments = [
      if (_currentLocationCity.isNotEmpty) _currentLocationCity,
      if (_currentLocationState.isNotEmpty) _currentLocationState,
      if (_currentLocationCountry.isNotEmpty) _currentLocationCountry,
    ];
    final currentLocationName = currentLocSegments.join(', ');
    final travelFrequency = _selectedTravelFrequency;

    // Parse expertise
    final expertiseStr = _expertiseController.text.trim();
    final List<String> expertiseList = expertiseStr.isNotEmpty
        ? expertiseStr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : [];

    // Validate fields before complete
    if (role.isEmpty ||
        company.isEmpty ||
        experience.isEmpty ||
        bio.isEmpty ||
        expertiseList.isEmpty ||
        _selectedIndustry == null ||
        _selectedInterest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all professional details, skills, experience, bio, and select a sector and primary interest.',
          ),
          backgroundColor: Color(0xFF7A432D),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await UserService().updateUserProfile(
          userId: user.uid,
          role: role,
          company: company,
          headline: headline.isNotEmpty ? headline : '$role at $company',
          bio: bio,
          industry: industry != null && industry.isNotEmpty
              ? industry
              : 'Technology',
          experience: experience,
          homeBase: homeBase.isNotEmpty ? homeBase : null,
          currentLocationName: currentLocationName.isNotEmpty
              ? currentLocationName
              : null,
          travelFrequency: travelFrequency,
          expertise: expertiseList,
          intents: [_selectedInterest!],
          skills: expertiseList,
          interests: [_selectedInterest!],
          careerTimeline: _careerTimeline,
          educationTimeline: _educationTimeline,
          linkedinProfileUrl: !_isLinkedInUser && _linkedinUrlController.text.trim().isNotEmpty
              ? _linkedinUrlController.text.trim()
              : null,
        );
        await AppStateManager().syncSignedInUser(user);
        AppStateManager().currentScreen = AppScreen.hub;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile completed successfully!'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _emailErrorText = '';
    } else if (!_isValidEmail(email)) {
      _emailErrorText = 'Please enter a valid email address';
    } else {
      _emailErrorText = '';
    }
    if (mounted) setState(() {});
  }

  bool _isPasswordValid(String p) {
    return p.length >= 8 &&
        p.contains(RegExp(r'[A-Z]')) &&
        p.contains(RegExp(r'[a-z]')) &&
        p.contains(RegExp(r'[0-9]')) &&
        p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }

  List<({String label, bool met})> _checkPasswordReqs(String p) {
    return [
      (label: 'At least 8 characters', met: p.length >= 8),
      (label: '1 uppercase letter', met: p.contains(RegExp(r'[A-Z]'))),
      (label: '1 lowercase letter', met: p.contains(RegExp(r'[a-z]'))),
      (label: '1 number', met: p.contains(RegExp(r'[0-9]'))),
      (label: '1 special character', met: p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))),
    ];
  }

  Widget _buildPasswordReqs(List<({String label, bool met})> reqs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reqs.map((r) {
        final ok = r.met;
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 14,
                color: ok ? const Color(0xFF2E7D32) : const Color(0xFF8C736B),
              ),
              const SizedBox(width: 6),
              Text(
                r.label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: ok ? const Color(0xFF2E7D32) : const Color(0xFF8C736B),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    _passwordReqs = _checkPasswordReqs(password);
    if (password.isEmpty) {
      _passwordErrorText = '';
    } else if (!_isPasswordValid(password)) {
      _passwordErrorText = 'Password does not meet all requirements';
    } else {
      _passwordErrorText = '';
    }
    if (mounted) setState(() {});
  }

  double _calculateCompletionPercentage() {
    int total = 0;
    int completed = 0;

    // 1. Name
    total++;
    if (_nameController.text.trim().isNotEmpty) completed++;

    // 2. Email
    total++;
    if (_emailController.text.trim().isNotEmpty) completed++;

    // 3. Profile Image
    total++;
    if (_profileImageUrlController.text.trim().isNotEmpty) completed++;

    // 4. Role
    total++;
    if (_roleController.text.trim().isNotEmpty) completed++;

    // 5. Company
    total++;
    if (_companyController.text.trim().isNotEmpty) completed++;

    // 6. Headline
    total++;
    if (_headlineController.text.trim().isNotEmpty) completed++;

    // 7. Expertise / Skills
    total++;
    if (_expertiseController.text.trim().isNotEmpty) completed++;

    // 8. Industry
    total++;
    if (_selectedIndustry != null &&
        _selectedIndustry!.isNotEmpty &&
        _selectedIndustry != 'Select Industry') {
      if (_selectedIndustry == 'Other') {
        if (_industryController.text.trim().isNotEmpty) {
          completed++;
        }
      } else {
        completed++;
      }
    }

    // 9. Experience Years
    total++;
    if (_experienceController.text.trim().isNotEmpty) completed++;

    // 10. Bio
    total++;
    if (_bioController.text.trim().isNotEmpty) completed++;

    // 11. Primary Interest
    total++;
    if (_selectedInterest != null) completed++;

    // 12. Travel Frequency
    total++;
    if (_selectedTravelFrequency != null &&
        _selectedTravelFrequency!.isNotEmpty &&
        _selectedTravelFrequency != 'Select Frequency') {
      completed++;
    }

    // 13. Home Base
    total++;
    if (_homeBaseCountry.isNotEmpty || _homeBaseCity.isNotEmpty) completed++;

    // 14. Current Location
    total++;
    if (_currentLocationCountry.isNotEmpty || _currentLocationCity.isNotEmpty) completed++;

    // 15. Work Experience (Optional)
    total++;
    if (_careerTimeline.isNotEmpty) completed++;

    // 16. Education (Optional)
    total++;
    if (_educationTimeline.isNotEmpty) completed++;

    return total == 0 ? 0.0 : (completed / total) * 100.0;
  }

  Widget _buildStepIndicator(int step) {
    return Row(
      children: List.generate(2, (index) {
        final currentStep = index + 1;
        final isActive = currentStep <= step;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF7A432D)
                  : const Color(0xFFE8E2DD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: Color(0xFFB0A29C),
          fontSize: 13,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: Color(0xFF8C736B),
          fontSize: 13,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: Color(0xFF7A432D),
        ),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF7A432D),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : (readOnly
                ? const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF7A432D),
                    size: 18,
                  )
                : null),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
        ),
      ),
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        color: Color(0xFF3E1F11),
      ),
    );
  }

  Widget _buildSignInScreen(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF3E1F11),
            ),
            onPressed: () {
              setState(() {
                _currentView = OnboardingView.slides;
                _currentIndex = _onboardingData.length - 1;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(_onboardingData.length - 1);
                }
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to your NexMeet account to continue connecting.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              color: Color(0xFF5C473E),
            ),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            controller: _emailController,
            labelText: 'Email Address',
            hintText: 'e.g. rohan@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          if (_emailErrorText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _emailErrorText,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: Color(0xFFC62828),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            labelText: 'Password',
            hintText: 'Enter your password',
            obscureText: _obscurePassword,
            isPassword: true,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _handleEmailSignIn,
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () async {
                final email = _emailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter your email address above first.'),
                      backgroundColor: Color(0xFF7A432D),
                    ),
                  );
                  return;
                }
                try {
                  await AuthService().sendPasswordResetEmail(email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset email sent to $email'),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not send reset email: $e'),
                        backgroundColor: const Color(0xFF7A432D),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: Color(0xFF7A432D),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpStep1(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF3E1F11),
            ),
            onPressed: () {
              setState(() {
                _currentView = OnboardingView.slides;
                _currentIndex = _onboardingData.length - 1;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(_onboardingData.length - 1);
                }
              });
            },
          ),
          const SizedBox(height: 12),
          _buildStepIndicator(1),
          const SizedBox(height: 20),
          const Text(
            'Create Account',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Let\'s set up your profile picture and credentials first.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF5C473E),
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _nameController,
            labelText: 'Full Name',
            hintText: 'e.g. Rohan Mehta',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            labelText: 'Email Address',
            hintText: 'e.g. rohan@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          if (_emailErrorText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _emailErrorText,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: Color(0xFFC62828),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            labelText: 'Password',
            hintText: 'Create a strong password',
            obscureText: _obscurePassword,
            isPassword: true,
          ),
          if (_passwordReqs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: _buildPasswordReqs(_passwordReqs),
            ),
          const SizedBox(height: 24),

          // Profile Image Picker Section
          const Text(
            'Profile Image',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8E2DD),
                  border: Border.all(
                    color: const Color(0xFF7A432D),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: buildProfileImage(
                    _profileImageUrlController.text,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    fallback: const Icon(
                      Icons.person,
                      size: 36,
                      color: Color(0xFF7A432D),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _pickProfileImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A432D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Upload Photo',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (_nameController.text.trim().isEmpty ||
                    _emailController.text.trim().isEmpty ||
                    _passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all credentials fields'),
                      backgroundColor: Color(0xFF7A432D),
                    ),
                  );
                  return;
                }
                if (_passwordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Color(0xFF7A432D),
                    ),
                  );
                  return;
                }
                if (_profileImageUrlController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please upload a profile photo or paste a URL',
                      ),
                      backgroundColor: Color(0xFF7A432D),
                    ),
                  );
                  return;
                }
                setState(() {
                  _currentView = OnboardingView.signUpStep2;
                });
              },
              child: const Text(
                'Next: Professional Details',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpStep2(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.completionMode)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF3E1F11),
              ),
              onPressed: () {
                setState(() {
                  _currentView = OnboardingView.signUpStep1;
                });
              },
            )
          else ...[
            Align(
              alignment: Alignment.topRight,
              child: TextButton.icon(
                icon: const Icon(
                  Icons.logout,
                  size: 16,
                  color: Color(0xFF7A432D),
                ),
                label: const Text(
                  'Cancel / Logout',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFF7A432D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  AppStateManager().logOut();
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildStepIndicator(2),
          const SizedBox(height: 20),
          Text(
            widget.completionMode
                ? 'Complete Your Profile'
                : 'Professional Profile',
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your professional details, skills, and networking interests.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF5C473E),
            ),
          ),
          const SizedBox(height: 24),

          // Profile Completeness Widget
          Row(
            children: [
              GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _calculateCompletionPercentage() / 100.0,
                        strokeWidth: 4,
                        backgroundColor: const Color(0xFFE8E2DD),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                      ),
                    ),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE8E2DD),
                      ),
                      child: ClipOval(
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                                ),
                              )
                            : buildProfileImage(
                                _profileImageUrlController.text,
                                width: 68,
                                height: 68,
                                fit: BoxFit.cover,
                                fallback: const Icon(
                                  Icons.person,
                                  size: 34,
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF7A432D),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Completeness: ${_calculateCompletionPercentage().toInt()}%',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap photo to upload or change picture.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 1: Professional Role
          _buildSectionHeader('Professional Role'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _roleController,
            labelText: 'Job Title / Role',
            hintText: 'e.g. VP Engineering, Founder, Partner',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _companyController,
            labelText: 'Company / Organization',
            hintText: 'e.g. Stripe, Lumen Ventures, SME Credit',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _headlineController,
            labelText: 'Professional Headline',
            hintText: 'e.g. Scaling payments infra, Investing in Fintech',
          ),
          if (!_isLinkedInUser) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _linkedinUrlController,
              labelText: 'LinkedIn Profile Link (Optional)',
              hintText: 'e.g. https://linkedin.com/in/username',
            ),
          ],
          const SizedBox(height: 24),

          // Section 2: Skills & Experience
          _buildSectionHeader('Skills & Experience'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _expertiseController,
            labelText: 'Skills / Expertise Tags (comma-separated)',
            hintText: 'e.g. Fintech, Payments, Go-to-market',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Industry / Sector',
                  currentValue: _selectedIndustry,
                  items: _industries,
                  hintText: 'Select industry',
                  onChanged: (val) {
                    setState(() => _selectedIndustry = val);
                  },
                  secondaryField: _selectedIndustry == 'Other'
                      ? _buildTextField(
                          controller: _industryController,
                          labelText: 'Custom Industry',
                          hintText: 'e.g. BioTech',
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _experienceController,
                  labelText: 'Experience (Years)',
                  hintText: 'e.g. 5',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 3: Biography & Interests
          _buildSectionHeader('Biography & Interests'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _bioController,
            labelText: 'Short Biography',
            hintText: 'Describe what you do and who you want to meet...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Primary Interest:',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdownField(
            label: 'Select Interest',
            currentValue: _selectedInterest,
            items: _interestOptions,
            hintText: 'Select interest',
            onChanged: (val) => setState(() => _selectedInterest = val),
          ),
          const SizedBox(height: 24),

          // Section 4: Location & Travel
          _buildSectionHeader('Location & Travel'),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Travel Frequency',
            currentValue: _selectedTravelFrequency,
            items: _travelFrequencies,
            hintText: 'Select frequency',
            onChanged: (val) {
              setState(() => _selectedTravelFrequency = val);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Home Base Location',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 6),
          CSCPickerPlus(
            layout: Layout.vertical,
            showStates: true,
            showCities: true,
            flagState: CountryFlag.DISABLE,
            currentCountry: getCountryForPicker(_homeBaseCountry),
            currentState: _homeBaseState,
            currentCity: _homeBaseCity,
            countryDropdownLabel: 'Select country',
            stateDropdownLabel: 'Select state',
            cityDropdownLabel: 'Select city',
            dropdownDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
            ),
            disabledDropdownDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFAF7F5),
              border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
            ),
            selectedItemStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF3E1F11),
              fontWeight: FontWeight.w600,
            ),
            dropdownHeadingStyle: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
            dropdownItemStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF3E1F11),
            ),
            searchBarRadius: 10.0,
            onCountryChanged: (value) {
              setState(() {
                _homeBaseCountry = value.contains('   ')
                    ? value.split('   ').last
                    : value;
              });
            },
            onStateChanged: (value) {
              setState(() {
                _homeBaseState = value ?? '';
              });
            },
            onCityChanged: (value) {
              setState(() {
                _homeBaseCity = value ?? '';
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Current Location',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 6),
          CSCPickerPlus(
            layout: Layout.vertical,
            showStates: true,
            showCities: true,
            flagState: CountryFlag.DISABLE,
            currentCountry: getCountryForPicker(_currentLocationCountry),
            currentState: _currentLocationState,
            currentCity: _currentLocationCity,
            countryDropdownLabel: 'Select country',
            stateDropdownLabel: 'Select state',
            cityDropdownLabel: 'Select city',
            dropdownDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
            ),
            disabledDropdownDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFAF7F5),
              border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
            ),
            selectedItemStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF3E1F11),
              fontWeight: FontWeight.w600,
            ),
            dropdownHeadingStyle: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
            dropdownItemStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF3E1F11),
            ),
            searchBarRadius: 10.0,
            onCountryChanged: (value) {
              setState(() {
                _currentLocationCountry = value.contains('   ')
                    ? value.split('   ').last
                    : value;
              });
            },
            onStateChanged: (value) {
              setState(() {
                _currentLocationState = value ?? '';
              });
            },
            onCityChanged: (value) {
              setState(() {
                _currentLocationCity = value ?? '';
              });
            },
          ),
          const SizedBox(height: 24),

          // Section 5: Work Experience (Career Timeline)
          _buildSectionHeader('Work Experience (Optional)'),
          const SizedBox(height: 12),
          if (_careerTimeline.isNotEmpty) ...[
            ..._careerTimeline.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final subtitleParts = <String>[
                if ((item['startDate'] ?? '').toString().isNotEmpty ||
                    (item['endDate'] ?? '').toString().isNotEmpty)
                  '${item['startDate'] ?? ''} to ${item['endDate'] ?? ''}',
                if ((item['employmentType'] ?? '').toString().isNotEmpty)
                  item['employmentType'],
                if ((item['location'] ?? '').toString().isNotEmpty)
                  item['location'],
              ];
              final subtitleLine = subtitleParts
                  .where((s) => s.isNotEmpty)
                  .join(' \u00B7 ');
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFE8E2DD)),
                ),
                child: ListTile(
                  title: Text(
                    '${item['role']} at ${item['company']}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  subtitle: Text(
                    subtitleLine +
                        ((item['description'] ?? '').toString().isNotEmpty
                            ? '\n${item['description']}'
                            : ''),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _careerTimeline.removeAt(idx);
                      });
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E2DD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Work Experience',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _workCompanyController,
                  labelText: 'Company',
                  hintText: 'e.g. Google',
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _workRoleController,
                  labelText: 'Role / Job Title',
                  hintText: 'e.g. Software Engineer',
                ),
                const SizedBox(height: 8),
                // Employment Type Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _workEmploymentType,
                  decoration: InputDecoration(
                    labelText: 'Employment Type',
                    labelStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      color: Color(0xFF8C736B),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAF7F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF7A432D)),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: Color(0xFF3E1F11),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Full-time',
                      child: Text('Full-time'),
                    ),
                    DropdownMenuItem(
                      value: 'Part-time',
                      child: Text('Part-time'),
                    ),
                    DropdownMenuItem(
                      value: 'Self-employed',
                      child: Text('Self-employed'),
                    ),
                    DropdownMenuItem(
                      value: 'Freelance',
                      child: Text('Freelance'),
                    ),
                    DropdownMenuItem(
                      value: 'Contract',
                      child: Text('Contract'),
                    ),
                    DropdownMenuItem(
                      value: 'Internship',
                      child: Text('Internship'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _workEmploymentType = val);
                  },
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _workLocationController,
                  labelText: 'Location',
                  hintText: 'e.g. San Francisco, CA',
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _workDescController,
                  labelText: 'Description',
                  hintText: 'Describe key accomplishments...',
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A432D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (_workRoleController.text.trim().isEmpty ||
                          _workCompanyController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill Role and Company'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _careerTimeline.add({
                          'company': _workCompanyController.text.trim(),
                          'role': _workRoleController.text.trim(),
                          'employmentType': _workEmploymentType,
                          'location': _workLocationController.text.trim(),
                          'startDate': '',
                          'endDate': '',
                          'duration': '',
                          'description': _workDescController.text.trim(),
                        });
                        _workCompanyController.clear();
                        _workRoleController.clear();
                        _workEmploymentType = 'Full-time';
                        _workLocationController.clear();
                        _workStartDateController.clear();
                        _workEndDateController.clear();
                        _workDescController.clear();
                      });
                    },
                    child: const Text(
                      'Add Work Experience Entry',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 6: Education (Education Timeline)
          _buildSectionHeader('Education (Optional)'),
          const SizedBox(height: 12),
          if (_educationTimeline.isNotEmpty) ...[
            ..._educationTimeline.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFE8E2DD)),
                ),
                child: ListTile(
                  title: Text(
                    '${item['degree']} at ${item['school']}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  subtitle: Text(
                    ((item['startDate'] ?? '').toString().isNotEmpty ||
                            (item['endDate'] ?? '').toString().isNotEmpty)
                        ? '${item['startDate'] ?? ''} to ${item['endDate'] ?? ''}'
                        : '${item['duration'] ?? ''}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _educationTimeline.removeAt(idx);
                      });
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E2DD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Education',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _eduDegreeController,
                  labelText: 'Degree / Course',
                  hintText: 'e.g. B.S. in Computer Science',
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _eduSchoolController,
                  labelText: 'School / University',
                  hintText: 'e.g. Stanford University',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A432D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (_eduDegreeController.text.trim().isEmpty ||
                          _eduSchoolController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill Degree and School'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _educationTimeline.add({
                          'degree': _eduDegreeController.text.trim(),
                          'school': _eduSchoolController.text.trim(),
                          'startDate': '',
                          'endDate': '',
                          'duration': '',
                          'description': '',
                        });
                        _eduDegreeController.clear();
                        _eduSchoolController.clear();
                        _eduStartDateController.clear();
                        _eduEndDateController.clear();
                      });
                    },
                    child: const Text(
                      'Add Education Entry',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Complete Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: widget.completionMode
                  ? _handleProfileCompletion
                  : _handleEmailSignUp,
              child: Text(
                widget.completionMode
                    ? 'Complete Profile'
                    : 'Complete & Create Account',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF7A432D),
          ),
        ),
        const SizedBox(height: 4),
        const Divider(color: Color(0xFFE8E2DD), thickness: 1),
      ],
    );
  }



  Widget _buildDropdownField({
    required String label,
    String? currentValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Widget? secondaryField,
    String? hintText,
  }) {
    final List<String> safeItems = List<String>.from(items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Color(0xFF8C736B),
              fontSize: 13,
            ),
            floatingLabelStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Color(0xFF7A432D),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF7A432D),
                width: 1.5,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: currentValue != null && safeItems.contains(currentValue) ? currentValue : null,
              hint: hintText != null
                  ? Text(hintText, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF8C736B)))
                  : null,
              isExpanded: true,
              isDense: true,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7A432D)),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: Color(0xFF3E1F11),
              ),
              items: safeItems.map((String val) {
                return DropdownMenuItem<String?>(value: val, child: Text(val));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (secondaryField != null) ...[
          const SizedBox(height: 8),
          secondaryField,
        ],
      ],
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 60,
      );

      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
      });

      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      setState(() {
        _profileImageUrlController.text = dataUri;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image loaded successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load image: $e')));
      }
    }
  }

  Widget _buildFormView(double screenHeight, double screenWidth) {
    switch (_currentView) {
      case OnboardingView.signIn:
        return _buildSignInScreen(screenHeight, screenWidth);
      case OnboardingView.signUpStep1:
        return _buildSignUpStep1(screenHeight, screenWidth);
      case OnboardingView.signUpStep2:
        return _buildSignUpStep2(screenHeight, screenWidth);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      body: Stack(
        children: [
          // Subtle warm gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF8F4),
                    Color(0xFFFAF7F5),
                    Color(0xFFF5EDE6),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: isSmallScreen ? screenHeight * 0.02 : screenHeight * 0.03,
              ),
              child: _currentView == OnboardingView.slides
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header logo
                        const AppLogo(size: 26),
                        SizedBox(height: isSmallScreen ? screenHeight * 0.01 : screenHeight * 0.015),

                        // PageView for onboarding slides
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _onboardingData.length,
                            onPageChanged: (int index) {
                              setState(() {
                                _currentIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return OnboardingPage(
                                imagePath: _onboardingData[index]['image']!,
                                title: _onboardingData[index]['title']!,
                                subtitle: _onboardingData[index]['subtitle']!,
                                screenHeight: screenHeight,
                                isFinalPage:
                                    index == _onboardingData.length - 1,
                                onLinkedInTap: _handleLinkedInSignIn,
                                onSignUpEmailTap: () {
                                  setState(() {
                                    _currentView = OnboardingView.signUpStep1;
                                  });
                                },
                                onSignInEmailTap: () {
                                  setState(() {
                                    _currentView = OnboardingView.signIn;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 16),

                        // Bottom control bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Pill-style dot indicators
                            Row(
                              children: List.generate(
                                _onboardingData.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  margin: const EdgeInsets.only(right: 5),
                                  height: 6,
                                  width: _currentIndex == index ? 20 : 6,
                                  decoration: BoxDecoration(
                                    color: _currentIndex == index
                                        ? const Color(0xFF7A432D)
                                        : const Color(0xFFD5C4BB),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),

                            // Next / Skip buttons
                            if (_currentIndex < _onboardingData.length - 1)
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      _pageController.jumpToPage(
                                        _onboardingData.length - 1,
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      child: Text(
                                        'Skip',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF8C736B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () {
                                      _pageController.nextPage(
                                        duration: const Duration(milliseconds: 350),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7A432D),
                                        borderRadius: BorderRadius.circular(28),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF7A432D).withValues(alpha: 0.30),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'Next',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox(height: 32),
                          ],
                        ),
                      ],
                    )
                  : _buildFormView(screenHeight, screenWidth),
            ),
          ),

          // Loading Overlay during Sign In
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F5),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF7A432D).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                        strokeWidth: 2.5,
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final double screenHeight;
  final bool isFinalPage;
  final VoidCallback onLinkedInTap;
  final VoidCallback onSignUpEmailTap;
  final VoidCallback onSignInEmailTap;

  const OnboardingPage({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.screenHeight,
    required this.isFinalPage,
    required this.onLinkedInTap,
    required this.onSignUpEmailTap,
    required this.onSignInEmailTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = screenHeight < 700;
    final double titleSize = screenHeight < 640
        ? 26.0
        : screenHeight < 700
            ? 30.0
            : 36.0;
    final double imageRatio = isSmallScreen ? 0.27 : 0.32;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration image with subtle drop shadow card
          Container(
            height: screenHeight * imageRatio,
            margin: EdgeInsets.only(bottom: screenHeight * 0.025),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFFFFF5EE),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A432D).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Title Header — responsive font size
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3E1F11),
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: screenHeight * 0.012),

          // Subtitle with better line-height
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: isSmallScreen ? 14 : 15,
              color: const Color(0xFF6B5148),
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),

          // Final Page Sign In/Up options
          if (isFinalPage) ...[
            SizedBox(height: isSmallScreen ? screenHeight * 0.025 : screenHeight * 0.035),
            _buildLinkedInButton(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFAF7F5), Color(0xFFD5C4BB)],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8C736B),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFD5C4BB), Color(0xFFFAF7F5)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildEmailButtons(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkedInButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF7A432D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7A432D).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onLinkedInTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'in',
                style: TextStyle(
                  color: Color(0xFF7A432D),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFamily: 'PlusJakartaSans',
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with LinkedIn',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onSignUpEmailTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.mail_outline_rounded, color: Color(0xFF7A432D), size: 18),
                SizedBox(width: 10),
                Text(
                  'Sign Up with Email',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A432D),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onSignInEmailTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: Color(0xFF8C736B),
                ),
                children: [
                  TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Sign In',
                    style: TextStyle(
                      color: Color(0xFF7A432D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String getCountryForPicker(String? countryName) {
  if (countryName == null || countryName.isEmpty) return '';
  if (countryName.contains('   ')) return countryName;
  
  final Map<String, String> countryToEmoji = {
    'Afghanistan': 'ðŸ‡¦ðŸ‡«   Afghanistan',
    'Albania': 'ðŸ‡¦ðŸ‡±   Albania',
    'Algeria': 'ðŸ‡©ðŸ‡¿   Algeria',
    'Andorra': 'ðŸ‡¦ðŸ‡©   Andorra',
    'Angola': 'ðŸ‡¦ðŸ‡´   Angola',
    'Argentina': 'ðŸ‡¦ðŸ‡·   Argentina',
    'Armenia': 'ðŸ‡¦ðŸ‡²   Armenia',
    'Australia': 'ðŸ‡¦ðŸ‡º   Australia',
    'Austria': 'ðŸ‡¦ðŸ‡¹   Austria',
    'Azerbaijan': 'ðŸ‡¦ðŸ‡¿   Azerbaijan',
    'Bahamas': 'ðŸ‡§ðŸ‡¸   Bahamas',
    'Bahrain': 'ðŸ‡§ðŸ‡­   Bahrain',
    'Bangladesh': 'ðŸ‡§ðŸ‡©   Bangladesh',
    'Barbados': 'ðŸ‡§ðŸ‡§   Barbados',
    'Belarus': 'ðŸ‡§ðŸ‡¾   Belarus',
    'Belgium': 'ðŸ‡§ðŸ‡ª   Belgium',
    'Belize': 'ðŸ‡§ðŸ‡¿   Belize',
    'Benin': 'ðŸ‡§ðŸ‡¯   Benin',
    'Bhutan': 'ðŸ‡§ðŸ‡¹   Bhutan',
    'Bolivia': 'ðŸ‡§ðŸ‡´   Bolivia',
    'Bosnia and Herzegovina': 'ðŸ‡§ðŸ‡¦   Bosnia and Herzegovina',
    'Botswana': 'ðŸ‡§ðŸ‡¼   Botswana',
    'Brazil': 'ðŸ‡§ðŸ‡·   Brazil',
    'Brunei': 'ðŸ‡§ðŸ‡³   Brunei',
    'Bulgaria': 'ðŸ‡§ðŸ‡¬   Bulgaria',
    'Burkina Faso': 'ðŸ‡§ðŸ‡«   Burkina Faso',
    'Burundi': 'ðŸ‡§ðŸ‡®   Burundi',
    'Cambodia': 'ðŸ‡°ðŸ‡­   Cambodia',
    'Cameroon': 'ðŸ‡¨ðŸ‡²   Cameroon',
    'Canada': 'ðŸ‡¨ðŸ‡¦   Canada',
    'Cape Verde': 'ðŸ‡¨ðŸ‡»   Cape Verde',
    'Central African Republic': 'ðŸ‡¨ðŸ‡«   Central African Republic',
    'Chad': 'ðŸ‡¹ðŸ‡©   Chad',
    'Chile': 'ðŸ‡¨ðŸ‡±   Chile',
    'China': 'ðŸ‡¨ðŸ‡³   China',
    'Colombia': 'ðŸ‡¨ðŸ‡´   Colombia',
    'Comoros': 'ðŸ‡°ðŸ‡²   Comoros',
    'Congo': 'ðŸ‡¨ðŸ‡¬   Congo',
    'Costa Rica': 'ðŸ‡¨ðŸ‡·   Costa Rica',
    'Croatia': 'ðŸ‡­ðŸ‡·   Croatia',
    'Cuba': 'ðŸ‡¨ðŸ‡º   Cuba',
    'Cyprus': 'ðŸ‡¨ðŸ‡¾   Cyprus',
    'Czech Republic': 'ðŸ‡¨ðŸ‡¿   Czech Republic',
    'Denmark': 'ðŸ‡©ðŸ‡°   Denmark',
    'Djibouti': 'ðŸ‡©ðŸ‡¯   Djibouti',
    'Dominica': 'ðŸ‡©ðŸ‡²   Dominica',
    'Dominican Republic': 'ðŸ‡©ðŸ‡´   Dominican Republic',
    'Ecuador': 'ðŸ‡ªðŸ‡¨   Ecuador',
    'Egypt': 'ðŸ‡ªðŸ‡¬   Egypt',
    'El Salvador': 'ðŸ‡¸ðŸ‡»   El Salvador',
    'Equatorial Guinea': 'ðŸ‡¬ðŸ‡¶   Equatorial Guinea',
    'Eritrea': 'ðŸ‡ªðŸ‡·   Eritrea',
    'Estonia': 'ðŸ‡ªðŸ‡ª   Estonia',
    'Ethiopia': 'ðŸ‡ªðŸ‡¹   Ethiopia',
    'Fiji': 'ðŸ‡«ðŸ‡¯   Fiji',
    'Finland': 'ðŸ‡«ðŸ‡®   Finland',
    'France': 'ðŸ‡«ðŸ‡·   France',
    'Gabon': 'ðŸ‡¬ðŸ‡¦   Gabon',
    'Gambia': 'ðŸ‡¬ðŸ‡²   Gambia',
    'Georgia': 'ðŸ‡¬ðŸ‡ª   Georgia',
    'Germany': 'ðŸ‡©ðŸ‡ª   Germany',
    'Ghana': 'ðŸ‡¬ðŸ‡­   Ghana',
    'Greece': 'ðŸ‡¬ðŸ‡·   Greece',
    'Grenada': 'ðŸ‡¬ðŸ‡©   Grenada',
    'Guatemala': 'ðŸ‡¬ðŸ‡¹   Guatemala',
    'Guinea': 'ðŸ‡¬ðŸ‡³   Guinea',
    'Guinea-Bissau': 'ðŸ‡¬ðŸ‡¼   Guinea-Bissau',
    'Guyana': 'ðŸ‡¬ðŸ‡¾   Guyana',
    'Haiti': 'ðŸ‡­ðŸ‡¹   Haiti',
    'Honduras': 'ðŸ‡­ðŸ‡³   Honduras',
    'Hungary': 'ðŸ‡­ðŸ‡º   Hungary',
    'Iceland': 'ðŸ‡®ðŸ‡¸   Iceland',
    'India': 'ðŸ‡®ðŸ‡³   India',
    'Indonesia': 'ðŸ‡®ðŸ‡©   Indonesia',
    'Iran': 'ðŸ‡®ðŸ‡·   Iran',
    'Iraq': 'ðŸ‡®ðŸ‡¶   Iraq',
    'Ireland': 'ðŸ‡®ðŸ‡ª   Ireland',
    'Israel': 'ðŸ‡®ðŸ‡±   Israel',
    'Italy': 'ðŸ‡®ðŸ‡¹   Italy',
    'Jamaica': 'ðŸ‡¯ðŸ‡²   Jamaica',
    'Japan': 'ðŸ‡¯ðŸ‡µ   Japan',
    'Jordan': 'ðŸ‡¯ðŸ‡´   Jordan',
    'Kazakhstan': 'ðŸ‡°ðŸ‡¿   Kazakhstan',
    'Kenya': 'ðŸ‡°ðŸ‡ª   Kenya',
    'Kiribati': 'ðŸ‡°ðŸ‡®   Kiribati',
    'Kuwait': 'ðŸ‡°ðŸ‡¼   Kuwait',
    'Kyrgyzstan': 'ðŸ‡°ðŸ‡¬   Kyrgyzstan',
    'Laos': 'ðŸ‡±ðŸ‡¦   Laos',
    'Latvia': 'ðŸ‡±ðŸ‡»   Latvia',
    'Lebanon': 'ðŸ‡±ðŸ‡§   Lebanon',
    'Lesotho': 'ðŸ‡±ðŸ‡¸   Lesotho',
    'Liberia': 'ðŸ‡±ðŸ‡·   Liberia',
    'Libya': 'ðŸ‡±ðŸ‡¾   Libya',
    'Liechtenstein': 'ðŸ‡±ðŸ‡®   Liechtenstein',
    'Lithuania': 'ðŸ‡±ðŸ‡¹   Lithuania',
    'Luxembourg': 'ðŸ‡±ðŸ‡º   Luxembourg',
    'Macedonia': 'ðŸ‡²ðŸ‡°   Macedonia',
    'Madagascar': 'ðŸ‡²ðŸ‡¬   Madagascar',
    'Malawi': 'ðŸ‡²ðŸ‡¼   Malawi',
    'Malaysia': 'ðŸ‡²ðŸ‡¾   Malaysia',
    'Maldives': 'ðŸ‡²ðŸ‡»   Maldives',
    'Mali': 'ðŸ‡²ðŸ‡±   Mali',
    'Malta': 'ðŸ‡²ðŸ‡¹   Malta',
    'Marshall Islands': 'ðŸ‡²ðŸ‡­   Marshall Islands',
    'Mauritania': 'ðŸ‡²ðŸ‡·   Mauritania',
    'Mauritius': 'ðŸ‡²ðŸ‡º   Mauritius',
    'Mexico': 'ðŸ‡²ðŸ‡½   Mexico',
    'Micronesia': 'ðŸ‡«ðŸ‡²   Micronesia',
    'Moldova': 'ðŸ‡²ðŸ‡©   Moldova',
    'Monaco': 'ðŸ‡²ðŸ‡¨   Monaco',
    'Mongolia': 'ðŸ‡²ðŸ‡³   Mongolia',
    'Montenegro': 'ðŸ‡²ðŸ‡ª   Montenegro',
    'Morocco': 'ðŸ‡²ðŸ‡¦   Morocco',
    'Mozambique': 'ðŸ‡²ðŸ‡¿   Mozambique',
    'Myanmar': 'ðŸ‡²ðŸ‡²   Myanmar',
    'Namibia': 'ðŸ‡³ðŸ‡¦   Namibia',
    'Nauru': 'ðŸ‡³ðŸ‡·   Nauru',
    'Nepal': 'ðŸ‡³ðŸ‡µ   Nepal',
    'Netherlands': 'ðŸ‡³ðŸ‡±   Netherlands',
    'New Zealand': 'ðŸ‡³ðŸ‡¿   New Zealand',
    'Nicaragua': 'ðŸ‡³ðŸ‡®   Nicaragua',
    'Niger': 'ðŸ‡³ðŸ‡ª   Niger',
    'Nigeria': 'ðŸ‡³ðŸ‡¬   Nigeria',
    'North Korea': 'ðŸ‡°ðŸ‡µ   North Korea',
    'Norway': 'ðŸ‡³ðŸ‡´   Norway',
    'Oman': 'ðŸ‡´ðŸ‡²   Oman',
    'Pakistan': 'ðŸ‡µðŸ‡°   Pakistan',
    'Palau': 'ðŸ‡µðŸ‡¼   Palau',
    'Panama': 'ðŸ‡µðŸ‡¦   Panama',
    'Papua New Guinea': 'ðŸ‡µðŸ‡¬   Papua New Guinea',
    'Paraguay': 'ðŸ‡µðŸ‡¾   Paraguay',
    'Peru': 'ðŸ‡µðŸ‡ª   Peru',
    'Philippines': 'ðŸ‡µðŸ‡­   Philippines',
    'Poland': 'ðŸ‡µðŸ‡±   Poland',
    'Portugal': 'ðŸ‡µðŸ‡¹   Portugal',
    'Qatar': 'ðŸ‡¶ðŸ‡¦   Qatar',
    'Romania': 'ðŸ‡·ðŸ‡´   Romania',
    'Russia': 'ðŸ‡·ðŸ‡º   Russia',
    'Rwanda': 'ðŸ‡·ðŸ‡¼   Rwanda',
    'Samoa': 'ðŸ‡¼ðŸ‡¸   Samoa',
    'San Marino': 'ðŸ‡¸ðŸ‡²   San Marino',
    'Saudi Arabia': 'ðŸ‡¸ðŸ‡¦   Saudi Arabia',
    'Senegal': 'ðŸ‡¸ðŸ‡³   Senegal',
    'Serbia': 'ðŸ‡·ðŸ‡¸   Serbia',
    'Seychelles': 'ðŸ‡¸ðŸ‡¨   Seychelles',
    'Sierra Leone': 'ðŸ‡¸ðŸ‡±   Sierra Leone',
    'Singapore': 'ðŸ‡¸ðŸ‡¬   Singapore',
    'Slovakia': 'ðŸ‡¸ðŸ‡°   Slovakia',
    'Slovenia': 'ðŸ‡¸ðŸ‡®   Slovenia',
    'Solomon Islands': 'ðŸ‡¸ðŸ‡§   Solomon Islands',
    'Somalia': 'ðŸ‡¸ðŸ‡´   Somalia',
    'South Africa': 'ðŸ‡¿ðŸ‡¦   South Africa',
    'South Korea': 'ðŸ‡°ðŸ‡·   South Korea',
    'South Sudan': 'ðŸ‡¸ðŸ‡¸   South Sudan',
    'Spain': 'ðŸ‡ªðŸ‡¸   Spain',
    'Sri Lanka': 'ðŸ‡±ðŸ‡°   Sri Lanka',
    'Sudan': 'ðŸ‡¸ðŸ‡©   Sudan',
    'Suriname': 'ðŸ‡¸ðŸ‡·   Suriname',
    'Swaziland': 'ðŸ‡¸ðŸ‡¿   Swaziland',
    'Sweden': 'ðŸ‡¸ðŸ‡ª   Sweden',
    'Switzerland': 'ðŸ‡¨ðŸ‡­   Switzerland',
    'Syria': 'ðŸ‡¸ðŸ‡¾   Syria',
    'Taiwan': 'ðŸ‡¹ðŸ‡¼   Taiwan',
    'Tajikistan': 'ðŸ‡¹ðŸ‡¯   Tajikistan',
    'Tanzania': 'ðŸ‡¹ðŸ‡¿   Tanzania',
    'Thailand': 'ðŸ‡¹ðŸ‡­   Thailand',
    'Togo': 'ðŸ‡¹ðŸ‡¬   Togo',
    'Tonga': 'ðŸ‡¹ðŸ‡´   Tonga',
    'Trinidad and Tobago': 'ðŸ‡¹ðŸ‡¹   Trinidad and Tobago',
    'Tunisia': 'ðŸ‡¹ðŸ‡³   Tunisia',
    'Turkey': 'ðŸ‡¹ðŸ‡·   Turkey',
    'Turkmenistan': 'ðŸ‡¹ðŸ‡²   Turkmenistan',
    'Tuvalu': 'ðŸ‡¹ðŸ‡»   Tuvalu',
    'Uganda': 'ðŸ‡ºðŸ‡¬   Uganda',
    'Ukraine': 'ðŸ‡ºðŸ‡¦   Ukraine',
    'United Arab Emirates': 'ðŸ‡¦ðŸ‡ª   United Arab Emirates',
    'United Kingdom': 'ðŸ‡¬ðŸ‡§   United Kingdom',
    'United States': 'ðŸ‡ºðŸ‡¸   United States',
    'Uruguay': 'ðŸ‡ºðŸ‡¾   Uruguay',
    'Uzbekistan': 'ðŸ‡ºðŸ‡¿   Uzbekistan',
    'Vanuatu': 'ðŸ‡»ðŸ‡º   Vanuatu',
    'Vatican City': 'ðŸ‡»ðŸ‡¦   Vatican City',
    'Venezuela': 'ðŸ‡»ðŸ‡ª   Venezuela',
    'Vietnam': 'ðŸ‡»ðŸ‡³   Vietnam',
    'Yemen': 'ðŸ‡¾ðŸ‡ª   Yemen',
    'Zambia': 'ðŸ‡¿ðŸ‡²   Zambia',
    'Zimbabwe': 'ðŸ‡¿ðŸ‡¼   Zimbabwe',
  };
  return countryToEmoji[countryName] ?? countryName;
}
