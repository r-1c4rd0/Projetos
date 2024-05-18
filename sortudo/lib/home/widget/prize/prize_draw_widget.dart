import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

class PrizeDrawWidget extends StatelessWidget {
  final String label;
  PrizeDrawWidget({Key? key, required this.label})
      : assert([
          "todos",
          "Disponiveis",
          "Reservados",
          "Pagos",
          "Meus_numeros",
        ].contains(label)),
        super(key: key);

  final config = {
    "todos": {
      "borderColor": const Color.fromARGB(255, 77, 72, 73),
      "color": const Color.fromARGB(255, 217, 230, 233),
      "fontColor": const Color.fromARGB(255, 54, 57, 56),
    },
    "Disponiveis": {
      "borderColor": const Color.fromARGB(255, 233, 227, 229),
      "color": const Color.fromARGB(255, 152, 140, 144),
      "fontColor": const Color.fromARGB(255, 144, 154, 148),
    },
    "Pagos": {
      "borderColor": const Color.fromARGB(255, 31, 187, 62),
      "color": const Color.fromARGB(255, 52, 201, 38),
      "fontColor": const Color.fromARGB(255, 247, 247, 247),
    },
    "Reservados": {
      "borderColor": const Color.fromARGB(255, 213, 123, 26),
      "color": const Color.fromARGB(255, 186, 101, 45),
      "fontColor": const Color.fromARGB(255, 247, 249, 250),
    },
    "Meus_numeros": {
      "borderColor": AppColors.levelButtonBorderPerito,
      "color": AppColors.levelButtonBorderPerito,
      "fontColor": AppColors.levelButtonTextMedio,
    },
  };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 65,
              childAspectRatio: 1 / 1,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2),
          itemCount: 10,
          itemBuilder: (context, index) {
            return Card(
              color: const Color.fromARGB(255, 191, 241, 195),
              shape: const CircleBorder(
                // <-- perfect for circular images

                side: BorderSide(
                  color: Color.fromARGB(255, 80, 169, 88),
                  width: 1,
                ),
              ),
              child: Center(
                  child: Text("$index",
                      style: TextStyle(
                          fontSize:
                              12 * MediaQuery.of(context).textScaleFactor))),
            );
          }),
    );
  }
}
