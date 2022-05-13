import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sortudo/core/app_colors.dart';

class SelectButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  SelectButton({
    Key? key,
    required this.label,
    required this.onTap,
  })  : assert([
          "Inicio",
          "Sorteios",
          "Ganhadores",
          "Regulamento",
          "A Sortudo",
          "Minhas compras",
        ].contains(label)),
        super(key: key);

  final config = {
    "Inicio": {
      "borderColor": AppColors.levelButtonBorderPerito,
      "color": AppColors.levelButtonBorderPerito,
      "fontColor": AppColors.levelButtonTextMedio,
    },
    "Sorteios": {
      "borderColor": AppColors.levelButtonBorderPerito,
      "color": AppColors.levelButtonBorderPerito,
      "fontColor": AppColors.levelButtonTextMedio,
    },
    "Ganhadores": {
      "borderColor": AppColors.levelButtonBorderPerito,
      "color": AppColors.levelButtonBorderPerito,
      "fontColor": AppColors.levelButtonTextMedio,
    },
    "Regulamento": {
      "borderColor": AppColors.levelButtonBorderPerito,
      "color": AppColors.levelButtonBorderPerito,
      "fontColor": AppColors.levelButtonTextMedio,
    },
    "A Sortudo": {
      "borderColor": AppColors.levelButtonBorderPerito,
      "color": AppColors.levelButtonBorderPerito,
      "fontColor": AppColors.levelButtonTextMedio,
    },
    "Minhas compras": {
      "borderColor": AppColors.levelButtonBorderPerito,
      "color": AppColors.levelButtonBorderPerito,
      "fontColor": AppColors.levelButtonTextPerito,
    },
  };
  Color get borderColor => config[label]!["borderColor"]!;
  Color get textColor => config[label]!["textColor"]!;
  Color get fontColor => config[label]!["fontColor"]!;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color.fromARGB(255, 6, 7, 70),
            Color.fromARGB(255, 9, 5, 74),
            Color.fromARGB(255, 88, 95, 195),
          ],
        ),
        borderRadius: BorderRadius.all(Radius.circular(90)),
      ),
      width: 130,
      child: Flexible(
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.all(4),
            primary: Colors.white,
            textStyle: const TextStyle(fontSize: 14),
          ),
          onPressed: () {
            onTap();
          },
          child: Expanded(
            child: Text(label,
                style: GoogleFonts.notoSans(
                  fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                  color: fontColor,
                )),
          ),
        ),
      ),
    );
  }
}
