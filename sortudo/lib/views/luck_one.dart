import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../home/widget/app_bar_widget.dart';
import '../model/user_model.dart';

class LuckOne extends StatelessWidget {
  const LuckOne({Key? key}) : super(key: key);
  final String assetName = 'assets/images/O SORTUDO.svg';

  @override
  Widget build(BuildContext context) {
    final Widget svg = SvgPicture.asset(
      assetName,
      semanticsLabel: 'O SORTUDO',
      height: 100,
      width: 1098,
    );
    return Scaffold(
      appBar: AppBarWidget(
          user: UserModel(
        name: 'Ricardo',
        photoUrl: 'https://avatars.githubusercontent.com/u/28695175?s=40&v=4',
      )),
      body: ListView(
        children: [
          // ignore: sized_box_for_whitespace
          Container(
            width: 1098,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 288.0),
            child: Column(
              children: [
                const SizedBox(height: 51),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('NOSSA EMPRESA',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        )),
                  ],
                ),
                const SizedBox(
                  height: 58,
                ),
                Row(
                  children: const [
                    Text('QUEM SOMOS?',
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        )),
                  ],
                ),
                const SizedBox(
                  height: 58,
                ),
                Row(
                  children: const [
                    Flexible(
                      child: Text(
                          'SOMOS UMA EMPRESA DA MODALIDADE FILANTROPIA PREMIÁVEL REGULAMENTADA NA LEI FEDERAL\n'
                          'N. 13.019/14 ART. 84 B , 84 C, SOB O CNPJ 38.240.687/0001-05. DESDE 2019 ESTAMOS ENTREGANDO\n'
                          'PRÊMIOS E REALIZANDO SONHOS EM TODO BRASIL, ALÉM DE CONTRIBUIR COM A SOCIEDADE EM UMA PARCERIA\n'
                          'COM A INSTITUIÇÃO UNIÃO AO PRÓXIMO E UP AMOR ANIMAL.',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          )),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 58,
                ),
                svg,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
