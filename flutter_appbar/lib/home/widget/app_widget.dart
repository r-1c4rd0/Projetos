import 'package:flutter/cupertino.dart';
import 'package:flutter_appbar/core/app_gradients.dart';
import 'package:flutter_appbar/core/app_text_style.dart';

class AppBarWidget extends PreferredSize {
  AppBarWidget({Key? key})
      : super(
          key: key,
          preferredSize: const Size.fromHeight(28),
          child: Builder(builder: (context) {
            return SizedBox(
              height: 80,
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                width: double.infinity,
                decoration: const BoxDecoration(gradient: AppGradients.linear),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'Olá',
                          style: AppTextStyles.title,
                          children: [
                            TextSpan(text: ' ', style: AppTextStyles.titleBold),
                            TextSpan(
                                text: 'Ricardo', style: AppTextStyles.title),
                          ],
                        ),
                      ),
                    ]),
              ),
            );
          }),
        );
}
