import 'package:app/model/trade.dart';
import 'package:app/service/trade_service.dart';
import 'package:app/view/whatadeal_screen.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String errorMessage = '';
  Student? user;

  @override
  void initState() {
    user = widget.user;
    super.initState();
  }

  Future<void> updateUserPoints() async {
    await UserService.updateUserPoints(user!);
  }

  Future<void> _purchase(int reqPoint) async {
    if(_isPurchaseValid(reqPoint)) {
      pref = await SharedPreferences.getInstance();
      int? id = pref.getInt('userId');
      
      setState(() {
        user!.points = (user!.points ?? 0) - reqPoint;
      });

      try {
        // Create the trade record in backend
        await TradeService.createUserTrade(id!, widget.trade.id, 0);
        // Persist the new point balance
        await updateUserPoints();

        print('Pembelian berhasil!');
        if (mounted) {
          showCompletionDialog(context, "Transaksi poin anda telah berhasil!", false);
        }
      } catch (e) {
        debugPrint("Error during purchase: $e");
        if (mounted) {
          setState(() {
            errorMessage = 'Terjadi kesalahan saat melakukan pembelian.';
          });
        }
      }
    } else {
      setState(() {
        errorMessage = 'Poin atau Tingkatan (Elo) Anda tidak mencukupi.';
      });
    }
  }

  bool _isPurchaseValid(int reqPoint) {
    if (user == null) return false;
    
    // Check Point balance
    if ((user!.points ?? 0) < reqPoint) return false;

    // Check Elo Rank Requirement
    final int userElo = user!.elo ?? 750;
    switch (widget.trade.requiredBadgeType.toUpperCase()) {
      case 'BEGINNER':
        return userElo >= 750;
      case 'INTERMEDIATE':
        return userElo >= 1200;
      case 'ADVANCE':
        return userElo >= 1600;
      default:
        return true;
    }
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
              fit: BoxFit.cover,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text("Pointku : ${user?.points ?? 0} ", style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'DIN_Next_Rounded',
                    ),),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        user?.eloTitle ?? 'Beginner',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: 'DIN_Next_Rounded'
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12,),
                ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: widget.trade.image.toLowerCase().startsWith('http')
                    ? Image.network(
                      widget.trade.image,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Image.asset('lib/assets/pictures/icon.png'),
                      )
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
                  'Dapatkan tingkatan ${widget.trade.requiredBadgeType} dengan mengumpulkan Elo, dan tukarkan point sebanyak $reqPoint untuk mendapatkan penawaran ini!',
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPurchaseValid(reqPoint) ? () => _purchase(reqPoint) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Purchase with Points',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
      ),
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
                    ? Image.network(
                        widget.trade.image,
                        height: 180,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'lib/assets/pictures/icon.png',
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      )
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
