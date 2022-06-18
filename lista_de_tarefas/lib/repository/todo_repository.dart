import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/todo.dart';

const todoListkey = 'todo_list';

class TodoRespository {
  late SharedPreferences sharedPreferences;

  Future<List<Todo>> getTodoList() async {
    sharedPreferences = await SharedPreferences.getInstance();
    final String jsonString = sharedPreferences.getString(todoListkey) ?? '[]';
    final List jsonDecoded = json.decode(jsonString) as List;
    return jsonDecoded.map((e) => Todo.fromJson(e)).toList();
  }

  void saveTodoList(List<Todo> todos) {
    final String jasonString = json.encode(todos);
    try {
      sharedPreferences.setString('todo_list', jasonString);
    } catch (e) {
      e.toString();
    }
  }
}
