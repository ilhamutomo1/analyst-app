import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:takraw_analyst/pages/help_page.dart';
import 'package:takraw_analyst/pages/home_page.dart';
import 'package:takraw_analyst/pages/input_team_page.dart';
import 'package:takraw_analyst/pages/history_page.dart';
import 'package:takraw_analyst/pages/profile_page.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sepak Takraw Analytics',
      theme: ThemeData.dark(),
      initialRoute: '/',
      navigatorObservers: [routeObserver],
      routes: {
        '/': (context) => const HomePage(),
        '/player_input': (context) => PlayerInputPage(),
        '/history': (context) => HistoryPage(),
        '/profile': (context) => ProfilePage(),
        '/help': (context) => HelpPage(),
      },
    );
  }
}
