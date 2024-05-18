import 'package:flutter/material.dart';
import 'package:lista_de_tarefas/model/todo.dart';

import '../controller/controller_todo_list.dart';
import '../repository/todo_repository.dart';
import '../widgets/todo_list_itens.dart';

class TodoList extends StatefulWidget {
  const TodoList({Key? key}) : super(key: key);

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final TextEditingController controllerTitle = TextEditingController();
  final TextEditingController controllerDescription = TextEditingController();
  final ControllerTodoList controllerTodoList = ControllerTodoList();
  final TodoRespository todoRespository = TodoRespository();

  @override
  void initState() {
    super.initState();
    todoRespository.getTodoList().then((value) {
      setState(() {
        controllerTodoList.setList(value);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          title: const Text('Your smart list'),
          leading: const Icon(Icons.person_rounded),
          elevation: 4.5,
          actions: [
            IconButton(
              onPressed: () {
                showConfirmationAllDeleteTodos();
              },
              icon: const Icon(Icons.cleaning_services),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (Todo todo in controllerTodoList.getList())
                      TodoItens(
                        todo: todo,
                        toDelete: toDelete,
                        toChange: toChange,
                        toEdit: toEdit,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Você tem ${controllerTodoList.getList().length} tarefas pendentes.',
                      style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.w900,
                          fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                      onPressed: () {
                        showAddItem();
                      },
                      backgroundColor: Colors.purple[600],
                      child: const Icon(Icons.add)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void toDelete(Todo item) {
    int p = controllerTodoList.getList().indexOf(item);
    controllerTodoList.storeTask(item, p);
    setState(() {
      controllerTodoList.toDelete(item);
    });

    upDateJson();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'A tarefa ${item.title} foi removida.',
          style: const TextStyle(
            color: Colors.purple,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        action: SnackBarAction(
          label: 'Desfazer',
          textColor: Colors.purple,
          onPressed: () {
            setState(() {
              controllerTodoList.returnTask();
              upDateJson();
            });
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void toChange(Todo item) {
    setState(() {
      controllerTodoList.toChangeStatusTask(item);
    });
    upDateJson();
  }

  void showConfirmationAllDeleteTodos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Tarefas'),
        content: const Text('Deseja ecluir todas lista de tarefas?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
            style: TextButton.styleFrom(
              primary: const Color(0xff00d7f3),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              toClean();
            },
            child: const Text('Limpar'),
            style: TextButton.styleFrom(
              primary: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void showAddItem() {
    showDialog(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: SimpleDialog(
                    contentPadding: const EdgeInsets.all(18),
                    title: const Center(
                      child: Text(
                        '                    Nova tarefa                   ',
                        style: TextStyle(color: Colors.purple),
                      ),
                    ),
                    children: [
                      TextField(
                        controller: controllerTitle,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Titulo',
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.purple,
                              width: 2,
                            ),
                          ),
                          labelStyle: TextStyle(color: Colors.purple),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 150,
                        ),
                        child: TextField(
                          maxLines: null,
                          controller: controllerDescription,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Descrição',
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.purple,
                                width: 2,
                              ),
                            ),
                            labelStyle: TextStyle(color: Colors.purple),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          addItem();
                        },
                        child: const Text(
                          'Salvar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          primary: Colors.purple[100],
                          backgroundColor: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void addItem() {
    String text = controllerTitle.text;
    String desc = controllerDescription.text;
    setState(() {
      Todo newItens = Todo(
          title: text, description: desc, date: DateTime.now(), done: false);
      controllerTodoList.toSaveTask(newItens);
      controllerTitle.clear();
      controllerDescription.clear();
    });
    upDateJson();
  }

  void toEdit(Todo todo, String title, String desc) {
    setState(() {
      int position = controllerTodoList.getList().indexOf(todo);

      controllerTodoList.toDelete(todo);
      Todo newTodo = Todo(
          title: title, description: desc, date: DateTime.now(), done: false);
      controllerTodoList.storeTask(newTodo, position);
      controllerTodoList.returnTask();
      upDateJson();
    });
  } //Criando função nova

  void upDateJson() =>
      {todoRespository.saveTodoList(controllerTodoList.getList())};

  void toClean() {
    setState(() {
      controllerTodoList.toClean();
    });
    upDateJson();
  }
}
