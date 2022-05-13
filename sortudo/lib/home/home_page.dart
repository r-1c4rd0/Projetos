import 'package:flutter/material.dart';
import 'package:sortudo/home/widget/app_bar_widget.dart';
import 'package:sortudo/home/widget/award_card/award_card_widget.dart';

import '../model/user_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    Widget titleSection = Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 5; i++)
                      const Icon(
                        Icons.star,
                        color: Color.fromARGB(255, 216, 230, 20),
                      ),
                    Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: const Text(
                        'Sorteios',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                    ),
                    for (var i = 0; i < 5; i++)
                      const Icon(
                        Icons.star,
                        color: Color.fromARGB(255, 216, 230, 20),
                      ),
                  ],
                ),
                const Text(
                  'Valores promocionais por cota, aproveite e confira nossos prêmios.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget cardSection = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        AwardCardWidget(
            title: 'Sortudo',
            textSection: 'Sorteio de números',
            image: 'assets/images/award_card_1.jpg'),
        AwardCardWidget(
            title: 'Sortudo',
            textSection: 'Sorteio de números',
            image: 'assets/images/award_card_2.jpg'),
        AwardCardWidget(
            title: 'Sortudo',
            textSection: 'Sorteio de números',
            image: 'assets/images/award_card_3.jpg'),
        AwardCardWidget(
            title: 'Sortudo',
            textSection: 'Sorteio de números',
            image: 'assets/images/award_card_4.jpg'),
      ],
    );

    return Scaffold(
      appBar: AppBarWidget(
          user: UserModel(
        name: 'Ricardo',
        photoUrl: 'https://avatars.githubusercontent.com/u/28695175?s=40&v=4',
      )),
      body: ListView(
        children: [
          Expanded(
              child: Image.asset('assets/images/fotopagina1.png',
                  fit: BoxFit.cover)),
          titleSection,
          cardSection,
        ],
      ),
    );
  }
}
