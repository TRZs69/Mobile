import 'package:app/service/user_service.dart';
import 'package:app/utils/colors.dart';
import 'package:flutter/material.dart';

import '../model/user.dart';

Color purple = Color(0xFF441F7F);
Color backgroundNavHex = Color(0xFFF3EDF7);
const url =
    'https://www.globalcareercounsellor.com/blog/wp-content/uploads/2018/05/Online-Career-Counselling-course.jpg';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<StatefulWidget> createState() => _FriendsScreen();
}

class _FriendsScreen extends State<FriendsScreen> {
  List<Student> user = [];
  bool isLoading = true;

  List<Student> sortUserByElo(List<Student> list) {
    final sorted = List<Student>.from(list);
    sorted.sort((a, b) => (b.elo ?? 0).compareTo(a.elo ?? 0));
    return sorted;
  }

  void getAllUser() async {
    try {
      final result = await UserService.getLeaderboard(
        onRevalidated: (freshData) {
          if (!mounted) return;
          setState(() {
            user = freshData;
            isLoading = false;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        user = result;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        user = [];
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getAllUser();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            image: DecorationImage(
                image: AssetImage("lib/assets/learnbg.png"),
                fit: BoxFit.cover,
                opacity: 0.7),
          ),
        ),
        !isLandscape
            ? Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  toolbarHeight: 450,
                  backgroundColor: AppColors.primaryColor,
                  automaticallyImplyLeading: false,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  title: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Papan Peringkat',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 24,
                              fontFamily: 'DIN_Next_Rounded'),
                        ),
                        isLoading
                            ? const SizedBox(
                                height: 300,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white)))
                            : _buildLeaderBoard(user),
                      ],
                    ),
                  ),
                ),
                body: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _listFriends(),
              )
            : Scaffold(
                backgroundColor: Colors.transparent,
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        height: 450,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Papan Peringkat',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontFamily: 'DIN_Next_Rounded'),
                                ),
                                isLoading
                                    ? const SizedBox(
                                        height: 300,
                                        child: Center(
                                            child: CircularProgressIndicator(
                                                color: Colors.white)))
                                    : _buildLeaderBoard(user),
                              ],
                            ),
                          ),
                        ),
                      ),
                      isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()))
                          : _listFriendsForLandscape(),
                    ],
                  ),
                ),
              )
      ],
    );
  }

  Widget _listFriends() {
    final sortedUsers = sortUserByElo(user);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        itemCount: sortedUsers.length,
        itemBuilder: (context, count) {
          return _listFriendsItem(
              sortedUsers[count],
              count,
              count == 0
                  ? 0
                  : count == sortedUsers.length - 1
                      ? 2
                      : 1);
        },
      ),
    );
  }

  Widget _listFriendsForLandscape() {
    final sortedUsers = sortUserByElo(user);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: sortedUsers.length,
        itemBuilder: (context, count) {
          return _listFriendsItem(
              sortedUsers[count],
              count,
              count == 0
                  ? 0
                  : count == sortedUsers.length - 1
                      ? 2
                      : 1);
        },
      ),
    );
  }

  Widget _listFriendsItem(Student user, int index, int position) {
    return Padding(
      padding: position == 0
          ? const EdgeInsets.only(top: 12)
          : position == 2
              ? const EdgeInsets.only(bottom: 12)
              : const EdgeInsets.all(0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (switch (index) {
                  0 => Colors.amber.shade300,
                  1 => Colors.blueGrey.shade400,
                  2 => Colors.orange.shade400,
                  _ => Colors.grey.shade300
                }),
                Colors.transparent
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.5,
                0.8,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: index <= 2
                ? Image.asset(switch (index) {
                    0 => 'lib/assets/1st.png',
                    1 => 'lib/assets/2nd.png',
                    2 => 'lib/assets/3rd.png',
                    _ => ''
                  })
                : Text(
                    '#${index + 1}',
                    style: TextStyle(fontSize: 25),
                  ),
            title: Text(
              user.name,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'DIN_Next_Rounded'),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.studentId ?? '',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontFamily: 'DIN_Next_Rounded'),
                ),
                Text(
                  user.eloTitle ?? 'Beginner',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      fontFamily: 'DIN_Next_Rounded'),
                ),
              ],
            ),
            trailing: Text(
              '${user.elo ?? 0} ELO',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'DIN_Next_Rounded'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderBoard(List<Student> list) {
    return Container(
      margin: EdgeInsets.all(16),
      height: 300,
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _buildPodiumItem(
              student: list.length >= 2 ? list[1] : null,
              bannerAsset: 'lib/assets/leaderboards/banner-silver.png',
              podiumHeight: 120,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPodiumItem(
              student: list.isNotEmpty ? list[0] : null,
              bannerAsset: 'lib/assets/leaderboards/banner-gold.png',
              podiumHeight: 150,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPodiumItem(
              student: list.length >= 3 ? list[2] : null,
              bannerAsset: 'lib/assets/leaderboards/banner-bronze.png',
              podiumHeight: 90,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required Student? student,
    required String bannerAsset,
    required double podiumHeight,
  }) {
    final image = student?.image;
    final hasImage = image != null && image.isNotEmpty;
    final displayName = student?.name ?? '';
    final elo = student?.elo ?? 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        hasImage
            ? CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(image),
                onBackgroundImageError: (_, __) {},
                child: const Icon(Icons.person, size: 20),
              )
            : const CircleAvatar(
                radius: 30, child: Icon(Icons.person, size: 20)),
        const SizedBox(height: 8),
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'DIN_Next_Rounded',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$elo ELO',
            style: TextStyle(fontSize: 12, fontFamily: 'DIN_Next_Rounded'),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 75,
          height: podiumHeight,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(bannerAsset),
              fit: BoxFit.fitWidth,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
