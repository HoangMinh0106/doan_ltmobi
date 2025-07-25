import 'dart:developer';
import 'package:doan_ltmobi/dpHelper/constant.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:intl/intl.dart';
import 'package:random_string/random_string.dart';

class MongoDatabase {
  static late Db db;
  static late DbCollection userCollection;
  static late DbCollection bannerCollection;
  static late DbCollection categoryCollection;
  static late DbCollection productCollection;
  static late DbCollection cartCollection;
  static late DbCollection orderCollection;
  static late DbCollection voucherCollection;
  static late DbCollection reviewCollection;
  static late DbCollection customOrderCollection;
  static late DbCollection pointHistoryCollection;
  static late DbCollection notificationCollection;

  // --- THÊM MỚI CHO FLASH SALE ---
  static late DbCollection flashSaleCollection;

  static connect() async {
    db = await Db.create(MONGO_CONN_URL);
    await db.open();
    inspect(db);
    // *** BẮT ĐẦU SỬA LỖI ***
    userCollection = db.collection(USER_COLLECTION); // Sửa lại tên biến cho đúng
    // *** KẾT THÚC SỬA LỖI ***
    bannerCollection = db.collection("banners");
    categoryCollection = db.collection("categories");
    productCollection = db.collection("products");
    cartCollection = db.collection("carts");
    orderCollection = db.collection("orders");
    voucherCollection = db.collection("vouchers");
    reviewCollection = db.collection("reviews");
    customOrderCollection = db.collection("custom_orders");
    pointHistoryCollection = db.collection("point_history");
    notificationCollection = db.collection("notifications");

    // --- THÊM MỚI CHO FLASH SALE ---
    flashSaleCollection = db.collection("flash_sales");
  }
  
  //*** BẮT ĐẦU SỬA LỖI ***
  // HÀM MỚI: Vô hiệu hóa voucher sau khi sử dụng
  static Future<void> invalidateVoucher(ObjectId voucherId) async {
    try {
      // Tìm voucher bằng ID và cập nhật trường 'isActive' thành false
      await voucherCollection.updateOne(
        where.id(voucherId),
        modify.set('isActive', false),
      );
      print('Voucher $voucherId đã được vô hiệu hóa.');
    } catch (e) {
      print("Lỗi khi vô hiệu hóa voucher: $e");
    }
  }
  //*** KẾT THÚC SỬA LỖI ***

