import 'package:app/model/user.dart';
import 'package:app/model/user_course.dart';
import 'dart:async';
import 'dart:io';
import 'package:app/model/assignment.dart';
import 'package:app/model/chapter_status.dart';
import 'package:app/service/badge_service.dart';
import 'package:app/service/chapter_service.dart';
import 'package:app/service/user_chapter_service.dart';
import 'package:app/service/user_service.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/main_screen.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/user_course_service.dart';
import 'congratulation_screen.dart';

class AssignmentScreen extends StatefulWidget {
  final ChapterStatus status;
  final Student user;
  final UserCourse uc;
  final int level;
  final String? chapterName;
  final int chLength;
  final int chapterIndexInList;
  final Function(bool) updateProgress;
  final Function(ChapterStatus) updateStatus;
  const AssignmentScreen({
    super.key,
    required this.status,
    required this.user,
    required this.uc,
    required this.level,
    this.chapterName,
    required this.chLength,
    required this.chapterIndexInList,
    required this.updateProgress,
    required this.updateStatus
  });

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  late ChapterStatus status;
  Assignment? assignment;
  Student? user;
  late UserCourse uc;
  double downloadProgress = 0.0;
  PlatformFile? file;
  String lastestSubmissionUrl = '';
  bool _isFileUploaded = true;
  bool _isUserBadgeUpdated = true;
  bool _isUserCourseUpdated = true;
  int chLength = 0;
  bool complete = false;
  bool showDialogAssignmentOnce = false;

  @override
  void initState() {
    getAssignment(widget.status.chapterId);
    status = widget.status;
    user = widget.user;
    uc = widget.uc;
    chLength = widget.chLength;
    complete = status.isCompleted;
    showDialogAssignmentOnce = widget.status.assignmentDone;
    if (status.submission != null && status.submission != '') {
      lastestSubmissionUrl = status.submission!;
    }
    super.initState();
  }

  void getAssignment(int id) async {
    final resultAssignment = await ChapterService.getAssignmentByChapterId(id);
    setState(() {
      assignment = resultAssignment;
    });
  }

  Future<void> updateStatus() async {
    status = await UserChapterService.updateChapterStatus(status.id, status);
    setState(() {
      if(file != null){
        _isFileUploaded = true;
      }
    });
  }

  void _openFile(String filePath) {
    OpenFilex.open(filePath);
  }

  Future<void> updateUserPointsAndBadge() async {
    await UserService.updateUserPointsAndBadge(user!);
    setState(() {
      _isUserBadgeUpdated = true;
    });
  }

  Future<void> updateUserCourse() async {
    await UserCourseService.updateUserCourse(uc.id, uc);
    setState(() {
      _isUserCourseUpdated = true;
    });
  }

  int calculatePoint(int mnt) {
    switch (mnt) {
      case <= 120:
        return 100;
      case <= 240:
        return 80;
      case <= 180:
        return 60;
      case <= 240:
        return 40;
      case <= 300:
        return 20;
      case <= 360:
        return 10;
      default:
        return 0;
    }
  }

  void updateProgressValue(int progressValue) {
    setState(() {
      progressValue = progressValue;
    });
  }

