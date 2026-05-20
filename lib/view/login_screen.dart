import 'dart:io';

import 'package:app/global_var.dart';
import 'package:app/service/user_service.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../model/login.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  void login() async {
    if (isLoading) return;

    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Username dan Password tidak boleh kosong", style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      var client = http.Client();
      final response = await UserService.login(emailController.text, passwordController.text).timeout(Duration(seconds: 15));

      if (response['code'] == 200) {
        Login credential = response['value'];
        SharedPreferences prefs = await SharedPreferences.getInstance();

        if(credential.role == 'STUDENT') {
          await prefs.setInt('userId', credential.id);
          await prefs.setString('name', credential.name);
          await prefs.setString('role', credential.role);
          await prefs.setString('token', credential.token);
          await prefs.setBool('firstLaunch', false);
          if (credential.sessionId != null) {
            await prefs.setInt('sessionId', credential.sessionId!);
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Mainscreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Mohon Login sebagai mahasiswa")),
          );
        }

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${response['message']}")),
        );
      }
      client.close();
    } on TimeoutException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Waktu koneksi habis. Coba lagi nanti.")),
      );
      print("Waktu koneksi habis. Coba lagi nanti.");
    }
    on SocketException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tidak dapat terhubung ke server. Periksa koneksi internet Anda.")),
      );
      print("Tidak dapat terhubung ke server. Periksa koneksi internet Anda.");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan: ${e.toString()}")),
      );
      print("Terjadi kesalahan: ${e.toString()}");
    }

    setState(() => isLoading = false);
  }

  void _launchEmail() async {
    String encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map((MapEntry<String, String> e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value).replaceAll('+', '%20')}')
          .join('&');
    }

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'siahaanralphael24@gmail.com',
      query: encodeQueryParameters(<String, String>{
        'subject': 'Levelearn Mobile Help Request - Authentication',
        'body': 'Saya menulis email ini untuk meminta bantuan terkait [jelaskan masalah atau pertanyaan Anda secara singkat].\n\n'
            'Berikut adalah detail masalah yang saya alami:\n\n'
            '* [Deskripsi masalah dengan jelas dan detail]\n'
            '* [Langkah-langkah yang sudah Anda coba]\n'
            '* [Informasi perangkat atau akun jika relevan]\n\n'
            'Saya berharap dapat segera mendapatkan solusi atau bantuan dari tim Anda.\n\n'
            'Terima kasih atas perhatian dan bantuannya.\n\n'
            'Hormat saya,\n\n'
            '[Nama Anda]\n'
            '[Kontak (opsional)]',
      }),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka aplikasi email')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;
            final contentMaxWidth = availableWidth > 600 ? 520.0 : availableWidth;
            final baseFontSize = (availableWidth * 0.04).clamp(14.0, 18.0).toDouble();
            final titleFontSize = (baseFontSize * 1.5).clamp(20.0, 28.0).toDouble();
            final headerHeight = (isLandscape && availableHeight < 500)
                ? 0.0
                : (availableHeight * 0.34).clamp(180.0, 320.0).toDouble();
            final sidePadding = availableWidth < 360 ? 12.0 : 16.0;
            final topGap = isLandscape ? 8.0 : 16.0;
            final sectionGap = isLandscape
              ? (availableHeight * 0.02).clamp(12.0, 18.0).toDouble()
              : (availableHeight * 0.04).clamp(16.0, 30.0).toDouble();
            final innerVerticalPadding = isLandscape ? 10.0 : 16.0;
            final helpToButtonGap = isLandscape ? 12.0 : 20.0;
            final bottomSpacing =
              keyboardInset > 0 ? keyboardInset + 16 : (isLandscape ? 8.0 : 16.0) + bottomInset;

            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomSpacing),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(height: topGap),
                      headerHeight > 0
                          ? SizedBox(
                              height: headerHeight,
                              child: Stack(
                                children: <Widget>[
                                  Positioned(
                                    top: -headerHeight * 0.1,
                                    height: headerHeight,
                                    width: contentMaxWidth,
                                    child: FadeInUp(
                                      duration: Duration(seconds: 1),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage('lib/assets/pictures/background-pattern.png'),
                                            fit: BoxFit.fill,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    height: headerHeight,
                                    width: contentMaxWidth + 20,
                                    child: FadeInUp(
                                      duration: Duration(milliseconds: 1000),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage('lib/assets/vectors/welcome_primary.png'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox.shrink(),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: innerVerticalPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            FadeInUp(
                              duration: Duration(milliseconds: 1500),
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: GlobalVar.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: titleFontSize,
                                  fontFamily: 'DIN_Next_Rounded',
                                ),
                              ),
                            ),
                            SizedBox(height: sectionGap),
                            FadeInUp(
                              duration: Duration(milliseconds: 1700),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color.fromRGBO(68, 31, 127, .3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color.fromRGBO(68, 31, 127, .3),
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                    )
                                  ],
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color.fromRGBO(68, 31, 127, .3),
                                          ),
                                        ),
                                      ),
                                      child: TextField(
                                        style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                                        controller: emailController,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                        ],
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "Username",
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontFamily: 'DIN_Next_Rounded',
                                            fontSize: baseFontSize,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.fromLTRB(16, 8, 8, 8),
                                      child: TextField(
                                        style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                                        controller: passwordController,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                        ],
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "Password",
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontFamily: 'DIN_Next_Rounded',
                                            fontSize: baseFontSize,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                              color: AppColors.primaryColor.withOpacity(0.7),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            FadeInUp(
                              duration: Duration(milliseconds: 1700),
                              child: Center(
                                child: TextButton(
                                  onPressed: _launchEmail,
                                  child: Text(
                                    "Butuh Bantuan?",
                                    style: TextStyle(
                                      color: AppColors.primaryColor,
                                      fontFamily: 'DIN_Next_Rounded',
                                      fontSize: baseFontSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: helpToButtonGap),
                            FadeInUp(
                              duration: Duration(milliseconds: 1900),
                              child: SizedBox(
                                width: double.infinity,
                                child: MaterialButton(
                                  onPressed: login,
                                  color: GlobalVar.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  height: 50,
                                  child: Center(
                                    child: isLoading
                                        ? CircularProgressIndicator(color: Colors.white)
                                        : Text(
                                            "Login",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'DIN_Next_Rounded',
                                              fontSize: baseFontSize,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: (isLandscape ? 8.0 : 16.0) + bottomInset),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
