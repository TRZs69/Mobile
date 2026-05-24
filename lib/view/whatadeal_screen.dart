import 'package:app/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class WhatADealScreen extends StatefulWidget {
  final String message;

  const WhatADealScreen({super.key, required this.message});

  @override
  State<WhatADealScreen> createState() => _WhatADealScreenState();
}

class _WhatADealScreenState extends State<WhatADealScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
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
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.celebration,
                      color: AppColors.secondaryColor, size: 100),
                  const SizedBox(height: 20),
                  Text(
                    "What a Deal!",
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
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all<Color>(
                            AppColors.primaryColor)),
                    child: Text("Ayo, dapatkan lebih banyak badge!",
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
