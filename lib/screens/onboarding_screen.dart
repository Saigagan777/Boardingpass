import 'package:flutter/material.dart';
import '../state_manager.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isLoading = false;

  final List<Map<String, String>> _onboardingData = [
    {
      'image': 'assets/images/boarding_pass_illustration.png',
      'title': 'Welcome to\nBoarding Pass',
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleLinkedInSignIn() {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading/redirection delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
      });
      AppStateManager().logIn({
        'sub': 'li_85a9s8f9a2',
        'name': 'Rohan Mehta',
        'given_name': 'Rohan',
        'family_name': 'Mehta',
        'picture': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&auto=format&fit=crop&q=80',
        'headline': 'Founder | SME Lending Platform',
        'email': 'rohan.mehta@example.com',
        'email_verified': 'true',
        'location': 'Bengaluru, India',
      });
    });
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header text
                  const Text(
                    'Boarding Pass',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
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
                          isFinalPage: index == _onboardingData.length - 1,
                          onLinkedInTap: _handleLinkedInSignIn,
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
                            child: _buildIndicatorDot(isActive: _currentIndex == index),
                          ),
                        ),
                      ),

                      // Next Button
                      if (_currentIndex < _onboardingData.length - 1)
                        InkWell(
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
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
                        )
                      else
                        const SizedBox(height: 32),
                    ],
                  ),
                ],
              ),
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
                    side: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Connecting to LinkedIn...',
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
}

class OnboardingPage extends StatefulWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final double screenHeight;
  final bool isFinalPage;
  final VoidCallback onLinkedInTap;

  const OnboardingPage({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.screenHeight,
    required this.isFinalPage,
    required this.onLinkedInTap,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _isSignUpMode = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
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

    if (!_isSignUpMode) {
      // Sign In mode
      if (email == 'Gagan@gmail.com' && password == 'mypass@123') {
        AppStateManager().logIn({
          'sub': 'admin_gagan',
          'name': 'Gagan (Admin)',
          'given_name': 'Gagan',
          'family_name': 'Admin',
          'email': 'Gagan@gmail.com',
          'location': 'Bengaluru, India',
        }, isAdmin: true);
      } else {
        // Log in as normal user
        AppStateManager().logIn({
          'sub': 'normal_user',
          'name': email.split('@')[0],
          'given_name': email.split('@')[0],
          'family_name': '',
          'email': email,
          'location': 'Bengaluru, India',
        }, isAdmin: false);
      }
    } else {
      // Sign Up mode
      AppStateManager().logIn({
        'sub': 'new_user',
        'name': email.split('@')[0],
        'given_name': email.split('@')[0],
        'family_name': '',
        'email': email,
        'location': 'Bengaluru, India',
      }, isAdmin: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration image
          SizedBox(
            height: widget.screenHeight * 0.35,
            child: Center(
              child: Image.asset(
                widget.imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: widget.screenHeight * 0.03),

          // Title Header
          Text(
            widget.title,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3E1F11),
              height: 1.15,
            ),
          ),
          SizedBox(height: widget.screenHeight * 0.015),

          // Subtitle
          Text(
            widget.subtitle,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              color: Color(0xFF5C473E),
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),

          // Final Page Sign In/Up options
          if (widget.isFinalPage) ...[
            SizedBox(height: widget.screenHeight * 0.03),
            _buildLinkedInButton(context),
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
            _buildForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkedInButton(BuildContext context) {
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
        onPressed: widget.onLinkedInTap,
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

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Switch between SignIn and SignUp
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSignUpMode = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: !_isSignUpMode
                      ? const Border(bottom: BorderSide(color: Color(0xFF7A432D), width: 2))
                      : null,
                ),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.bold,
                    color: !_isSignUpMode ? const Color(0xFF7A432D) : const Color(0xFF8C736B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 30),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSignUpMode = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: _isSignUpMode
                      ? const Border(bottom: BorderSide(color: Color(0xFF7A432D), width: 2))
                      : null,
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.bold,
                    color: _isSignUpMode ? const Color(0xFF7A432D) : const Color(0xFF8C736B),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Email Field
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email Address',
            labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B), fontSize: 13),
            floatingLabelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
        ),
        const SizedBox(height: 12),
        // Password Field
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B), fontSize: 13),
            floatingLabelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
        ),
        const SizedBox(height: 18),
        // Action Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A432D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: _handleSubmit,
            child: Text(
              _isSignUpMode ? 'Create Account' : 'Sign In',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
