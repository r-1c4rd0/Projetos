import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> uploadLogo(String academyId, File file) async {
  final ref = FirebaseStorage.instance
      .ref()
      .child('academies')
      .child(academyId)
      .child('logo.png');

  await ref.putFile(file);
  return await ref.getDownloadURL();
}

Future<void> saveAcademyLogoUrl(String academyId, String url) async {
  await FirebaseFirestore.instance
      .collection('academies')
      .doc(academyId)
      .set({'logoUrl': url}, SetOptions(merge: true));
}
