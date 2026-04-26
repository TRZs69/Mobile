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
  final int idBadge;
  final int chLength;
  final Function(bool) updateProgress;
  final Function(ChapterStatus) updateStatus;
  const AssignmentScreen({
    super.key,
    required this.status,
    required this.user,
    required this.uc,
    required this.level,
    this.chapterName,
    this.idBadge = 0,
    required this.chLength,
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
  int idBadge = 0;
  int chLength = 0;
  bool complete = false;
  bool showDialogAssignmentOnce = false;

  @override
  void initState() {
    getAssignment(widget.status.chapterId);
    status = widget.status;
    user = widget.user;
    uc = widget.uc;
    idBadge = widget.idBadge;
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

  Future<void> createUserBadge(int userId, int badgeId) async{
    await BadgeService.createUserBadgeByChapterId(userId, badgeId);
  }

  Future<void> uploadFile(PlatformFile file) async {
    final filename = '${file.name.split('.').first}_${status.userId}_${status.chapterId}_${DateTime.now().millisecondsSinceEpoch}.${file.extension}';
    final path = 'uploads/$filename';

    Uint8List bytes = file.bytes ?? await File(file.path!).readAsBytes();

    try {
      await Supabase.instance.client.storage.from('assignment').uploadBinary(path, bytes);
      final publicUrl = getPublicUrl(path);
      status.timeFinished = DateTime.now();
      setState(() {
        status.submission = publicUrl;
        status.isCompleted = true;
        status.assignmentDone = true;
        widget.updateStatus(status);
      });
      await updateStatus();
    } catch (e) {
      if (kDebugMode) {
        print('Upload error: $e');
      }
    }
  }

  String getPublicUrl(String filePath) {
    return Supabase.instance.client.storage
        .from('assigment')
        .getPublicUrl(filePath);
  }

  void updateProgressAssignment() {
    if (status.assignmentDone && status.isCompleted && !showDialogAssignmentOnce) {
      showDialogAssignmentOnce = true;
      showCompletionDialog(context, "Yeay kamu berhasil menyelesaikan Chapter ini, Ayo lanjutkan pelajari chapter yang lain");
    }
  }

  void _navigateToCongratulations() {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CongratulationsScreen(
          message: "You have successfully completed Chapter 8!",
          onContinue: () async {
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => Mainscreen(navIndex: 2),
              ),
              (route) => false,
            );
          },
          idBadge: idBadge,
        ),
      ),
    );
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
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CongratulationsScreen(
                            message: "You have successfully completed this assignment!",
                            onContinue: () async {
                              if (!context.mounted) return;

                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Mainscreen(navIndex: 2),
                                ),
                                (route) => false,
                              );
                            },
                            idBadge: idBadge,
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
                assignment?.fileUrl != null && assignment?.fileUrl != "" ? ListTile(
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 30, color: AppColors.primaryColor),
                        if (downloadProgress > 0.0 && downloadProgress < 1.0)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              value: downloadProgress,
                              strokeWidth: 3,
                              backgroundColor: Colors.grey[300],
                              color: Colors.deepPurple,
                            ),
                          ),
                      ],
                    ),
                    title: Text("Unduh file assignment disini", style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
                    onTap: () async {
                      FileDownloader.downloadFile(
                        url: assignment!.fileUrl!,
                        onProgress: (name, progress) {
                          setState(() {
                            debugPrint("Download Progress: $progress");
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
                ) : SizedBox(),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                      );

                      if (result == null) return;

                      final fileSizeInMB = result.files.first.size / (1024 * 1024);

                      if (fileSizeInMB > 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File size must be 5MB or less', style: TextStyle(fontFamily: 'DIN_Next_Rounded'),)),
                        );
                      } else {
                        setState(() {
                          file = result.files.first;
                        });
                      }
                    },
                    child: file == null
                        ? _buildUploadBox()
                        : _buildFilePreview(file!),
                  ),
                ),
                lastestSubmissionUrl != '' ? _buildExistingFile(lastestSubmissionUrl) : SizedBox(),
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
                          print(user?.points);
                          print(status.assignmentDone);
                          print(complete);
                          print("awoo");
                          if(!status.assignmentDone && !complete){
                            user?.points = user!.points! + calculatePoint(difference.inMinutes);
                          }
                          if (idBadge != 0) {
                            createUserBadge(user!.id, idBadge);
                            user?.badges = user!.badges! + 1;
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
                Container(
                  width: MediaQuery.of(context).size.width,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text("Feedback", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded')),
                        Text("Score : ${status.assignmentScore}", style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
                        Text(
                          status.assignmentFeedback,
                          style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                        ),
                      ],
                    ),
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

  Widget _buildExistingFile(String url) {
    return GestureDetector(
      onTap: () async {
        FileDownloader.downloadFile(
          url: url,
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
          },
        );
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.deepPurple),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                  url.split('/').last.replaceAll('%20', ' '),
                  style: TextStyle(fontSize: 14, fontFamily: 'DIN_Next_Rounded'),
                  overflow: TextOverflow.ellipsis
              ),
            ),
          ],
        ),
      ),
    );
  }
}
