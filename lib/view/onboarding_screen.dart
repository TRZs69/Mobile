// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously
import 'package:app/model/onboarding.dart';
import 'package:app/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingModel> onboardingData = [
    OnboardingModel(
        image: 'lib/assets/vectors/socialshare-primary.png',
        title: 'Extra Time College',
        description:
            'Tingkatkan Pemahaman Kuliahmu, Kapan Saja, Di Mana Saja!'),
    OnboardingModel(
        image: 'lib/assets/vectors/gaming-primary.png',
        title: 'Gamified Learning',
        description: 'Belajar Sambil Bermain, Jadikan Ilmu sebagai Temanmu!'),
    OnboardingModel(
        image: 'lib/assets/vectors/socialinfluencer-primary.png',
        title: 'Levelearn!',
        description: 'Level Up Your Learn! Become Advanced!'),
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final safeBottom = mediaQuery.viewPadding.bottom;
    final contentMaxWidth = screenWidth > 600 ? 520.0 : screenWidth;
    final ctaAreaHeight = isLandscape ? 96.0 : 116.0;
    final bottomReservedSpace = ctaAreaHeight + safeBottom + 12.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/pictures/background-pattern.png',
              fit: BoxFit.cover,
            ),
          ),
          PageView.builder(
            controller: _pageController,
            itemCount: onboardingData.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              return OnboardingPage(
                model: onboardingData[index],
                bottomReservedSpace: bottomReservedSpace,
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: onboardingData.length,
                      effect: WormEffect(
                        dotColor: Colors.grey,
                        activeDotColor: AppColors.primaryColor,
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: isLandscape ? 46 : 50,
                      child: ElevatedButton(
                        onPressed: _currentPage < onboardingData.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.ease,
                                );
                              }
                            : () async {
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool('firstLaunch', false);

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => LoginScreen()),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: Text(
                          _currentPage < onboardingData.length - 1
                              ? 'Selanjutnya'
                              : 'Mulai',
                          style: TextStyle(
                            fontFamily: 'DIN_Next_Rounded',
                            color: Colors.white,
                          ),
                        ),
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
  final OnboardingModel model;
  final double bottomReservedSpace;

  const OnboardingPage({
    super.key,
    required this.model,
    required this.bottomReservedSpace,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final imageHeight = isLandscape
        ? (screenHeight * 0.22).clamp(110.0, 180.0).toDouble()
        : (screenHeight * 0.30).clamp(180.0, 300.0).toDouble();
    final titleSize = isLandscape ? 20.0 : 24.0;
    final descriptionSize = isLandscape ? 14.0 : 16.0;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: screenHeight,
        ),
        child: IntrinsicHeight(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(flex: isLandscape ? 1 : 2),
              Container(
                color: Colors.white,
                height: isLandscape ? 56 : 112,
              ),
              Image.asset(
                model.image,
                height: imageHeight,
              ),
              SizedBox(height: 20),
              Text(
                model.title,
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'DIN_Next_Rounded',
                      color: AppColors.primaryColor,
                      fontSize: titleSize,
                    ),
              ),
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  model.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontFamily: 'DIN_Next_Rounded',
                        fontSize: descriptionSize,
                      ),
                ),
              ),
              Spacer(flex: isLandscape ? 2 : 3),
              SizedBox(height: bottomReservedSpace),
            ],
          ),
        ),
      ),
    );
  }
}
