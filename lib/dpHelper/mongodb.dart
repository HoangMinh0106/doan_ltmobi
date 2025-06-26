import 'dart:developer';

import 'package:doan_ltmobi/dpHelper/constant.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  static var db , userCollection;
  static var bannerCollection; //slider
  static var categoryCollection; //cate
  static var productCollection; //product
  //static var orderCollection;
  static connect() async{
    db = await Db.create(MONGO_CONN_URL);
    await db.open();
    inspect(db);
    userCollection = db.collection(USER_COLLECTION);
    bannerCollection = db.collection("banners"); //silder
    categoryCollection = db.collection("categories"); //cate
    productCollection = db.collection("products"); //product
    //orderCollection = db.collection("orders"); //order
  }
  static Future<List<Map<String, dynamic>>> getData() async {
    final arrData = await userCollection.find().toList();
    return arrData;
  }
}