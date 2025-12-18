import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/colors.dart';

class QuickAccessScreen extends StatefulWidget {
  const QuickAccessScreen({super.key});

  @override
  State<QuickAccessScreen> createState() => _QuickAccessScreenState();
}

class _QuickAccessScreenState extends State<QuickAccessScreen> {

  late final List<QuickAccessItem> quickAccessItems;

  @override
  void initState() {
    super.initState();
    final storage = Supabase.instance.client.storage;
    final badges = storage.from('badges');

    quickAccessItems = [
      QuickAccessItem(
        name: "E-Course Del",
        link: "https://ecourse.del.ac.id/",
        imageUrl: badges.getPublicUrl('Quick Access/ecourse.png'),
      ),
      QuickAccessItem(
        name: "Campus Information System (CIS)",
        link: "https://cis.del.ac.id/",
        imageUrl: badges.getPublicUrl('Quick Access/del.png'),
      ),
      QuickAccessItem(
        name: "Zimbra Del",
        link: "https://students.del.ac.id/",
        imageUrl: badges.getPublicUrl('Quick Access/zimbra.png'),
      ),
    ];
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka URL: $url')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Quick Access"),
        backgroundColor: AppColors.primaryColor,
        leading: IconButton(
            onPressed: (){
              Navigator.pop(context);
            },
            icon: Icon(LineAwesomeIcons.angle_left_solid, color: Colors.white,)),
        titleTextStyle: TextStyle(
            fontFamily: 'DIN_Next_Rounded',
            fontSize: 24,
            color: Colors.white
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'lib/assets/pictures/background-pattern.png'
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView.builder(
          itemCount: quickAccessItems.length,
          itemBuilder: (context, index) {
            final item = quickAccessItems[index];
            return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(item.imageUrl),
                ),
                title: Text(item.name,
                    style: TextStyle(
                        fontFamily: 'DIN_Next_Rounded',
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor)),
              onTap: () {
                _launchURL(item.link);
              }
            );
          },
        ),
      ),
    );
  }
}

class QuickAccessItem {
  final String name;
  final String link;
  final String imageUrl;

  QuickAccessItem({
    required this.name,
    required this.link,
    required this.imageUrl,
  });
}
