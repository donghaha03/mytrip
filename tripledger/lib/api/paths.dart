import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_api.dart';

// Firestore 경로 모음
//   users/{uid}/trips/{tripId}
//  users/{uid}/trips/{tripId}/expenses/{expenseId}
class Paths {
  Paths._();

  static CollectionReference<Map<String, dynamic>> get trips =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(AuthApi.uid)
          .collection('trips');

  static CollectionReference<Map<String, dynamic>> expenses(String tripId) =>
      trips.doc(tripId).collection('expenses');
}
