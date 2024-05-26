import 'package:flutter/material.dart';

class WebAppBar extends StatelessWidget {
  const WebAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Image.asset(
            "images/blocks.png",
            fit: BoxFit.contain,
          ),
          Expanded(child: Container()),
          const SizedBox(
            width: 10,
          ),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: OutlinedButton(
                onPressed: () {},
                child: const Text("Cadastrar"),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.lightBlueAccent,
                  primary: Colors.white,
                ),
              ),
            ),
          const SizedBox(
            width: 10,
          ),
        ],
      ),
    );
  }
}
