// lib/dpHelper/mongodb.dart

import 'dart:developer';
import 'package:doan_ltmobi/dpHelper/constant.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  // Dùng 'late' để đảm bảo không cần thay đổi ở các file khác
  static late Db db;
  static late DbCollection userCollection;
  static late DbCollection bannerCollection;
  static late DbCollection categoryCollection;
  static late DbCollection productCollection;
  static late DbCollection cartCollection;
  static late DbCollection orderCollection;
  static late DbCollection voucherCollection;
  static late DbCollection reviewCollection;
  static late DbCollection customOrderCollection; // <-- Chức năng mới

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
    voucherCollection = db.collection("vouchers");
    reviewCollection = db.collection("reviews");
    customOrderCollection = db.collection("custom_orders"); // <-- Chức năng mới
  }

  // --- Các hàm hiện có ---

  static Future<void> createOrder(ObjectId userId, List<Map<String, dynamic>> cartItems, double totalPrice, String shippingAddress) async {
    try {
      final productsForOrder = cartItems.map((item) => {
        'productId': item['productId'],
        'name': item['name'],
        'price': item['price'],
        'imageUrl': item['imageUrl'],
        'quantity': item['quantity'],
        'reviewed': false,
      }).toList();

      final orderDocument = {
        '_id': ObjectId(),
        'userId': userId,
        'products': productsForOrder,
        'shippingAddress': shippingAddress,
        'totalPrice': totalPrice,
        'orderDate': DateTime.now(),
        'status': 'Pending',
      };
      await orderCollection.insertOne(orderDocument);
    } catch (e) {
      print("Lỗi khi tạo đơn hàng: $e");
      rethrow;
    }
  }

  static Future<void> addReview(Map<String, dynamic> reviewData) async {
    try {
      await reviewCollection.insertOne(reviewData);
      final productId = reviewData['productId'] as ObjectId;
      final reviews = await reviewCollection.find(where.eq('productId', productId)).toList();
      final totalReviews = reviews.length;
      double totalRating = 0;
      for (var review in reviews) {
        totalRating += (review['rating'] as num).toDouble();
      }
      final averageRating = totalReviews > 0 ? totalRating / totalReviews : 0;
      await productCollection.updateOne(
        where.id(productId),
        modify
          .set('rating', double.parse(averageRating.toStringAsFixed(1)))
          .set('reviewCount', totalReviews),
      );
    } catch (e) {
      print('Lỗi khi thêm đánh giá: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getReviewsForProduct(ObjectId productId) async {
    try {
      final reviews = await reviewCollection.find(
        where.eq('productId', productId).sortBy('createdAt', descending: true)
      ).toList();
      return reviews;
    } catch (e) {
      print('Lỗi khi lấy đánh giá sản phẩm: $e');
      return [];
    }
  }

  static Future<void> markProductAsReviewedInOrder(ObjectId orderId, ObjectId productId) async {
    try {
      await orderCollection.updateOne(
        where.id(orderId).eq('products.productId', productId),
        modify.set('products.\$.reviewed', true)
      );
    } catch (e) {
      print("Lỗi khi đánh dấu đã đánh giá: $e");
    }
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
        totalQuantity += (item['quantity'] as num?)?.toInt() ?? 0;
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

  static Future<void> addToFavorites(ObjectId userId, ObjectId productId) async {
    try {
      await userCollection.updateOne(
        where.id(userId),
        modify.addToSet('favorites', productId),
      );
    } catch (e) {
      print('Lỗi khi thêm vào yêu thích: $e');
    }
  }

  static Future<void> removeFromFavorites(ObjectId userId, ObjectId productId) async {
    try {
      await userCollection.updateOne(
        where.id(userId),
        modify.pull('favorites', productId),
      );
    } catch (e) {
      print('Lỗi khi xóa khỏi yêu thích: $e');
    }
  }

  static Future<List<ObjectId>> getUserFavorites(ObjectId userId) async {
    try {
      final user = await userCollection.findOne(where.id(userId));
      if (user != null && user['favorites'] != null) {
        return (user['favorites'] as List).map((id) => id as ObjectId).toList();
      }
      return [];
    } catch (e) {
      print('Lỗi khi lấy danh sách ID yêu thích: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getFavoriteProducts(ObjectId userId) async {
    try {
      final favoriteIds = await getUserFavorites(userId);
      if (favoriteIds.isEmpty) {
        return [];
      }
      final products = await productCollection.find(where.oneFrom('_id', favoriteIds)).toList();
      return products;
    } catch (e) {
      print('Lỗi khi lấy chi tiết sản phẩm yêu thích: $e');
      return [];
    }
  }

  static Future<bool> changePassword(ObjectId userId, String oldPassword, String newPassword) async {
    try {
      final user = await userCollection.findOne(
        where.id(userId).eq('password', oldPassword),
      );

      if (user == null) {
        return false;
      }

      await userCollection.updateOne(
        where.id(userId),
        modify.set('password', newPassword),
      );
      
      return true;
    } catch (e) {
      print('Lỗi khi đổi mật khẩu: $e');
      return false;
    }
  }
  
  // --- HÀM CHO TÍNH NĂNG THỐNG KÊ ---

  static Future<int> getTotalUsers() async {
    try {
      final count = await userCollection.count();
      return count;
    } catch (e) {
      print('Lỗi khi lấy tổng số người dùng: $e');
      return 0;
    }
  }

  static Future<int> getTotalProducts() async {
    try {
      final count = await productCollection.count();
      return count;
    } catch (e) {
      print('Lỗi khi lấy tổng số sản phẩm: $e');
      return 0;
    }
  }

  static Future<int> getTotalOrders() async {
    try {
      final count = await orderCollection.count();
      return count;
    } catch (e) {
      print('Lỗi khi lấy tổng số đơn hàng: $e');
      return 0;
    }
  }

  static Future<double> getTotalRevenue() async {
    try {
      final pipeline = [
        {'\$match': {'status': 'Delivered'}},
        {'\$group': {'_id': null, 'totalRevenue': {'\$sum': '\$totalPrice'}}}
      ];
      
      final result = await orderCollection.aggregateToStream(pipeline).toList();
      
      if (result.isNotEmpty && result.first['totalRevenue'] != null) {
        return (result.first['totalRevenue'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Lỗi khi tính tổng doanh thu: $e');
      return 0.0;
    }
  }

  static Future<Map<String, int>> getOrderStatusCounts() async {
    try {
      final pipeline = [
        {'\$group': {'_id': '\$status', 'count': {'\$sum': 1}}}
      ];
      
      final result = await orderCollection.aggregateToStream(pipeline).toList();
      
      final Map<String, int> statusCounts = {
        'Pending': 0,
        'Shipping': 0,
        'Delivered': 0,
        'Cancelled': 0,
      };

      for (var doc in result) {
        if (doc['_id'] != null && statusCounts.containsKey(doc['_id'])) {
          statusCounts[doc['_id']] = doc['count'];
        }
      }
      return statusCounts;

    } catch (e) {
      print('Lỗi khi lấy số lượng đơn hàng theo trạng thái: $e');
      return {};
    }
  }

  // --- HÀM MỚI CHO TÍNH NĂNG ĐẶT BÁNH TÙY CHỈNH ---

  /// Lưu yêu cầu đặt bánh tùy chỉnh vào database
  static Future<String> createCustomOrder(Map<String, dynamic> customOrderData) async {
    try {
      var result = await customOrderCollection.insertOne(customOrderData);
      if (result.isSuccess) {
        return "Yêu cầu của bạn đã được gửi đi thành công!";
      } else {
        return "Gửi yêu cầu thất bại: ${result.errmsg}";
      }
    } catch (e) {
      print('Lỗi khi tạo đơn hàng tùy chỉnh: $e');
      return "Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.";
    }
  }
}