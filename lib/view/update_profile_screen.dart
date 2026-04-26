import 'dart:io';

import 'package:app/model/user.dart';
import 'package:app/view/main_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';

import '../service/user_service.dart';
import '../utils/colors.dart';
import 'login_screen.dart';

class UpdateProfile extends StatefulWidget {
  final Student user;
  const UpdateProfile({super.key, required this.user});

  @override
  State<UpdateProfile> createState() => _UpdateProfileState();
}

class _UpdateProfileState extends State<UpdateProfile> {
  Student? user;
  late SharedPreferences prefs;
  PlatformFile? photo;
  TextEditingController nameController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool hasChanges = false;
  bool passwordHasChanges = false;
  FilePickerResult? result;

  @override
  void initState() {
    _loadPreferences();
    user = widget.user;
    super.initState();
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  Future<void> uploadPhotoProfile(XFile file, String filename) async {
    final path = 'profile/$filename';

    Uint8List bytes = await file.readAsBytes();

    try {
      await Supabase.instance.client.storage.from('images').uploadBinary(path, bytes);
      final publicUrl = getPublicUrl(path);
      if (kDebugMode) {
        print(publicUrl);
      }
      setState(() {
        user?.image = publicUrl;
      });
      hasChanges = true;
    } catch (e) {
      if (kDebugMode) {
        print('Upload error: $e');
      }
    }
  }

  String getPublicUrl(String filePath) {
    return Supabase.instance.client.storage
        .from('images')
        .getPublicUrl(filePath);
  }

  Future<void> updateUser() async {
    if (user == null) return;

    final result = await UserService.updateUser(user!);
    setState(() {
      user = result;
    });

    if (user != null) {
      await prefs.setInt('userId', user!.id);
      await prefs.setString('name', user!.name);
      await prefs.setString('role', user!.role);
    }
  }

  Future<void> updateUserPhoto() async {
    await UserService.updateUserPhoto(user!);
  }

  Future<void> updatePassword() async {
    await UserService.updatePassword(user!);
  }

  Future<XFile?> compressImage(PlatformFile file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = path.join(tempDir.path, "compressed_${file.name}");

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.path!,
      targetPath,
      quality: 50,
      format: CompressFormat.jpeg,
    );

    if (compressedFile != null) {
      return XFile(compressedFile.path);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => Mainscreen()),
              );
            },
            icon: const Icon(LineAwesomeIcons.angle_left_solid, color: Colors.white)),
        title: Text("Update Profile",
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontFamily: 'DIN_Next_Rounded',
                color: Colors.white)
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(
                        'lib/assets/pictures/background-pattern.png'),
                    fit: BoxFit.cover)),
          ),
          SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: photo != null
                              ? (photo!.bytes != null
                              ? Image.memory(photo!.bytes!, fit: BoxFit.cover)
                              : Image.file(File(photo!.path!), fit: BoxFit.cover))
                              : (user?.image != null && user!.image!.isNotEmpty
                              ? Image.network(
                                  user!.image!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: 100, color: Colors.grey),
                                )
                              : Icon(Icons.person, size: 100, color: Colors.grey)),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['jpg', 'jpeg', 'png'],
                            );

                            if (result == null) return;

                            setState(() {
                              photo = result.files.first;
                            });
                          },
                          child: Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: AppColors.secondaryColor),
                            child: const Icon(
                              LineAwesomeIcons.camera_solid,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  Form(child: Column(
                    children: [
                      TextFormField(
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontFamily: 'DIN_Next_Rounded',
                        ),
                        controller: nameController,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                            prefixIconColor: AppColors.primaryColor,
                            floatingLabelStyle: const TextStyle(color: AppColors.primaryColor),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(width: 2 ,color: AppColors.primaryColor),
                            ),
                            label: Text(
                                "Name",
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontFamily: 'DIN_Next_Rounded',
                                )
                            ),
                            hintText: user?.name != null && user?.name != '' ? user!.name : "Name",
                            prefixIcon: Icon(LineAwesomeIcons.person_booth_solid)
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontFamily: 'DIN_Next_Rounded',
                        ),
                        controller: usernameController,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(100)),
                            prefixIconColor: AppColors.primaryColor,
                            floatingLabelStyle:
                            const TextStyle(color: AppColors.primaryColor),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(width: 2, color: AppColors.primaryColor),
                            ),
                            label: Text(
                                "Username",
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontFamily: 'DIN_Next_Rounded',
                                )
                            ),
                            hintText: user?.username != null && user?.username != '' ? user!.username : "Username",
                            prefixIcon: Icon(LineAwesomeIcons.user)
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontFamily: 'DIN_Next_Rounded',
                        ),
                        controller: passwordController,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(100)),
                            prefixIconColor: AppColors.primaryColor,
                            floatingLabelStyle:
                            const TextStyle(color: AppColors.secondaryColor),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(width: 2, color: AppColors.primaryColor),
                            ),
                            label: Text(
                                "Password",
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontFamily: 'DIN_Next_Rounded',
                                )
                            ),
                            prefixIcon: Icon(LineAwesomeIcons.fingerprint_solid)
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () async {
                            if(photo != null) {
                              final filename = '${photo?.name.split('.').first}_${user!.studentId}_${DateTime.now().millisecondsSinceEpoch}.${photo?.extension}';
                              final compressedXFile = await compressImage(photo!);

                              if (compressedXFile != null) {
                                await uploadPhotoProfile(compressedXFile, filename);
                              }
                            }
                            String newName = nameController.text.trim();
                            String newUsername = usernameController.text.trim();
                            String newPassword = passwordController.text.trim();

                            if (newName.isNotEmpty && newName != user?.name) {
                              user?.name = newName;
                              hasChanges = true;
                            }
                            if (newUsername.isNotEmpty && newUsername != user?.username) {
                              user?.username = newUsername;
                              hasChanges = true;
                            }
                            if (newPassword.isNotEmpty && newPassword != user?.password) {
                              user?.password = newPassword;
                              hasChanges = true;
                              passwordHasChanges = true;
                            }

                            if (hasChanges) {
                              if (passwordHasChanges){
                                await updatePassword();
                              }
                              await updateUserPhoto();
                              await updateUser();
                              showSuccessDialog(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                          ),
                          child: Text("Save", style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontFamily: 'DIN_Next_Rounded',
                              color: Colors.white
                          ),)
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                  TextSpan(
                                    text: "Joined: ",
                                    style: const TextStyle(fontSize: 12, color: Colors.black),
                                    children: [
                                      TextSpan(text: DateFormat('dd MMMM yyyy HH:mm:ss').format(user!.createdAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryColor))
                                    ],
                                  )
                              ),
                              Text.rich(
                                  TextSpan(
                                    text: "Last Modified: ",
                                    style: const TextStyle(fontSize: 12, color: Colors.black),
                                    children: [
                                      TextSpan(text: DateFormat('dd MMMM yyyy HH:mm:ss').format(user!.updatedAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryColor))
                                    ],
                                  )
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () async{
                              await prefs.remove('userId');
                              await prefs.remove('name');
                              await prefs.remove('role');
                              await prefs.remove('token');
                              await prefs.remove('lastestSelectedCourse');
                              await prefs.remove('latestSelectedCourse');
                              await prefs.remove('getCourseDetail');
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LoginScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.1),
                                elevation: 0,
                                foregroundColor: Colors.red,
                                shape: const StadiumBorder(),
                                side: BorderSide.none
                            ),
                            child: Text("Delete", style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                fontFamily: 'DIN_Next_Rounded',
                                color: Colors.red
                            ),
                            ),
                          )
                        ],
                      )
                    ],
                  ))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Successful Update"),
          content: Text("Akunmu sudah diperbaharui"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => Mainscreen(navIndex: 4)),
                );
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
}