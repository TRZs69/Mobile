import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'package:app/model/chapter_status.dart';
import 'package:app/model/learning_material.dart';
import 'package:app/service/chapter_service.dart';
import 'package:app/service/user_chapter_service.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/chatbot_screen.dart';

class MaterialScreen extends StatefulWidget {
  final ChapterStatus status;
  final String chapterName;
  final Function(bool) updateProgress;
  final Function(ChapterStatus) updateStatus;
  const MaterialScreen({
    super.key,
    required this.status,
    required this.chapterName,
    required this.updateProgress,
    required this.updateStatus
  });

  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen> {
  LearningMaterial? material;
  late ScrollController _scrollController;
  double progressValue = 0.0;
  bool showDialogMaterialOnce = false;
  late ChapterStatus status;

  @override
  void initState() {
    getMaterial(widget.status.chapterId);
    showDialogMaterialOnce = widget.status.materialDone;
    progressValue = widget.status.materialDone ? 1.0 : 0;
    status = widget.status;
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(updateProgressMaterial);

  }

  void getMaterial(int id) async {
    final resultMaterial = await ChapterService.getMaterialByChapterId(id);
    setState(() {
      material = resultMaterial;
    });
  }

  updateProgressMaterial() {
    double currentProgressValue = _scrollController.offset / _scrollController.position.maxScrollExtent;

    if (currentProgressValue < 0.0) {
      currentProgressValue = 0.0;
    } else if (currentProgressValue > 1.0) {
      currentProgressValue = 1.0;
    }

    setState(() {
      progressValue = currentProgressValue <= progressValue ? progressValue : currentProgressValue;
      if (progressValue >= 1.0 && !showDialogMaterialOnce) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCompletionDialog(context, "Yeay kamu berhasil menyelesaikan Materi, Ayo lanjutkan ke bagian Assessment", false, false);
        });
        showDialogMaterialOnce = true;
      }
    });

    if (progressValue >= 1.0) {
      widget.updateProgress(true);
      status.materialDone = true;
      widget.updateStatus(status);
      updateStatus();
    }
  }

  Future<void> updateStatus() async {
    status = await UserChapterService.updateChapterStatus(status.id, status);
  }

  void showCompletionDialog(BuildContext context, String message, bool isAssessment, bool isAssignment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            "Progress Completed!",
            style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset('lib/assets/pixels/check.png', height: 72),
                SizedBox(height: 16,),
                Text(
                  message,
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  "OK",
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
        if (material != null)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/pictures/background-pattern.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    SizedBox(height: 16),
                    _buildHTMLContent(material!.content),
                    SizedBox(height: 16), // Prevents layout overflow
                  ],
                ),
              ),
            ),
          ),

        if (material == null)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/pictures/background-pattern.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('lib/assets/pixels/material-pixel.png', height: 50),
                    SizedBox(height: 16),
                    Text(
                      "Materi belum tersedia",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryColor,
                        fontFamily: 'DIN_Next_Rounded',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Untuk saat ini, materi untuk Level ${widget.chapterName} belum ada.",
                      style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
    floatingActionButton: material != null
        ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatbotScreen(
                    // Reset visible chat while keeping chapter-specific
                    // chatbot sessions isolated from other chapters.
                    startFresh: true,
                    materialId: material!.id,
                    chapterId: widget.status.chapterId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            label: const Text('Tanya Levely', style: TextStyle(color: Colors.white, fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.primaryColor,
          )
        : null,
  );
}

  Widget _buildHTMLContent(String material) {
    return Padding(
        padding: EdgeInsets.only(bottom: 30),
            child: HtmlWidget(material, textStyle: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
    );
  }
}