class Todo {
  Todo(
      {required this.title,
      this.description,
      required this.date,
      required this.done});
  String title;
  String? description;
  DateTime date;
  bool done;

  Todo.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        description = json['description'],
        date = DateTime.parse(json['date']),
        done = json['done'];
  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'done': done,
      };
}
