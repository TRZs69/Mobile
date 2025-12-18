import 'package:app/model/trade.dart';
import 'package:app/model/user_trade.dart';
import 'package:app/service/trade_service.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/main_screen.dart';
import 'package:app/view/trade_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';

class TradeScreen extends StatefulWidget {
  final Student user;
  const TradeScreen({super.key, required this.user});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {

  late SharedPreferences pref;
  List<TradeModel> trades = [];
  List<UserTrade> userTrade = [];

  @override
  void initState() {
    super.initState();
    fetchTrades();

    trades = trades;
  }

  Future<void> fetchTrades() async {
    await getAllTrades(); // Wait until all trades are fetched
    await getUserTrade(); // Then fetch user-specific trades
  }

  Future<void> getAllTrades() async {
    try {
      final result = await TradeService.getAllTrades();
      if (!mounted) return;

      setState(() {
        trades = result;
      });
    } catch (e) {
      debugPrint("Error fetching trades: $e");
    }
  }

  Future<void> getUserTrade() async {
    final result = await TradeService.getUserTrade(widget.user.id);
    setState(() {
      userTrade = result;
    });

    if (trades.isNotEmpty && userTrade.isNotEmpty) {
      final tradeIds = userTrade.map((trade) => trade.tradeId).toSet();

      for (var trade in trades) {
        trade.hasTrade = tradeIds.contains(trade.id);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Trade"),
        backgroundColor: AppColors.primaryColor,
        leading: IconButton(
            onPressed: (){
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => Mainscreen(navIndex : 4)),
              );
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
        child: trades.isEmpty
            ? Center(
              child: Text('Penawaran belum tersedia',
                  style: TextStyle(
                      fontFamily: 'DIN_Next_Rounded',
                      color: AppColors.primaryColor
                  )
              ),
            )
            : ListView.builder(
              itemCount: trades.length,
              itemBuilder: (context, index) {
                final trade = trades[index];
                return ListTile(
                  leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: trade.image.toLowerCase().startsWith('http')
                          ? Image.network(trade.image)
                          : Image.asset(trade.image)
                  ),
                  title: Text(
                      trade.title,
                      style: TextStyle(
                          fontFamily: 'DIN_Next_Rounded',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor
                      )),
                  subtitle: Text(
                    'Tukarkan badge ${trade.requiredBadgeType} anda untuk mendapatkan penawaran ini!',
                    style: TextStyle(
                      fontFamily: 'DIN_Next_Rounded',
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TradeDetailScreen(trade: trade, user: widget.user,),
                      ),
                    );
                  },
                );
              },
            ),
      )
    );
  }
}
