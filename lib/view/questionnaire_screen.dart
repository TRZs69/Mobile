import 'package:flutter/material.dart';
import 'package:app/utils/colors.dart';
import 'package:app/service/evaluation_service.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoadingStatus = true;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;

  // Questions based on SDT (Evaluasi Bab 8)
  final List<String> _likertQuestions = [
    "Saya merasa memiliki kendali atas cara saya belajar (Autonomy)",
    "Tantangan soal terasa sesuai dengan kemampuan saya (Competence)",
    "Saya merasa berkembang setelah menggunakan LeveLearn (Competence)",
    "Berinteraksi dengan Levely membuat saya lebih terhubung dengan materi (Relatedness)",
    "Saya aktif menyelesaikan materi dan soal di LeveLearn (Behavioral Engagement)",
    "Saya berpikir lebih dalam tentang materi saat menggunakan LeveLearn (Cognitive Engagement)",
    "Saya menikmati pengalaman belajar di LeveLearn (Emotional Engagement)",
    "Chatbot AI dan gamifikasi adaptif membantu saya belajar lebih baik (Overall)"
  ];

  final Map<int, int> _likertAnswers = {};

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await EvaluationService.checkHasSubmitted();
    if (mounted) {
      setState(() {
        _hasSubmitted = status;
        _isLoadingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionnaire Evaluasi', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/pictures/background-pattern.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoadingStatus
            ? const Center(child: CircularProgressIndicator())
            : _hasSubmitted
                ? _buildAlreadySubmitted()
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: ListView.builder(
                        itemCount: _likertQuestions.length + 1, // Likert + Submit
                        itemBuilder: (context, index) {
                // Submit Button
                if (index == _likertQuestions.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isSubmitting ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          if (_likertAnswers.length < _likertQuestions.length) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Mohon isi semua pertanyaan pilihan 1-5.', style: TextStyle(fontFamily: 'DIN_Next_Rounded'))),
                             );
                             return;
                          }
                          _formKey.currentState!.save();
                          
                          setState(() {
                            _isSubmitting = true;
                          });

                          // Map answers to backend keys q1...q8
                          Map<String, int> payload = {};
                          for (int i = 0; i < 8; i++) {
                            payload['q${i + 1}'] = _likertAnswers[i]!;
                          }

                          bool success = await EvaluationService.submitQuestionnaire(payload);
                          
                          setState(() {
                            _isSubmitting = false;
                          });

                          if (success) {
                            _showSuccessDialog();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gagal mengirimkan evaluasi. Silakan coba lagi.', style: TextStyle(fontFamily: 'DIN_Next_Rounded'))),
                            );
                          }
                        }
                      },
                      child: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Submit Evaluasi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'DIN_Next_Rounded',
                              fontWeight: FontWeight.bold
                            ),
                          ),
                    ),
                  );
                }

                // Likert Questions
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _likertQuestions[index],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'DIN_Next_Rounded',
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("1\nSangat\nKurang", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'DIN_Next_Rounded')),
                            ...List.generate(5, (optionIndex) {
                              int value = optionIndex + 1;
                              bool isSelected = _likertAnswers[index] == value;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _likertAnswers[index] = value;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primaryColor : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                    border: isSelected 
                                      ? Border.all(color: AppColors.secondaryColor, width: 2) 
                                      : Border.all(color: Colors.grey.shade300, width: 1),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    value.toString(),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'DIN_Next_Rounded'
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const Text("5\nSangat\nBaik", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'DIN_Next_Rounded')),
                          ],
                        ),
                        if (_likertAnswers[index] == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.red.shade400),
                                const SizedBox(width: 4),
                                Text(
                                  'Wajib diisi',
                                  style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontFamily: 'DIN_Next_Rounded'),
                                ),
                              ],
                            ),
                          )
                        else 
                          const SizedBox(height: 26) // Keep spacing consistent when answered
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Terima Kasih!', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
        content: const Text(
          'Evaluasi Anda telah kami terima. Terima kasih telah membantu penilaian LeveLearn!',
          style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Pop dialog
              Navigator.of(context).pop(); // Pop questionnaire screen
            },
            child: const Text('Tutup', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadySubmitted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: AppColors.primaryColor),
            const SizedBox(height: 24),
            const Text(
              'Terima Kasih!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'DIN_Next_Rounded',
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Anda sudah memberikan respon evaluasi ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'DIN_Next_Rounded',
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kembali', style: TextStyle(fontSize: 16, color: Colors.white, fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
