import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sortudo/core/app_gradients.dart';
import 'package:sortudo/core/app_text_styles.dart';
import 'package:sortudo/home/widget/select_button/select_button_widget.dart';
import 'package:sortudo/routes/app_routes.dart';

import '../../model/user_model.dart';

class AppBarWidget extends PreferredSize {
  final UserModel user;

  AppBarWidget({Key? key, required this.user})
      : super(
            key: key,
            preferredSize: const Size.fromHeight(28),
            child: Builder(builder: (context) {
              return SizedBox(
                height: 80,
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  width: double.maxFinite,
                  decoration:
                      const BoxDecoration(gradient: AppGradients.linear),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(TextSpan(
                          text: "Olá, ",
                          style: AppTextStyles.title,
                          children: [
                            TextSpan(
                              text: user.name,
                              style: AppTextStyles.titleBold,
                            )
                          ])),
                      Container(
                        width: 910,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            SelectButton(
                              label: 'Inicio',
                              onTap: () {
                                Navigator.pushNamed(
                                    context, AppRoutes.HOMEPAGE);
                              },
                            ),
                            SelectButton(
                              label: 'Sorteios',
                              onTap: () {
                                Navigator.pushNamed(
                                    context, AppRoutes.CONSTESTLUCK);
                              },
                            ),
                            SelectButton(
                              label: 'Ganhadores',
                              onTap: () {
                                Navigator.pushNamed(context, AppRoutes.PROFILE);
                              },
                            ),
                            SelectButton(
                              label: 'A Sortudo',
                              onTap: () {
                                Navigator.pushNamed(
                                    context, AppRoutes.LUCK_ONE);
                              },
                            ),
                            SelectButton(
                                label: 'Regulamento',
                                onTap: () {
                                  Navigator.pushNamed(
                                      context, AppRoutes.REGULATION);
                                }),
                            SelectButton(
                                label: 'Minhas compras',
                                onTap: () {
                                  Navigator.pushNamed(
                                      context, AppRoutes.PrizeDrawWidget);
                                }),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 26),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: NetworkImage(user.photoUrl),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }));
}
