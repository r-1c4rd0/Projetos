import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../model/todo.dart';
import '../pages/edit_page.dart';

class TodoItens extends StatelessWidget {
  const TodoItens(
      {Key? key,
      required this.todo,
      required this.toDelete,
      required this.toChange,
      required this.toEdit
      //required this.toDescriptionUpdate,
      })
      : super(key: key);
  final Todo todo;
  final Function toEdit;
  final Function(Todo) toDelete;
  final Function(Todo) toChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Slidable(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: todo.done ? Colors.green[200] : Colors.purple[100],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat('dd/MM/yyy - HH:mm').format(todo.date),
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.right,
              ),
              Text(
                todo.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                todo.description!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 1,
          children: [
            SlidableAction(
              onPressed: (context) => {toChange(todo)},
              backgroundColor: todo.done ? Colors.grey : Colors.green,
              foregroundColor: Colors.white,
              icon: todo.done ? Icons.close : Icons.check,
              label: todo.done ? 'Desfazer' : 'Feito',
            ),
            SlidableAction(
              onPressed: (context) => {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditPage(edit: toEdit, todo: todo),
                    ))
              },
              backgroundColor: todo.done ? Colors.grey : Colors.yellow,
              foregroundColor: Colors.white,
              icon: todo.done ? Icons.close : Icons.check,
              label: 'Editar',
            ),
            SlidableAction(
              onPressed: (context) => {toDelete(todo)},
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Deletar',
            ),
          ],
        ),
      ),
    );
  }
}
