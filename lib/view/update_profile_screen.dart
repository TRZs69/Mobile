// ignore_for_file: use_build_context_synchronously
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

import '../service/api_cache_service.dart';
import '../service/user_service.dart';
import '../utils/colors.dart';

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
  bool isLoading = false;
  FilePickerResult? result;

  @override
  void initState() {
    _loadPreferences();
    user = widget.user;
    nameController.text = user?.name ?? '';
    usernameController.text = user?.username ?? '';
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

  String getPublicUrl(String filePath) {
    return Supabase.instance.client.storage
        .from('profile_pictures')
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
                    builder: (context) => Mainscreen(navIndex: 4)),
              );
            },
            icon: const Icon(LineAwesomeIcons.angle_left_solid,
                color: Colors.white)),
        title: Text("Update Profile",
            style: Theme.of(context)
                .textTheme
                .titleLarge!
                .copyWith(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
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
                              ? Image.file(File(photo!.path!),
                                  fit: BoxFit.cover, width: 120, height: 120)
                              : (user?.image != null && user!.image!.isNotEmpty
                                  ? Image.network(
                                      user!.image!,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.person,
                                                  size: 100,
                                                  color: Colors.grey),
                                    )
                                  : Icon(Icons.person,
                                      size: 100, color: Colors.grey)),
                        ),
                      ),
                      Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              final result =
                                  await FilePicker.platform.pickFiles(
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
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  color: AppColors.secondaryColor),
                              child: const Icon(
                                LineAwesomeIcons.camera_solid,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 64),
                  Form(
                      child: Column(
                    children: [
                      TextFormField(
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontFamily: 'DIN_Next_Rounded',
                            ),
                        controller: nameController,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(100)),
                            prefixIconColor: AppColors.primaryColor,
                            floatingLabelStyle:
                                const TextStyle(color: AppColors.primaryColor),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                  width: 2, color: AppColors.primaryColor),
                            ),
                            label: Text("Name",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      fontFamily: 'DIN_Next_Rounded',
                                    )),
                            hintText: "Enter your name",
                            prefixIcon:
                                Icon(LineAwesomeIcons.person_booth_solid)),
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
                              borderSide: BorderSide(
                                  width: 2, color: AppColors.primaryColor),
                            ),
                            label: Text("Username",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      fontFamily: 'DIN_Next_Rounded',
                                    )),
                            hintText: "Enter your username",
                            prefixIcon: Icon(LineAwesomeIcons.user)),
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
                            floatingLabelStyle: const TextStyle(
                                color: AppColors.secondaryColor),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                  width: 2, color: AppColors.primaryColor),
                            ),
                            label: Text("Password",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      fontFamily: 'DIN_Next_Rounded',
                                    )),
                            prefixIcon:
                                Icon(LineAwesomeIcons.fingerprint_solid)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    setState(() {
                                      isLoading = true;
                                    });

                                    try {
                                      String? newPhotoUrl;
                                      if (photo != null) {
                                        final filename =
                                            '${photo?.name.split('.').first}_${user!.studentId}_${DateTime.now().millisecondsSinceEpoch}.${photo?.extension}';
                                        final compressedXFile =
                                            await compressImage(photo!);

                                        if (compressedXFile != null) {
                                          final path = 'profile/$filename';
                                          Uint8List bytes =
                                              await compressedXFile
                                                  .readAsBytes();
                                          await Supabase.instance.client.storage
                                              .from('profile_pictures')
                                              .uploadBinary(path, bytes);
                                          newPhotoUrl = getPublicUrl(path);
                                        }
                                      }

                                      String newName =
                                          nameController.text.trim();
                                      String newUsername =
                                          usernameController.text.trim();
                                      String newPassword =
                                          passwordController.text.trim();

                                      Map<String, dynamic> patch = {};
                                      if (newName.isNotEmpty &&
                                          newName != user?.name) {
                                        patch['name'] = newName;
                                      }
                                      if (newUsername.isNotEmpty &&
                                          newUsername != user?.username) {
                                        patch['username'] = newUsername;
                                      }
                                      if (newPhotoUrl != null) {
                                        patch['image'] = newPhotoUrl;
                                      }

                                      if (newPassword.isNotEmpty) {
                                        await UserService.updatePassword(user!
                                            .copyWith(password: newPassword));
                                      }

                                      if (patch.isNotEmpty) {
                                        final updatedUser =
                                            await UserService.patchUser(
                                                user!, patch);

                                        setState(() {
                                          user = updatedUser;
                                          photo = null;
                                        });

                                        await prefs.setInt(
                                            'userId', updatedUser.id);
                                        await prefs.setString(
                                            'name', updatedUser.name);
                                        await prefs.setString(
                                            'role', updatedUser.role);

                                        await ApiCacheService
                                            .clearCacheContaining(
                                                'user/${updatedUser.id}');
                                      }

                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                "Profil berhasil diperbarui",
                                                style: TextStyle(
                                                    fontFamily:
                                                        'DIN_Next_Rounded')),
                                            backgroundColor: Colors.green,
                                          ),
                                        );

                                        Future.delayed(
                                            const Duration(milliseconds: 500),
                                            () {
                                          if (mounted) {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const Mainscreen(
                                                          navIndex: 4)),
                                            );
                                          }
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint("Update failed: $e");
                                      String errorMessage =
                                          "Gagal menyimpan perubahan";
                                      if (e.toString().contains(
                                          "Username sudah digunakan")) {
                                        errorMessage =
                                            "Username sudah digunakan oleh pengguna lain.";
                                      }

                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(errorMessage,
                                              style: const TextStyle(
                                                  fontFamily:
                                                      'DIN_Next_Rounded')),
                                          backgroundColor: Colors.red,
                                        ));
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    "Save",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                            fontFamily: 'DIN_Next_Rounded',
                                            color: Colors.white),
                                  )),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(TextSpan(
                                text: "Joined: ",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black),
                                children: [
                                  TextSpan(
                                      text: DateFormat('dd MMMM yyyy HH:mm:ss')
                                          .format(user!.createdAt),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primaryColor))
                                ],
                              )),
                              Text.rich(TextSpan(
                                text: "Last Modified: ",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black),
                                children: [
                                  TextSpan(
                                      text: DateFormat('dd MMMM yyyy HH:mm:ss')
                                          .format(user!.updatedAt),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primaryColor))
                                ],
                              )),
                            ],
                          ),
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
}
