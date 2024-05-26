import 'package:flutter/material.dart';

import '../model/todo.dart';

//Pagina para editar uma tarefaz, ela recebe por parametro a função edit a todo a ser
//editada, de forma obrigatoria.

class EditPage extends StatefulWidget {
  final Function edit;
  final Todo todo;
  const EditPage({required this.todo, required this.edit, Key? key})
      : super(key: key);

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  @override
  Widget build(BuildContext context) {
    final TextEditingController controllerTitle =
        TextEditingController(); //controler do campo titulo.
    final TextEditingController controllerDescription =
        TextEditingController(); //controler do compo descrição.
    String? desc = widget.todo.description;
    String title = widget.todo.title;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // centraliza do titulo da APPBAR
        title: const Text("Edite sua tarefa"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.red],
            ),
          ),
        ),
      ),
      //SingleScrollView para a tela ter scroll.
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              //SizeBox para incluir imagem.

              TextField(
                controller: controllerTitle,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: title,
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  labelStyle: const TextStyle(color: Colors.deepPurple),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: TextField(
                  maxLines: 5,
                  controller: controllerDescription,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: desc,
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.deepPurple,
                        width: 2,
                      ),
                    ),
                    labelStyle: const TextStyle(color: Colors.deepPurple),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.edit(
                      widget.todo,
                      controllerTitle.text,
                      controllerDescription
                          .text); // chamando a função Edit e passando o todo.
                  controllerTitle.clear(); //limpa o campo titulo.
                  controllerDescription.clear(); //limpa o campo descrição.
                  Navigator.pop(context); // fechar a tela após salvar.
                },
                child: const Text(
                  "Salvar",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                style: TextButton.styleFrom(
                  primary: Colors.purple[100],
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
