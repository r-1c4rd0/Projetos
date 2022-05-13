import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../home/widget/app_bar_widget.dart';
import '../home/widget/prize/prize_draw_widget.dart';
import '../model/user_model.dart';

class ContestLuck extends StatefulWidget {
  const ContestLuck({Key? key}) : super(key: key);

  @override
  State<ContestLuck> createState() => _ContestLuckState();
}

class _ContestLuckState extends State<ContestLuck> {
  @override
  Widget build(BuildContext context) {
    Column _buildButtonColumn(Color color, IconData icon, String label) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ],
      );
    }

    Color color = AppColors.darkGreen;

    Widget buttonSection = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButtonColumn(color, Icons.all_out, "Todos"),
        _buildButtonColumn(
            color, Icons.auto_awesome_motion_sharp, "Disponíveis"),
        _buildButtonColumn(color, Icons.back_hand_outlined, "Reservados"),
        _buildButtonColumn(color, Icons.money, "Pagos"),
        _buildButtonColumn(color, Icons.person, "Meus números"),
      ],
    );
    return Scaffold(
      appBar: AppBarWidget(
        user: UserModel(
          name: 'Ricardo',
          photoUrl: 'https://avatars.githubusercontent.com/u/28695175?s=40&v=4',
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Container(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: const BoxDecoration(),
              child: Image.asset(
                'assets/images/award_card_1.jpg',
                width: 400,
                height: 400,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          buttonSection,
          PrizeDrawWidget(
            label: "Pagos",
          ),
        ],
      ),
    );
  }
}
