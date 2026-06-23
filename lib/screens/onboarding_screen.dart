import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  String? _selectedIndustry = 'Technology';
  String? _selectedTravelFrequency = 'Occasional';

  // Home Base dependent states
  String _homeBaseCountry = 'India';
  String _homeBaseState = 'Andhra Pradesh';
  String _homeBaseCity = 'Vijayawada';

  // Current Location dependent states
  String _currentLocationCountry = 'India';
  String _currentLocationState = 'Andhra Pradesh';
  String _currentLocationCity = 'Vijayawada';

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

  // Intents selectable checkboxes/chips
  final List<Map<String, dynamic>> _intentsSelection = [
    {'label': 'Raising Seed', 'selected': false},
    {'label': 'Hiring CTO', 'selected': false},
    {'label': 'Open to coffee', 'selected': false},
    {'label': 'B2B partnerships', 'selected': false},
  ];

  final List<Map<String, String>> _onboardingData = [
    {
      'image': 'assets/images/boarding_pass_illustration.png',
      'title': 'Welcome to\nBoarding Pause',
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
        // Sync intents selection
        for (final intentLabel in profile.intents) {
          final idx = _intentsSelection.indexWhere(
            (item) => item['label'] == intentLabel,
          );
          if (idx != -1) {
            _intentsSelection[idx]['selected'] = true;
          }
        }
      }
    }
  }

  @override
  void dispose() {
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

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().signInWithEmail(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Authentication failed'),
            backgroundColor: const Color(0xFF7A432D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: $e'),
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

  void _handleEmailSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
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

    // Parse intents
    final List<String> selectedIntents = _intentsSelection
        .where((item) => item['selected'] == true)
        .map((item) => item['label'] as String)
        .toList();

    // Validate fields before sign up
    if (role.isEmpty ||
        company.isEmpty ||
        experience.isEmpty ||
        bio.isEmpty ||
        expertiseList.isEmpty ||
        selectedIntents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all professional details, skills, experience, bio, and select at least one interest.',
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
        intents: selectedIntents,
        skills: expertiseList,
        interests: selectedIntents,
        careerTimeline: _careerTimeline,
        educationTimeline: _educationTimeline,
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

    // Parse intents
    final List<String> selectedIntents = _intentsSelection
        .where((item) => item['selected'] == true)
        .map((item) => item['label'] as String)
        .toList();

    // Validate fields before complete
    if (role.isEmpty ||
        company.isEmpty ||
        experience.isEmpty ||
        bio.isEmpty ||
        expertiseList.isEmpty ||
        selectedIntents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all professional details, skills, experience, bio, and select at least one interest.',
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
          intents: selectedIntents,
          skills: expertiseList,
          interests: selectedIntents,
          careerTimeline: _careerTimeline,
          educationTimeline: _educationTimeline,
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

  Widget _buildIndicatorDot({required bool isActive}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? const Color(0xFFB06F4D) : const Color(0xFFE8E2DD),
      ),
    );
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
        suffixIcon: readOnly
            ? const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF7A432D),
                size: 18,
              )
            : null,
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
            'Sign in to your Boarding Pause account to continue connecting.',
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
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            labelText: 'Password',
            hintText: 'Enter your password',
            obscureText: true,
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
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            labelText: 'Password',
            hintText: 'Min 6 characters',
            obscureText: true,
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
                  currentValue: _selectedIndustry!,
                  items: _industries,
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
            'Select Active Intents / Interests:',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _intentsSelection.map((intent) {
              final bool isSelected = intent['selected'];
              return ChoiceChip(
                label: Text(
                  intent['label'],
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF5C473E),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF7A432D),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF7A432D)
                        : const Color(0xFFE8E2DD),
                  ),
                ),
                onSelected: (bool selected) {
                  setState(() {
                    intent['selected'] = selected;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Section 4: Location & Travel
          _buildSectionHeader('Location & Travel'),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Travel Frequency',
            currentValue: _selectedTravelFrequency!,
            items: _travelFrequencies,
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
            currentCountry: _homeBaseCountry,
            currentState: _homeBaseState,
            currentCity: _homeBaseCity,
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
            currentCountry: _currentLocationCountry,
            currentState: _currentLocationState,
            currentCity: _currentLocationCity,
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
                  controller: _workStartDateController,
                  labelText: 'From',
                  hintText: 'Select From date',
                  readOnly: true,
                  onTap: () => _selectDate(context, _workStartDateController),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _workEndDateController,
                  labelText: 'To',
                  hintText: 'Select To date',
                  readOnly: true,
                  onTap: () => _selectDate(
                    context,
                    _workEndDateController,
                    isEndDate: true,
                  ),
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
                          'startDate': _workStartDateController.text.trim(),
                          'endDate': _workEndDateController.text.trim(),
                          'duration':
                              '${_workStartDateController.text.trim()} to ${_workEndDateController.text.trim()}',
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
                _buildTextField(
                  controller: _eduStartDateController,
                  labelText: 'From',
                  hintText: 'Select From date',
                  readOnly: true,
                  onTap: () => _selectDate(context, _eduStartDateController),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _eduEndDateController,
                  labelText: 'To',
                  hintText: 'Select To date',
                  readOnly: true,
                  onTap: () => _selectDate(
                    context,
                    _eduEndDateController,
                    isEndDate: true,
                  ),
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
                      if (_eduStartDateController.text.trim().isEmpty ||
                          _eduEndDateController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill From and To dates'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _educationTimeline.add({
                          'degree': _eduDegreeController.text.trim(),
                          'school': _eduSchoolController.text.trim(),
                          'startDate': _eduStartDateController.text.trim(),
                          'endDate': _eduEndDateController.text.trim(),
                          'duration':
                              '${_eduStartDateController.text.trim()} to ${_eduEndDateController.text.trim()}',
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

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller, {
    bool isEndDate = false,
  }) async {
    if (isEndDate) {
      final String? result = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'Select End Date',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Choose if this is your current position or select a specific date.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'Present'),
                child: const Text(
                  'Present',
                  style: TextStyle(color: Color(0xFF7A432D)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'Select'),
                child: const Text(
                  'Select Date',
                  style: TextStyle(color: Color(0xFF7A432D)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          );
        },
      );
      if (result == 'Present') {
        controller.text = 'Present';
        return;
      } else if (result == null) {
        return;
      }
    }

    if (!mounted) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7A432D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF3E1F11),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7A432D),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      controller.text = '${months[picked.month - 1]} ${picked.year}';
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String currentValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Widget? secondaryField,
  }) {
    final List<String> safeItems = List<String>.from(items);
    if (currentValue.isNotEmpty && !safeItems.contains(currentValue)) {
      safeItems.add(currentValue);
    }
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
            child: DropdownButton<String>(
              value: safeItems.contains(currentValue)
                  ? currentValue
                  : (safeItems.isNotEmpty ? safeItems.first : null),
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
                return DropdownMenuItem<String>(value: val, child: Text(val));
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

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: screenHeight * 0.03,
              ),
              child: _currentView == OnboardingView.slides
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header text
                        const AppLogo(size: 28),
                        SizedBox(height: screenHeight * 0.015),

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
                        SizedBox(height: screenHeight * 0.02),

                        // Bottom control bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Dot indicators
                            Row(
                              children: List.generate(
                                _onboardingData.length,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: _buildIndicatorDot(
                                    isActive: _currentIndex == index,
                                  ),
                                ),
                              ),
                            ),

                            // Next Button
                            if (_currentIndex < _onboardingData.length - 1)
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      _pageController.jumpToPage(
                                        _onboardingData.length - 1,
                                      );
                                    },
                                    child: const Text(
                                      'Skip',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      _pageController.nextPage(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'Next',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF3E1F11),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Color(0xFF3E1F11),
                                            size: 20,
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
              color: Colors.black.withValues(alpha: 0.4),
              child: Center(
                child: Card(
                  color: const Color(0xFFFAF7F5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: Color(0xFF7A432D),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF7A432D),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E1F11),
                          ),
                        ),
                      ],
                    ),
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration image
          SizedBox(
            height: screenHeight * 0.35,
            child: Center(child: Image.asset(imagePath, fit: BoxFit.contain)),
          ),
          SizedBox(height: screenHeight * 0.03),

          // Title Header
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3E1F11),
              height: 1.15,
            ),
          ),
          SizedBox(height: screenHeight * 0.015),

          // Subtitle
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              color: Color(0xFF5C473E),
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),

          // Final Page Sign In/Up options
          if (isFinalPage) ...[
            SizedBox(height: screenHeight * 0.03),
            _buildLinkedInButton(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: const Color(0xFFE8E2DD))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: const Color(0xFFE8E2DD))),
              ],
            ),
            const SizedBox(height: 16),
            _buildEmailButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkedInButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF7A432D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
                borderRadius: BorderRadius.circular(3),
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
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFAF7F5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
              ),
            ),
            onPressed: onSignUpEmailTap,
            child: const Text(
              'Sign Up with Email',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7A432D),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onSignInEmailTap,
          child: const Text(
            'Already have an account? Sign In',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7A432D),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
