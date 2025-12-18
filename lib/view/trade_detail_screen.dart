import 'package:app/model/badge.dart';
import 'package:app/model/trade.dart';
import 'package:app/model/user_badge.dart';
import 'package:app/service/badge_service.dart';
import 'package:app/service/trade_service.dart';
import 'package:app/service/user_badge_service.dart';
import 'package:app/view/whatadeal_screen.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

import '../model/user.dart';
import '../service/user_service.dart';
import '../utils/colors.dart';

class TradeDetailScreen extends StatefulWidget {
  final TradeModel trade;
  final Student user;

  const TradeDetailScreen({super.key, required this.trade, required this.user});

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {

  late SharedPreferences pref;
  List<UserBadge> userBadges = [];
  List<BadgeModel> allowedBadges = [];
  List<UserBadge> userBadgesWithStatus = [];

  List<UserBadge> selectedBadges = [];
  String errorMessage = '';
  Student? user;

  @override
  void initState() {
    user = widget.user;
    getUserBadges();
    getUserBadgesWithStatus();
    super.initState();
  }

  Future<void> getUserBadges() async {
    try {
      pref = await SharedPreferences.getInstance();
      int? id = pref.getInt('userId');
      if (id == null) return;

      final result = await BadgeService.getUserBadgeListByUserId(id);
      if (!mounted) return;

      setState(() {
        userBadges = result;
      });
    } catch (e) {
      debugPrint("Error fetching user badges: $e");
    }
  }

  Future<void> getUserBadgesWithStatus() async {
    try {
      pref = await SharedPreferences.getInstance();
      int? id = pref.getInt('userId');
      if (id == null) return;

      final result = await BadgeService.getUserBadgeListWithStatusByUserId(id);
      if (!mounted) return;

      setState(() {
        userBadgesWithStatus = result;
      });
    } catch (e) {
      debugPrint("Error fetching user badges: $e");
    }
  }

  Future<void> updateUserPoints() async {
    await UserService.updateUserPoints(user!);
  }

  Future<void> _purchase(int reqPoint) async {
    if(_isPurchaseValid()) {
      pref = await SharedPreferences.getInstance();
      int? id = pref.getInt('userId');
      setState(() {
        user!.points = user!.points! - reqPoint;
      });

      try {
        await createUserTrade(id!, widget.trade.id, selectedBadges.first.id);
        await updateUserBadgeStatus(selectedBadges.first.id, true);
        getUserBadges();
        updateUserPoints();

        print('Pembelian berhasil!');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCompletionDialog(context, "Transaksi badge anda telah berhasil!", false);
        });
      } catch (e) {
        debugPrint("Error during purchase: $e");
        setState(() {
          errorMessage = 'Terjadi kesalahan saat melakukan pembelian.';
        });
      }
    } else {
      setState(() {
        errorMessage = 'Badge yang dipilih tidak sesuai.';
      });
    }
  }

  bool _isPurchaseValid() {
    if (selectedBadges.isEmpty) {
      return false;
    }
    for (var badge in selectedBadges) {
      if (badge.badge.type != widget.trade.requiredBadgeType) {
        return false;
      }
      if( badge.badge.type.toUpperCase() == 'BEGINNER' && user!.points! < 100){
        return false;
      }
      if( badge.badge.type.toUpperCase() == 'INTERMEDIATE' && user!.points! < 300){
        return false;
      }
      if( badge.badge.type.toUpperCase() == 'ADVANCE' && user!.points! < 500){
        return false;
      }
    }
    return true;
  }

  Future<void> createUserTrade(int userId, int tradeId, int badgeId) async{
    await TradeService.createUserTrade(userId, tradeId, badgeId);
  }

  Future<void> updateUserBadgeStatus(int badgeId, bool status) async{
    await UserBadgeService.updateUserBadgeStatus(badgeId, status);
  }

  void showCompletionDialog(BuildContext context, String message, bool isAssignment) {
    Future.delayed(Duration(milliseconds: 100), () {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WhatADealScreen(
              message: message,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int reqPoint = 0;
    switch (widget.trade.requiredBadgeType.toUpperCase()) {
      case 'BEGINNER' :
        reqPoint = 300;
      case 'INTERMEDIATE' :
        reqPoint = 500;
      case 'ADVANCE' :
        reqPoint = 800;
      default :
        reqPoint = 0;
    }
    return !widget.trade.hasTrade ? Scaffold(
      appBar: AppBar(
        title: Text("Trade Detail"),
        backgroundColor: AppColors.primaryColor,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(LineAwesomeIcons.angle_left_solid, color: Colors.white)),
        titleTextStyle: TextStyle(
            fontFamily: 'DIN_Next_Rounded',
            fontSize: 24,
            color: Colors.white
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                  'lib/assets/pictures/background-pattern.png'
              ),
              fit: BoxFit.cover, // Menyesuaikan gambar agar mengisi layar
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pointku : ${user?.points != null ? user!.points : 0}", style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'DIN_Next_Rounded',
                ),),
                SizedBox(height: 12,),
                ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: widget.trade.image.toLowerCase().startsWith('http')
                        ? Image.network(widget.trade.image)
                        : Image.asset(widget.trade.image)
                ),
                SizedBox(height: 16),
                Text(
                  widget.trade.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DIN_Next_Rounded',
                    color: AppColors.primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.trade.description,
                  style: TextStyle(
                    fontFamily: 'DIN_Next_Rounded',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Persyaratan',
                  style: TextStyle(
                      fontFamily: 'DIN_Next_Rounded',
                      fontWeight: FontWeight.w600,
                      fontSize: 16
                  ),
                ),
                Text(
                  'Tukarkan satu buah badge dengan tipe ${widget.trade.requiredBadgeType} dan tukarkan point sebanyak ${reqPoint} untuk mendapatkan penawaran ini!',
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                ),
                SizedBox(height: 16),
                Text('Pilih Badge untuk ditukarkan:', style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
                userBadges.isEmpty
                    ? Text('Anda belum memiliki badge.', style: TextStyle(fontFamily: 'DIN_Next_Rounded'))
                    : Wrap(
                  spacing: 8.0,
                  children: userBadges.map((badge) {
                    return ChoiceChip(
                      selectedColor: AppColors.accentColor,
                      backgroundColor: Colors.white,
                      label: Text(
                        badge.badge.name,
                        style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                      ),
                      selected: selectedBadges.contains(badge), // Checks if this is selected
                      onSelected: !badge.isPurchased
                          ? (selected) {
                        setState(() {
                          if (selected) {
                            selectedBadges.clear(); // Clears previous selection
                            selectedBadges.add(badge); // Adds new selection
                          }
                          errorMessage = '';
                        });
                      }
                          : null,
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPurchaseValid() ? () => _purchase(reqPoint) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                    child: Text(
                      'Purchase',
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'DIN_Next_Rounded'
                      ),
                    ),
                  ),
                ),
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      )
    ) :  Scaffold(
      appBar: AppBar(
        title: const Text("Trade Redeemed", style: TextStyle(fontFamily: 'DIN_Next_Rounded',),),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(LineAwesomeIcons.angle_left_solid, color: Colors.white),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🎉 Success Message
              const Text(
                "Congratulations!",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontFamily: 'DIN_Next_Rounded',
                ),
              ),
              const SizedBox(height: 10),

              const Text(
                "You have successfully redeemed this trade.",
                style: TextStyle(fontSize: 18, color: Colors.black54, fontFamily: 'DIN_Next_Rounded',),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // 📌 Trade Details
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.trade.image.toLowerCase().startsWith('http')
                    ? Image.network(widget.trade.image, height: 180, fit: BoxFit.cover)
                    : Image.asset(widget.trade.image, height: 180, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),

              Text(
                widget.trade.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'DIN_Next_Rounded',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              Text(
                widget.trade.description,
                style: const TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'DIN_Next_Rounded',),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: const Text("Back to Trades", style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
