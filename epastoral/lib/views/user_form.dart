import 'package:epastoral/components/TakePictureScreen.dart';
import 'package:epastoral/models/user.dart';
import 'package:epastoral/provider/users.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserForm extends StatelessWidget {
  final _form = GlobalKey<FormState>();
  final Map<String, Object> _formData = {};

  void _loadFormData(User user) {
    if (user != null) {
      _formData['id'] = user.id;
      _formData['name'] = user.name;
      _formData['email'] = user.email;
      _formData['avatarUrl'] = user.avatarUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final User user = ModalRoute.of(context).settings.arguments;
    _loadFormData(user);

    return Scaffold(
        appBar: AppBar(
          title: Text('Formulário para cadastro'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.save),
              onPressed: () {
                final isValid = _form.currentState.validate();
                if (isValid) {
                  _form.currentState.save();
                  Provider.of<Users>(context, listen: false).put(
                    User(
                      id: _formData['id'],
                      name: _formData['name'],
                      email: _formData['email'],
                      avatarUrl: _formData['avatarUrl'],
                    ),
                  );

                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                child: Image.asset('images/cestas/2.png'),
                margin: const EdgeInsets.all(10.0),
                height: 215,
                decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(20)),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                    width: 1,
                  ),
                ),
                child: IconButton(
                    icon: Icon(Icons.camera_alt),
                    color: Colors.black,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TakePictureScreen(camera: null),
                        ),
                      );
                    }),
              ),
              Padding(
                  padding: EdgeInsets.all(15),
                  child: Form(
                    key: _form,
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          initialValue: _formData['name'],
                          decoration: InputDecoration(labelText: 'Nome'),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Nome inválido!';
                            if (value.trim().length < 3)
                              return 'Nome muito pequeno';
                            return null;
                          },
                          onSaved: (value) => _formData['name'] = value,
                        ),
                        TextFormField(
                          initialValue: _formData['sobrenome'],
                          decoration: InputDecoration(labelText: 'Sobrenome'),
                          onSaved: (value) => _formData['sobrenome'] = value,
                        ),
                        TextFormField(
                          initialValue: _formData['email'],
                          decoration: InputDecoration(labelText: 'E-mail'),
                          onSaved: (value) => _formData['email'] = value,
                        ),
                        TextFormField(
                          initialValue: _formData['avatarUrl'],
                          decoration:
                              InputDecoration(labelText: 'URL do Avatar'),
                          onSaved: (value) => _formData['avatarUrl'] = value,
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ));
  }
}
