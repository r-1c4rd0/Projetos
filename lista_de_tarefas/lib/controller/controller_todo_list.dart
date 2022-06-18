import '../model/todo.dart';

class ControllerTodoList {
  List<Todo> todoItens = [];
  Todo? itemRemoved;
  int? position;

  void toDelete(Todo todo) => {todoItens.remove(todo)};
  void toClean() => {todoItens.clear()};
  void storeTask(Todo todo, int p) => {itemRemoved = todo, position = p};

  void toChangeStatusTask(Todo todo) {
    if (todo.done) {
      todo.done = false;
    } else {
      todo.done = true;
    }
  }

  void toSaveTask(Todo todo) {
    if (todo.title.isEmpty) return;
    todoItens.add(todo);
  }

  void returnTask() {
    todoItens.insert(position!, itemRemoved!);
  }

  List<Todo> getList() {
    return todoItens;
  }

  void setList(List<Todo> todos) {
    todoItens = todos;
  }
}
