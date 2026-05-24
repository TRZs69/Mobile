import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../utils/colors.dart';

class CongratulationsScreen extends StatefulWidget {
  final String message;
  final VoidCallback? onContinue;

  const CongratulationsScreen(
      {super.key, required this.message, this.onContinue});

  @override
  _CongratulationsScreenState createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 10));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('lib/assets/pixels/star.png', height: 100),
                  const SizedBox(height: 20),
                  Text(
                    "Congratulations!",
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                        fontFamily: 'DIN_Next_Rounded'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontFamily: 'DIN_Next_Rounded'),
                  ),
                  const SizedBox(height: 30),
                  if (widget.onContinue != null)
                    ElevatedButton(
                      onPressed: widget.onContinue,
                      style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all<Color>(
                              AppColors.primaryColor)),
                      child: Text("Ayo Lanjutkan ke Level Berikutnya",
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontFamily: 'DIN_Next_Rounded')),
                    ),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 25,
            shouldLoop: true,
            colors: [
              AppColors.primaryColor,
              AppColors.secondaryColor,
              AppColors.accentColor,
              Colors.blue,
              Colors.green,
              Colors.purple
            ],
          ),
        ],
      ),
    );
  }
}
