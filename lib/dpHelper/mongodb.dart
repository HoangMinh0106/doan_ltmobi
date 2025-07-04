// lib/dpHelper/mongodb.dart

import 'dart:developer';

import 'package:doan_ltmobi/dpHelper/constant.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  static var db, userCollection;
  static var bannerCollection;
  static var categoryCollection;
  static var productCollection;
  static var cartCollection;
  static var orderCollection;
  static var voucherCollection; // <-- Giữ lại dòng đã thêm

  static connect() async {
    db = await Db.create(MONGO_CONN_URL);
    await db.open();
    inspect(db);
    userCollection = db.collection(USER_COLLECTION);
    bannerCollection = db.collection("banners");
    categoryCollection = db.collection("categories");
    productCollection = db.collection("products");
    cartCollection = db.collection("carts");
    orderCollection = db.collection("orders");
    voucherCollection = db.collection("vouchers"); // <-- Giữ lại dòng đã thêm
  }

  static Future<void> insertUser(String email, String password) async {
    try {
      await userCollection.insertOne({'email': email, 'password': password});
    } catch (e) {
      print("Lỗi khi thêm người dùng: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getData() async {
    final arrData = await userCollection.find().toList();
    return arrData;
  }

  static Future<void> addToCart(ObjectId userId, Map<String, dynamic> product, {int quantity = 1}) async {
    try {
      final cart = await cartCollection.findOne(where.eq('userId', userId));
      final productId = product['_id'];
      if (cart == null) {
        await cartCollection.insertOne({
          'userId': userId,
          'items': [{'productId': productId, 'name': product['name'], 'price': product['price'], 'imageUrl': product['imageUrl'], 'description': product['description'], 'quantity': quantity}]
        });
      } else {
        var items = List<Map<String, dynamic>>.from(cart['items']);
        int existingItemIndex = items.indexWhere((item) => item['productId'] == productId);
        if (existingItemIndex != -1) {
          items[existingItemIndex]['quantity'] += quantity;
        } else {
          items.add({'productId': productId, 'name': product['name'], 'price': product['price'], 'imageUrl': product['imageUrl'], 'description': product['description'], 'quantity': quantity});
        }
        await cartCollection.update(where.eq('userId', userId), modify.set('items', items));
      }
    } catch (e) {
      print("Lỗi khi thêm vào giỏ hàng: $e");
    }
  }

  static Future<Map<String, dynamic>?> getCart(ObjectId userId) async {
    try {
      final cart = await cartCollection.findOne(where.eq('userId', userId));
      return cart;
    } catch (e) {
      print("Lỗi khi lấy thông tin giỏ hàng: $e");
      return null;
    }
  }
  
  static Future<int> getCartTotalQuantity(ObjectId userId) async {
    try {
      final cart = await cartCollection.findOne(where.eq('userId', userId));
      if (cart == null || cart['items'] == null) return 0;
      int totalQuantity = 0;
      final items = List<Map<String, dynamic>>.from(cart['items']);
      for (var item in items) {
        totalQuantity += (item['quantity'] as int?) ?? 0;
      }
      return totalQuantity;
    } catch (e) {
      print("Lỗi khi lấy tổng số lượng giỏ hàng: $e");
      return 0;
    }
  }

  static Future<void> updateItemQuantity(ObjectId userId, ObjectId productId, int newQuantity) async {
    try {
      await cartCollection.update(
        where.eq('userId', userId).eq('items.productId', productId),
        modify.set('items.\$.quantity', newQuantity)
      );
    } catch (e) {
      print("Lỗi khi cập nhật số lượng: $e");
    }
  }

  static Future<void> removeItemFromCart(ObjectId userId, ObjectId productId) async {
    try {
      await cartCollection.update(where.eq('userId', userId), modify.pull('items', {'productId': productId}));
    } catch (e) {
      print("Lỗi khi xóa sản phẩm khỏi giỏ hàng: $e");
    }
  }

  // SỬA LẠI HÀM NÀY VỀ TRẠNG THÁI GỐC CỦA BẠN
  static Future<void> createOrder(ObjectId userId, List<Map<String, dynamic>> cartItems, double totalPrice, String shippingAddress) async {
    try {
      final orderDocument = {
        '_id': ObjectId(),
        'userId': userId,
        'products': cartItems,
        'shippingAddress': shippingAddress,
        'totalPrice': totalPrice,
        'orderDate': DateTime.now(),
        'status': 'Pending', // Sử dụng 'Pending' thay vì 'Đang xử lý'
      };
      await orderCollection.insertOne(orderDocument);
    } catch (e) {
      print("Lỗi khi tạo đơn hàng: $e");
      rethrow;
    }
  }

  static Future<void> clearCart(ObjectId userId) async {
    try {
      await cartCollection.update(where.eq('userId', userId), modify.set('items', []));
    } catch (e) {
      print("Lỗi khi xóa giỏ hàng: $e");
    }
  }

  static Future<void> deleteOrder(ObjectId orderId) async {
    try {
      await orderCollection.remove(where.id(orderId));
    } catch (e) {
      print("Lỗi khi xóa đơn hàng: $e");
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getOrdersByUserId(ObjectId userId) async {
    try {
      final orders = await orderCollection.find(
        where.eq('userId', userId).sortBy('orderDate', descending: true)
      ).toList();
      return orders;
    } catch(e) {
      print("Lỗi khi lấy danh sách đơn hàng của người dùng: $e");
      return [];
    }
  }
}