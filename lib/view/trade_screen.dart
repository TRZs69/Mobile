import 'package:app/model/trade.dart';
import 'package:app/model/user_trade.dart';
import 'package:app/service/trade_service.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/main_screen.dart';
import 'package:app/view/trade_detail_screen.dart';
import 'package:app/view/widgets/custom_refresh_scroll.dart';
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTrades();

    trades = trades;
  }

  Future<void> fetchTrades() async {
    setState(() => isLoading = true);
    await getAllTrades();
    await getUserTrade();
    setState(() => isLoading = false);
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
        child: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : trades.isEmpty
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
                  leading: Stack(
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: trade.image.toLowerCase().startsWith('http')
                            ? Image.network(
                              trade.image,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2,));
                              },
                              errorBuilder: (context, error, stackTrace) => Image.asset('lib/assets/pictures/icon.png'),
                            )
                              : Image.asset(trade.image, width: 50, height: 50, fit: BoxFit.cover)
                      ),
                      if (trade.hasTrade)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                            trade.title,
                            style: const TextStyle(
                                fontFamily: 'DIN_Next_Rounded',
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryColor
                            )),
                      ),
                      if (trade.hasTrade)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green, width: 0.5),
                          ),
                          child: const Text(
                            "Purchased",
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'DIN_Next_Rounded',
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    trade.hasTrade 
                      ? 'Anda sudah memiliki penawaran ini.'
                      : 'Miliki tingkatan ${trade.requiredBadgeType} untuk dapat menukarkan poin dengan penawaran ini!',
                    style: const TextStyle(
                      fontFamily: 'DIN_Next_Rounded',
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TradeDetailScreen(trade: trade, user: widget.user,),
                      ),
                    ).then((_) => fetchTrades()); // Refresh state when coming back
                  },
                );
              },
            ),
      )
    );
  }
}
