import 'package:flutter/material.dart';

class AwardCardWidget extends StatelessWidget {
  final String title;
  final String textSection;
  final String image;

  const AwardCardWidget({
    Key? key,
    required this.title,
    required this.textSection,
    required this.image,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Image.asset(
              image,
              height: 200,
              width: 200,
              fit: BoxFit.cover,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            textSection,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
