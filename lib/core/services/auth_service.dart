import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserModel?> login(String email, String password) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return await getUserData(credential.user!.uid);
  }

  Future<UserModel?> register(String name, String email, String password, String role) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    
    UserModel newUser = UserModel(
      id: credential.user!.uid,
      name: name,
      email: email,
      role: role, // Assigned based on UI selection (Manager/Staff)
    );

    await _firestore.collection('users').doc(newUser.id).set(newUser.toMap());
    return newUser;
  }

  Future<UserModel?> getUserData(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}