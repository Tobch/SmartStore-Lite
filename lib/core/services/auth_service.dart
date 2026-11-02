import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../data/models/user_model.dart';
import '../database/db_helper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> _saveUserToSQLite(UserModel user) async {
    try {
      final db = await DBHelper.instance.database;
      await db.insert(
        'users',
        user.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<UserModel?> login(String email, String password) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    final user = await getUserData(credential.user!.uid);
    if (user != null) {
      await _saveUserToSQLite(user);
    }
    return user;
  }

  Future<UserModel?> register(String name, String email, String password, String role) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    
    UserModel newUser = UserModel(
      id: credential.user!.uid,
      name: name,
      email: email,
      role: role,
    );

    await _firestore.collection('users').doc(newUser.id).set(newUser.toMap());
    await _saveUserToSQLite(newUser);
    return newUser;
  }

  Future<UserModel?> getUserData(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final user = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      await _saveUserToSQLite(user);
      return user;
    }
    return null;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
