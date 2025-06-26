import 'dart:developer';

import 'package:doan_ltmobi/dpHelper/constant.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  static var db , userCollection;
  static var bannerCollection; //slider

  static connect() async{
    db = await Db.create(MONGO_CONN_URL);
    await db.open();
    inspect(db);
    userCollection = db.collection(USER_COLLECTION);
    bannerCollection = db.collection("banners"); //silder
    
  }
  static Future<List<Map<String, dynamic>>> getData() async {
    final arrData = await userCollection.find().toList();
    return arrData;
  }
}