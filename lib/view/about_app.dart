import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/colors.dart';
import 'main_screen.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka URL: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("About App"),
          backgroundColor: AppColors.primaryColor,
          leading: IconButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => Mainscreen(navIndex: 4)),
                );
              },
              icon: Icon(
                LineAwesomeIcons.angle_left_solid,
                color: Colors.white,
              )),
          titleTextStyle: TextStyle(
              fontFamily: 'DIN_Next_Rounded',
              fontSize: 24,
              color: Colors.white),
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
        ),
        body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/pictures/background-pattern.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                  padding: EdgeInsets.all(0),
                  child: Column(children: [
                    Image.asset('lib/assets/pictures/about-header.png'),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                          "Levelearn adalah aplikasi pembelajaran berbasis mobile dengan menggunakan pendekatan gamification guna menciptakan pengalaman pengguna aplikasi yang baik dalam belajar. Levelearn ditujukan sebagai media untuk pelajar dapat belajar materi secara mandiri diluar perkuliahan. Levelearn menyajikan gaya belajar yang interaktif dengan mengadopsi elemen-elemen dari game untuk diterapkan pada aplikasi. Levelearn juga diharapkan dapat meningkatkan kenyamanan belajar melalui kenyamanan dalam menggunakan aplikasi.",
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'DIN_Next_Rounded',
                          )),
                    ),
                    Image.asset('lib/assets/pictures/about-logo.png'),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                          "Levelearn dikembangkan dengan latar belakang keperluan Tugas Akhir TA-2024/2025-13 Institut Teknologi Del yang berjudul 'Pendekatan Gamifikasi berbasis Preferensi Pengguna untuk Optimalisasi Pengalaman Pengguna pada E-Learning'. Adapaun studi kasus dari penelitian ini adalah Mata Kuliah Interaksi Manusia Komputer, yang melibatkan langsung mahasiswa mata kuliah Interaksi Manusia Komputer sebagai pengguna akhir aplikasi. Pengguna akhir aplikasi ini terlibat dalam pengembangan aplikasi, terkhusus dalam pemilihan elemen gamification untuk diterapkan pada aplikasi, dan evaluasi optimalisasi pengalaman pengguna pada aplikasi.",
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'DIN_Next_Rounded',
                          )),
                    ),
                    GridView(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      children: [
                        Image.asset('lib/assets/pictures/flutter.png',
                            fit: BoxFit.cover),
                        Image.asset('lib/assets/pictures/node.png',
                            fit: BoxFit.cover),
                        Image.asset('lib/assets/pictures/react.png',
                            fit: BoxFit.cover),
                        Image.asset('lib/assets/pictures/mysql.png',
                            fit: BoxFit.cover),
                        Image.asset('lib/assets/pictures/supabase.png',
                            fit: BoxFit.cover),
                        Image.asset('lib/assets/pictures/docker.png',
                            fit: BoxFit.cover),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                          "Levelearn dibangun dengan mengkombinasikan beberapa jenis teknologi pengembangan aplikasi. Untuk pengembangan aplikasi mobile Levelearn menggunakan Flutter Dart, dan untuk pengembangan aplikasi web Levelearn menggunakan React. Untuk pengembangan backend aplikasi menggunakan Express (Node), dengan database berupa MySQL, dan storage menggunakan Supabase. Dan untuk deployment dan operation dari aplikasi menggunakan Docker.",
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'DIN_Next_Rounded',
                          )),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            onPressed: () {
                              _launchURL('https://github.com/Levelearn');
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor),
                            icon: Icon(
                              LineAwesomeIcons.github,
                              color: Colors.white,
                            ),
                            label: Text("Explore More",
                                style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'DIN_Next_Rounded',
                                    color: Colors.white))),
                      ),
                    )
                  ])),
            )));
  }
}
