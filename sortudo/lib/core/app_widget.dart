import 'package:flutter/material.dart';
import 'package:sortudo/home/home_page.dart';
import 'package:sortudo/routes/app_routes.dart';

import '../home/widget/prize/prize_draw_widget.dart';
import '../views/contest_luck.dart';
import '../views/luck_one.dart';
import '../views/regulation_page.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sortudo',
      initialRoute: '/',
      routes: {
        AppRoutes.HOMEPAGE: (context) => const HomePage(),
        AppRoutes.CONSTESTLUCK: (context) => const ContestLuck(),
        AppRoutes.REGULATION: (context) => const RegulationPage(),
        AppRoutes.LUCK_ONE: (context) => const LuckOne(),
        AppRoutes.PrizeDrawWidget: (context) => PrizeDrawWidget(
              label: "pagos",
            ),
      },
    );
  }
}
