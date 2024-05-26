import 'package:flutter/material.dart';
import 'package:lista_de_tarefas/pages/todo_list.dart';

class Appwidget extends StatelessWidget {
  const Appwidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TodoList(),
    );
  }
}