  // --- HÀM CẬP NHẬT CHO FLASH SALE ---
  static Future<Map<String, dynamic>?> getFlashSale() async {
    try {
      final sale = await flashSaleCollection.findOne(where.eq('_id', 'current_sale'));

      if (sale != null && sale['isActive'] == true) {
        // Lấy danh sách sản phẩm sale (mỗi phần tử là một Map {'productId': ..., 'salePrice': ...})
        final saleProductInfo = (sale['products'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        if (saleProductInfo.isNotEmpty) {
           // Lấy ra danh sách các ObjectId của sản phẩm
           final productIds = saleProductInfo.map((p) => p['productId'] as ObjectId).toList();

           // Tìm tất cả sản phẩm có trong danh sách ID
           final products = await productCollection.find(where.oneFrom('_id', productIds)).toList();

           // Gộp giá sale vào thông tin sản phẩm
           for (var product in products) {
             try {
                final saleInfo = saleProductInfo.firstWhere((p) => p['productId'] == product['_id']);
                product['salePrice'] = saleInfo['salePrice'];
             } catch(e) {
                // Nếu không tìm thấy thông tin sale, giá sale bằng giá gốc
                product['salePrice'] = product['price'];
             }
           }

           sale['products'] = products; // Gán lại danh sách sản phẩm đã có giá sale
        } else {
           sale['products'] = [];
        }
        return sale;
      }
      return null;
    } catch (e) {
      print("Lỗi khi lấy dữ liệu Flash Sale: $e");
      return null;
    }
  }

  // --- HÀM CHO CHỨC NĂNG THÔNG BÁO ---

  static Future<void> createNotification({
    required ObjectId userId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic> data = const {},
  }) async {
    try {
      await notificationCollection.insertOne({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'isRead': false,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      print("Lỗi khi tạo thông báo: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getNotificationsForUser(ObjectId userId) async {
    try {
      return await notificationCollection.find(
        where.eq('userId', userId).sortBy('createdAt', descending: true)
      ).toList();
    } catch (e) {
      print("Lỗi khi lấy thông báo: $e");
      return [];
    }
  }

  static Future<int> getUnreadNotificationCount(ObjectId userId) async {
    try {
      return await notificationCollection.count(
        where.eq('userId', userId).eq('isRead', false)
      );
    } catch (e) {
      print("Lỗi khi đếm thông báo chưa đọc: $e");
      return 0;
    }
  }

  static Future<void> markAsRead(ObjectId notificationId) async {
    try {
      await notificationCollection.updateOne(
        where.id(notificationId),
        modify.set('isRead', true)
      );
    } catch (e) {
      print("Lỗi khi đánh dấu đã đọc: $e");
    }
  }

  static Future<void> markAllAsRead(ObjectId userId) async {
    try {
      await notificationCollection.updateMany(
        where.eq('userId', userId).eq('isRead', false),
        modify.set('isRead', true)
      );
    } catch (e) {
      print("Lỗi khi đánh dấu tất cả đã đọc: $e");
    }
  }

  // --- CÁC HÀM CŨ (GIỮ NGUYÊN) ---

  static Future<void> insertUser(String email, String password) async {
    try {
      await userCollection.insertOne({
        'email': email,
        'password': password,
        'loyaltyPoints': 0,
      });
    } catch (e) {
      print("Lỗi khi thêm người dùng: $e");
    }
  }

  static Map<String, dynamic> getMembershipLevel(double totalSpending) {
    if (totalSpending >= 30000000) {
      return {'level': 'Kim Cương', 'discountPercent': 20};
    } else if (totalSpending >= 15000000) {
      return {'level': 'Bạch Kim', 'discountPercent': 15};
    } else if (totalSpending >= 5000000) {
      return {'level': 'Vàng', 'discountPercent': 10};
    } else if (totalSpending >= 3000000) {
      return {'level': 'Bạc', 'discountPercent': 5};
    } else {
      return {'level': 'Đồng', 'discountPercent': 0};
    }
  }

  static Future<double> getUserTotalSpending(ObjectId userId) async {
    try {
      final pipeline = [
        {
          '\$match': {'userId': userId, 'status': 'Delivered'}
        },
        {
          '\$group': {
            '_id': '\$userId',
            'totalSpending': {'\$sum': '\$totalPrice'}
          }
        }
      ];
      final result = await orderCollection.aggregateToStream(pipeline).toList();
      if (result.isNotEmpty && result.first['totalSpending'] != null) {
        return (result.first['totalSpending'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      print("Lỗi khi tính tổng chi tiêu: $e");
      return 0.0;
    }
  }

  static Future<void> addPointsForOrder(Map<String, dynamic> order) async {
    try {
      final userId = order['userId'] as ObjectId;
      final orderId = order['_id'] as ObjectId;
      final totalPrice = (order['totalPrice'] as num).toDouble();
      final pointsEarned = (totalPrice / 1000).floor();

      if (pointsEarned > 0) {
        await userCollection.updateOne(where.id(userId), modify.inc('loyaltyPoints', pointsEarned));
        await pointHistoryCollection.insertOne({
          'userId': userId,
          'orderId': orderId,
          'points': pointsEarned,
          'type': 'earned',
          // **SỬA LỖI**: Thay toHexString() bằng oid
          'description': 'Tích điểm từ đơn hàng #${orderId.oid.substring(0, 6)}',
          'date': DateTime.now(),
        });
      }
    } catch (e) {
      print("Lỗi khi cộng điểm thưởng: $e");
    }
  }

  // --- HÀM ĐƯỢC CẬP NHẬT CHO KHO VOUCHER ---
  static Future<Map<String, dynamic>> redeemPointsForVoucher({
    required ObjectId userId,
    required int pointsToRedeem,
    required double voucherValue,
  }) async {
    try {
      final user = await userCollection.findOne(where.id(userId));
      if (user == null || (user['loyaltyPoints'] ?? 0) < pointsToRedeem) {
        return {'success': false, 'message': 'Bạn không đủ điểm để đổi vật phẩm này.'};
      }

      await userCollection.updateOne(where.id(userId), modify.inc('loyaltyPoints', -pointsToRedeem));

      await pointHistoryCollection.insertOne({
        'userId': userId,
        'points': -pointsToRedeem,
        'type': 'spent',
        'description': 'Đổi $pointsToRedeem điểm nhận voucher ${NumberFormat('#,##0').format(voucherValue)} VNĐ',
        'date': DateTime.now(),
      });

      final voucherCode = 'REDEEM-${randomAlphaNumeric(8).toUpperCase()}';
      await voucherCollection.insertOne({
        'code': voucherCode,
        'discountValue': voucherValue,
        'discountType': 'fixed',
        'minPurchase': 0.0,
        'isActive': true,
        'description': 'Voucher đổi từ $pointsToRedeem điểm',
        'userId': userId, // <-- THÊM MỚI: Gán voucher cho người dùng
      });
      
      return {'success': true, 'message': 'Đổi điểm thành công! Mã voucher của bạn là: $voucherCode'};
    } catch (e) {
      print("Lỗi khi đổi điểm: $e");
      return {'success': false, 'message': 'Đã xảy ra lỗi, vui lòng thử lại.'};
    }
  }

  // --- HÀM MỚI CHO KHO VOUCHER ---
  static Future<List<Map<String, dynamic>>> getVouchersForUser(ObjectId userId) async {
    try {
      // Tìm tất cả voucher có userId trùng khớp và còn hoạt động
      return await voucherCollection.find(
        where.eq('userId', userId).eq('isActive', true)
      ).toList();
    } catch (e) {
      print("Lỗi khi lấy voucher của người dùng: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPointHistory(ObjectId userId) async {
    try {
      return await pointHistoryCollection.find(where.eq('userId', userId).sortBy('date', descending: true)).toList();
    } catch (e) {
      print("Lỗi khi lấy lịch sử điểm: $e");
      return [];
    }
  }

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
        modify.set('rating', double.parse(averageRating.toStringAsFixed(1))).set('reviewCount', totalReviews),
      );
    } catch (e) {
      print('Lỗi khi thêm đánh giá: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getReviewsForProduct(ObjectId productId) async {
    try {
      return await reviewCollection.find(where.eq('productId', productId).sortBy('createdAt', descending: true)).toList();
    } catch (e) {
      print('Lỗi khi lấy đánh giá sản phẩm: $e');
      return [];
    }
  }

  static Future<void> markProductAsReviewedInOrder(ObjectId orderId, ObjectId productId) async {
    try {
      await orderCollection.updateOne(where.id(orderId).eq('products.productId', productId), modify.set('products.\$.reviewed', true));
    } catch (e) {
      print("Lỗi khi đánh dấu đã đánh giá: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getData() async {
    return await userCollection.find().toList();
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
      return await cartCollection.findOne(where.eq('userId', userId));
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
      for (var item in List<Map<String, dynamic>>.from(cart['items'])) {
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
      await cartCollection.update(where.eq('userId', userId).eq('items.productId', productId), modify.set('items.\$.quantity', newQuantity));
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
      return await orderCollection.find(where.eq('userId', userId).sortBy('orderDate', descending: true)).toList();
    } catch(e) {
      print("Lỗi khi lấy danh sách đơn hàng của người dùng: $e");
      return [];
    }
  }

  static Future<void> addToFavorites(ObjectId userId, ObjectId productId) async {
    try {
      await userCollection.updateOne(where.id(userId), modify.addToSet('favorites', productId));
    } catch (e) {
      print('Lỗi khi thêm vào yêu thích: $e');
    }
  }

  static Future<void> removeFromFavorites(ObjectId userId, ObjectId productId) async {
    try {
      await userCollection.updateOne(where.id(userId), modify.pull('favorites', productId));
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
      if (favoriteIds.isEmpty) return [];
      return await productCollection.find(where.oneFrom('_id', favoriteIds)).toList();
    } catch (e) {
      print('Lỗi khi lấy chi tiết sản phẩm yêu thích: $e');
      return [];
    }
  }

  static Future<bool> changePassword(ObjectId userId, String oldPassword, String newPassword) async {
    try {
      final user = await userCollection.findOne(where.id(userId).eq('password', oldPassword));
      if (user == null) return false;
      await userCollection.updateOne(where.id(userId), modify.set('password', newPassword));
      return true;
    } catch (e) {
      print('Lỗi khi đổi mật khẩu: $e');
      return false;
    }
  }

  static Future<int> getTotalUsers() async {
    try {
      return await userCollection.count();
    } catch (e) {
      print('Lỗi khi lấy tổng số người dùng: $e');
      return 0;
    }
  }

  static Future<int> getTotalProducts() async {
    try {
      return await productCollection.count();
    } catch (e) {
      print('Lỗi khi lấy tổng số sản phẩm: $e');
      return 0;
    }
  }

  static Future<int> getTotalOrders() async {
    try {
      return await orderCollection.count();
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
      final Map<String, int> statusCounts = {'Pending': 0, 'Shipping': 0, 'Delivered': 0, 'Cancelled': 0};
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

  static Future<String> createCustomOrder(Map<String, dynamic> customOrderData) async {
    try {
      var result = await customOrderCollection.insertOne(customOrderData);
      return result.isSuccess ? "Yêu cầu của bạn đã được gửi đi thành công!" : "Gửi yêu cầu thất bại: ${result.errmsg}";
    } catch (e) {
      print('Lỗi khi tạo đơn hàng tùy chỉnh: $e');
      return "Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.";
    }
  }
}