  Future<void> uploadFile(PlatformFile file) async {
    final filename = '${file.name.split('.').first}_${status.userId}_${status.chapterId}_${DateTime.now().millisecondsSinceEpoch}.${file.extension}';
    final path = 'uploads/$filename';

    Uint8List bytes = file.bytes ?? await File(file.path!).readAsBytes();

    try {
      print('DEBUG: Attempting upload to bucket assignments');
      print('DEBUG: Path: $path');
      final response = await Supabase.instance.client.storage.from('assignments').uploadBinary(
        path, 
        bytes,
        retryAttempts: 3,
      );
      print('DEBUG: Upload response path: $response');
      
      final publicUrl = getPublicUrl(path);
      status.timeFinished = DateTime.now();
      setState(() {
        status.submission = publicUrl;
        lastestSubmissionUrl = publicUrl;
        status.isCompleted = true;
        status.assignmentDone = true;
        this.file = null;
        widget.updateStatus(status);
        _isFileUploaded = true;
      });
      await updateStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment uploaded successfully!', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Upload error: $e');
      }
      if (mounted) {
        setState(() {
          _isFileUploaded = true; // Reset loading state on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}', style: const TextStyle(fontFamily: 'DIN_Next_Rounded')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String getPublicUrl(String filePath) {
    return Supabase.instance.client.storage
        .from('assignments')
        .getPublicUrl(filePath);
  }

  void updateProgressAssignment() {
    if (status.assignmentDone && status.isCompleted && !showDialogAssignmentOnce) {
      showDialogAssignmentOnce = true;
      showCompletionDialog(context, "Yeay kamu berhasil menyelesaikan Chapter ini, Ayo lanjutkan pelajari chapter yang lain");
    }
  }

  void showCompletionDialog(BuildContext context, String message) {
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
                  // Pop the AlertDialog first
                  Navigator.pop(context);
                  
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CongratulationsScreen(
                            message: "You have successfully completed this assignment!",
                            onContinue: () async {
                              if (!context.mounted) return;
                              
                              final navigator = Navigator.of(context);

                              // Pop CongratulationsScreen
                              navigator.pop();
                              // Pop AssignmentScreen/ChapterScreen
                              navigator.pop({
                                'status': status.toJson(),
                                'index': widget.chapterIndexInList,
                              });
                            },
                          ),
                        ),
                      );
                    }
                  });
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result == null) return;

    final fileSizeInMB = result.files.first.size / (1024 * 1024);

    if (fileSizeInMB > 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File size must be 5MB or less', style: TextStyle(fontFamily: 'DIN_Next_Rounded'),)),
      );
    } else {
      setState(() {
        file = result.files.first;
      });
    }
  }

  void _downloadFile(String url) {
    FileDownloader.downloadFile(
      url: url,
      onProgress: (name, progress) {
        setState(() {
          downloadProgress = progress / 100;
        });
      },
      onDownloadCompleted: (filePath) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download Complete, saved in $filePath", style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
            action: SnackBarAction(
              label: "Open",
              onPressed: () => _openFile(filePath),
            ),
          ),
        );
        setState(() {
          downloadProgress = 0;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildAssignmentContent();
  }

  Widget _buildAssignmentContent() {
    return Container(
      decoration: BoxDecoration(
          image: DecorationImage(
              image: AssetImage(
                  'lib/assets/pictures/background-pattern.png'),
              fit: BoxFit.cover
          )
      ),
      child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            controller: ScrollController(),
            child: Column(
              children: [
                assignment?.instruction == null ? CircularProgressIndicator() : _buildHTMLAssignment(),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () async {
                      if (file == null) {
                        _pickFile();
                      }
                    },
                    child: file != null
                        ? _buildFilePreview(file!)
                        : (lastestSubmissionUrl != ''
                            ? _buildSubmittedFilePreview(lastestSubmissionUrl)
                            : _buildUploadBox()),
                  ),
                ),
                file == null ? SizedBox() :
                !_isFileUploaded && !_isUserBadgeUpdated && !_isUserCourseUpdated ?
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(
                      "Mohon Tunggu, sedang mengunggah berkas",
                      style:
                      TextStyle(fontSize: 16, fontFamily: 'DIN_Next_Rounded'),
                    ),
                  ],
                ) : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            _isFileUploaded = false;
                            _isUserBadgeUpdated = false;
                            _isUserCourseUpdated = false;
                          });

                          Duration difference = status.timeStarted.difference(status.timeFinished);
                          if(!status.assignmentDone && !complete){
                            user?.points = user!.points! + calculatePoint(difference.inMinutes);
                          }

                          if (widget.level == uc.currentChapter) {
                            uc.currentChapter++;
                            uc.progress = (((uc.currentChapter - 1) / chLength) * 100).toInt();
                          }

                          await uploadFile(file!);
                          await Future.wait([
                            updateUserPointsAndBadge(),
                            updateUserCourse(),
                          ]);

                          if (_isUserCourseUpdated && _isUserBadgeUpdated && _isFileUploaded) {
                            Future.delayed(Duration(milliseconds: 200), () {
                              if (complete) {
                                Navigator.pop(context);
                              } else {
                                updateProgressAssignment();
                              }
                            });
                          }
                        },
                        style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(AppColors.primaryColor)),
                        icon: Icon(LineAwesomeIcons.paper_plane_solid, color: Colors.white),
                        label: Text(
                          'Submit',
                          style: TextStyle(color: Colors.white, fontFamily: 'DIN_Next_Rounded'),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          onPressed:() {
                            setState(() {
                              file = null;
                            });
                          },
                          style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.red)),
                          icon: Icon(LineAwesomeIcons.trash_alt, color: Colors.white,),
                          label: Text('Delete', style: TextStyle(color: Colors.white, fontFamily: 'DIN_Next_Rounded'),)
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10,),
                if (status.assignmentDone) 
                  Container(
                    width: MediaQuery.of(context).size.width,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.primaryColor.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.feedback_outlined, color: AppColors.primaryColor),
                            SizedBox(width: 8),
                            Text("Feedback & Nilai", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor)),
                          ],
                        ),
                        Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Score:", style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.w500)),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${status.assignmentScore}/100",
                                style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text("Komentar:", style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Text(
                          status.assignmentFeedback.isEmpty ? "Belum ada feedback." : status.assignmentFeedback,
                          style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )
      ),
    );
  }

  Widget _buildHTMLAssignment() {
    return SizedBox(
        width: double.infinity,
        child: Text(assignment!.instruction, style: TextStyle(fontFamily: 'DIN_Next_Rounded'),)
    );
  }

  Widget _buildUploadBox() {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: Radius.circular(12),
      color: Colors.grey.shade400,
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.file_present, color: Colors.grey.shade400, size: 80),
              Text(
                'Tap untuk mengunggah file',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontFamily: 'DIN_Next_Rounded'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmittedFilePreview(String url) {
    String fileName = url.split('/').last.replaceAll('%20', ' ');
    String extension = fileName.split('.').last.toLowerCase();

    return DottedBorder(
      borderType: BorderType.RRect,
      radius: Radius.circular(12),
      color: AppColors.secondaryColor,
      strokeWidth: 2,
      child: Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: AppColors.secondaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image(
                  image: AssetImage(
                    extension == 'pdf'
                        ? 'lib/assets/iconpdf.png'
                        : (extension == 'jpg' || extension == 'jpeg' || extension == 'png')
                        ? 'lib/assets/iconjpg.png'
                        : 'lib/assets/empty.png',
                  ),
                  width: 80,
                  height: 80,
                ),
                Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, color: Colors.white, size: 20),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Tersubmit',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryColor,
                  fontFamily: 'DIN_Next_Rounded'
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                fileName,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontFamily: 'DIN_Next_Rounded'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _downloadFile(url),
                  icon: Icon(Icons.download, color: AppColors.primaryColor),
                  label: Text('Download', style: TextStyle(color: AppColors.primaryColor, fontFamily: 'DIN_Next_Rounded')),
                ),
                SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _pickFile,
                  icon: Icon(Icons.refresh, color: Colors.grey),
                  label: Text('Ganti File', style: TextStyle(color: Colors.grey, fontFamily: 'DIN_Next_Rounded')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview(PlatformFile file) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: Radius.circular(12),
      color: Colors.grey.shade400,
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(image: AssetImage(
                  file.extension == 'pdf'
                      ? 'lib/assets/iconpdf.png'
                      : file.extension == 'jpg'
                      ? 'lib/assets/iconjpg.png'
                      : ''
              ), width: 80, height: 80,
              ),
              Text(
                file.name,
                style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade700, fontFamily: 'DIN_Next_Rounded'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
