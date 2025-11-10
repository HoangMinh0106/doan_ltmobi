import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:doan_ltmobi/page/custom_cake_order_screen.dart';
import 'package:doan_ltmobi/page/loyalty_program_screen.dart';
import 'package:doan_ltmobi/page/notifications_screen.dart';
import 'package:doan_ltmobi/page/product_detail_screen.dart';
import 'package:doan_ltmobi/page/promotion_detail_screen.dart';
import 'package:doan_ltmobi/page/promotions_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/vn_location_search.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:badges/badges.dart' as badges;
import 'package:doan_ltmobi/widgets/flash_sale_banner.dart';
// --- THÊM CÁC IMPORT MỚI ---
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HomePageBody extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;
  final String userName;
  final String? profileImageBase64;
  final Function(String) onSearchSubmitted;
  final Function(String?) onCategorySelected;
  final String initialAddress;
  final Function(String) onAddressChanged;

  const HomePageBody({
    super.key,
    required this.userDocument,
    required this.onProductAdded,
    required this.userName,
    this.profileImageBase64,
    required this.onSearchSubmitted,
    required this.onCategorySelected,
    required this.initialAddress,
    required this.onAddressChanged,
  });

  @override
  State<HomePageBody> createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _bannersFuture;
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  late Future<List<Map<String, dynamic>>> _bestSellersFuture;
  late Future<Map<String, dynamic>?> _flashSaleFuture;
  List<mongo.ObjectId> _favoriteProductIds = [];

  final PageController _pageController = PageController();
  int _currentBannerIndex = 0;
  Timer? _timer;
  late String _currentCity;
  int _unreadCount = 0;

  bool _isFetchingLocation = false;

  static const Color primaryColor = Color(0xFFE91E63);
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _currentCity = widget.initialAddress;
    _loadData();
    if (widget.initialAddress == 'Vui lòng chọn địa chỉ của bạn!') {
      _getCurrentLocationAndSetAddress();
    }
  }

  Future<void> _getCurrentLocationAndSetAddress() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Dịch vụ vị trí đã bị tắt.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Bạn đã từ chối quyền truy cập vị trí.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Quyền vị trí bị từ chối vĩnh viễn, không thể yêu cầu quyền!');
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        String fullAddress = [
          if (place.street != null && place.street!.isNotEmpty) place.street,
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) place.subAdministrativeArea,
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
        ].where((s) => s != null).join(', ');

        setState(() => _currentCity = fullAddress);
        widget.onAddressChanged(fullAddress);
      }
    } catch (e) {
      print('Lỗi khi tự động lấy vị trí: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _loadData() {
    setState(() {
      _bannersFuture = MongoDatabase.bannerCollection.find().toList();
      _categoriesFuture = MongoDatabase.categoryCollection.find().toList();
      _bestSellersFuture = _fetchBestSellers();
      _flashSaleFuture = MongoDatabase.getFlashSale();
      _bannersFuture.then((banners) {
        if (banners.isNotEmpty && mounted) _startAutoScroll(banners.length);
      });
      _fetchFavorites();
      _fetchUnreadCount();
    });
  }

  Future<void> _refreshData() async {
    _loadData();
  }

  Future<void> _fetchUnreadCount() async {
    if (!mounted) return;
    final count = await MongoDatabase.getUnreadNotificationCount(widget.userDocument['_id']);
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _fetchFavorites() async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    _favoriteProductIds = await MongoDatabase.getUserFavorites(userId);
    if (mounted) setState(() {});
  }

  void _toggleFavorite(mongo.ObjectId productId) {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    setState(() {
      if (_favoriteProductIds.contains(productId)) {
        _favoriteProductIds.remove(productId);
        MongoDatabase.removeFromFavorites(userId, productId);
      } else {
        _favoriteProductIds.add(productId);
        MongoDatabase.addToFavorites(userId, productId);
      }
    });
  }

  Future<List<Map<String, dynamic>>> _fetchBestSellers() async {
    try {
      return await MongoDatabase.productCollection.find(mongo.where.sortBy('reviewCount', descending: true).limit(10)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll(int pageCount) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      _currentBannerIndex = (_currentBannerIndex + 1) % pageCount;
      if (_pageController.hasClients) {
        _pageController.animateToPage(_currentBannerIndex, duration: const Duration(milliseconds: 400), curve: Curves.easeIn);
      }
    });
  }

  Future<void> _chooseLocation() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const VnLocationSearch()));
    if (result != null && mounted) {
      final address = result is String ? result : (result['full_address'] ?? '').toString();
      setState(() => _currentCity = address);
      widget.onAddressChanged(address);
    }
  }

  void _handleAddToCart(Map<String, dynamic> product) {
    MongoDatabase.addToCart(widget.userDocument['_id'], product);
    widget.onProductAdded();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã thêm '${product['name']}' vào giỏ hàng!"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildHeader()),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
                    children: <TextSpan>[
                      const TextSpan(text: 'Xin chào, '),
                      TextSpan(text: '${widget.userName}! 👋', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildSearchBar()),
              _buildFlashSaleSection(),
              _buildFeaturedActionsSection(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSectionHeader("Ưu đãi đặc biệt", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PromotionsScreen()))),
              ),
              const SizedBox(height: 12),
              _buildPromoSlider(),
              const SizedBox(height: 24),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildSectionHeader("Bán chạy nhất 🔥", () => widget.onCategorySelected(null))),
              const SizedBox(height: 12),
              _buildBestSellersSection(),
              const SizedBox(height: 24),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildSectionHeader("Danh mục", () => widget.onCategorySelected(null))),
              const SizedBox(height: 12),
              _buildCategorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashSaleSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _flashSaleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final saleData = snapshot.data!;
        final DateTime endTime = saleData['endTime'];
        final DateTime startTime = saleData['startTime'];
        final now = DateTime.now();

        if (now.isAfter(startTime) && now.isBefore(endTime)) {
          final products = (saleData['products'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

          if (products.isEmpty) return const SizedBox.shrink();

          return FlashSaleBanner(
            endTime: endTime,
            products: products,
            userDocument: widget.userDocument,
            onProductAdded: widget.onProductAdded,
            selectedAddress: _currentCity,
            favoriteProductIds: _favoriteProductIds,
            onFavoriteToggle: _toggleFavorite,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHeader() => Row(children: [
        _buildProfileAvatarWithBadge(),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _chooseLocation,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryColor.withAlpha(26), Colors.white], begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: primaryColor, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _isFetchingLocation
                        ? const Text('Đang tìm vị trí...', style: TextStyle(color: Colors.grey))
                        : Text(_currentCity, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: primaryColor),
                ],
              ),
            ),
          ),
        ),
      ]);

  Widget _buildProfileAvatarWithBadge() {
    ImageProvider image;
    if (widget.profileImageBase64 != null && widget.profileImageBase64!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(widget.profileImageBase64!);
        image = MemoryImage(bytes);
      } catch (_) {
        image = const AssetImage("assets/image/default-avatar.png");
      }
    } else {
      image = const AssetImage("assets/image/default-avatar.png");
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen(userId: widget.userDocument['_id'])));
        _fetchUnreadCount();
      },
      child: badges.Badge(
        position: badges.BadgePosition.topEnd(top: -5, end: -7),
        showBadge: _unreadCount > 0,
        badgeContent: Text(_unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
        badgeStyle: const badges.BadgeStyle(badgeColor: Colors.redAccent),
        child: CircleAvatar(radius: 28, backgroundImage: image),
      ),
    );
  }

  Widget _buildFeaturedActionsSection() {
    final int points = widget.userDocument['loyaltyPoints'] ?? 0;
    const Color primaryCardColor = Color(0xFFE91E63);
    final Color cardBackgroundColor = Colors.pink.shade50;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomCakeOrderScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 160,
                decoration: BoxDecoration(color: cardBackgroundColor, borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.cake_outlined, color: primaryCardColor, size: 42),
                    Text("Thiết kế bánh riêng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryCardColor)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoyaltyProgramScreen(userDocument: widget.userDocument))),
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 160,
                decoration: BoxDecoration(color: cardBackgroundColor, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.stars_rounded, color: primaryCardColor, size: 42),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(NumberFormat('#,##0').format(points), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: primaryCardColor)),
                        const Text("Điểm của bạn", style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() => TextField(
      controller: _searchController,
      onSubmitted: widget.onSearchSubmitted,
      decoration: InputDecoration(
        hintText: 'Tìm kiếm sản phẩm...',
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 22),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
      ),
    );

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          TextButton(onPressed: onViewAll, child: const Text("Xem tất cả", style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600))),
        ],
      );

  Widget _buildPromoSlider() => FutureBuilder<List<Map<String, dynamic>>>(
        future: _bannersFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 210, child: Center(child: CircularProgressIndicator(color: primaryColor)));
          }
          if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
          final banners = snap.data!;
          return Column(children: [
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: _pageController,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _currentBannerIndex = i),
                itemBuilder: (_, i) {
                  // **SỬA LỖI**: Lấy URL và kiểm tra
                  final imageUrl = banners[i]['imageUrl'] as String?;
                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PromotionDetailScreen(promotion: banners[i]))),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        // **SỬA LỖI**: Hiển thị ảnh hoặc placeholder
                        child: (imageUrl != null && imageUrl.isNotEmpty)
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSmoothIndicator(
                activeIndex: _currentBannerIndex,
                count: banners.length,
                effect: const ExpandingDotsEffect(dotWidth: 8, dotHeight: 8, activeDotColor: primaryColor, dotColor: Colors.grey)),
          ]);
        },
      );

  Widget _buildBestSellersSection() => FutureBuilder<List<Map<String, dynamic>>>(
        future: _bestSellersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 255, child: Center(child: CircularProgressIndicator(color: primaryColor)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }
          final products = snapshot.data!;
          return SizedBox(
            height: 255,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 500 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
                    );
                  },
                  child: _buildProductCard(products[index]),
                );
              },
            ));
        },
      );

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productId = product['_id'] as mongo.ObjectId;
    final isFavorite = _favoriteProductIds.contains(productId);
    // **SỬA LỖI**: Lấy URL
    final imageUrl = product['imageUrl'] as String?;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                product: product,
                userDocument: widget.userDocument,
                onProductAdded: widget.onProductAdded,
                selectedAddress: _currentCity,
                isFavorite: isFavorite,
                onFavoriteToggle: () => _toggleFavorite(productId),
              ),
            ));
        if (result == 'favorite_toggled') _fetchFavorites();
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 5, offset: const Offset(0, 5))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1.1,
                // **SỬA LỖI**: Hiển thị ảnh hoặc placeholder
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: Colors.grey)),
              ),
            ),
            Positioned(
                top: 4,
                right: 4,
                child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                        splashRadius: 20,
                        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.redAccent : Colors.white, size: 24),
                        onPressed: () => _toggleFavorite(productId)))),
          ])),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    height: 36,
                    child: Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis)),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(currencyFormatter.format(product['price']), style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      InkWell(
                          onTap: () => _handleAddToCart(product),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                            child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                          )),
                    ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCategorySection() => SizedBox(
        height: 110,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _categoriesFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }
            if (!snap.hasData || snap.data!.isEmpty) {
              return const Center(child: Text("Không thể tải danh mục."));
            }
            final cats = snap.data!;
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cats.length,
              itemBuilder: (_, i) => _buildCategoryItem(cats[i]),
            );
          },
        ),
      );

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    // **SỬA LỖI**: Lấy URL
    final imageUrl = category['imageUrl'] as String?;
    return GestureDetector(
      onTap: () => widget.onCategorySelected((category['_id'] as mongo.ObjectId).oid),
      child: Container(
        color: Colors.transparent,
        width: 90,
        margin: const EdgeInsets.only(right: 12),
        child: Column(children: [
          Container(
            height: 70,
            width: 70,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF0F0), shape: BoxShape.circle, border: Border.all(color: primaryColor.withAlpha(51))),
            // **SỬA LỖI**: Hiển thị ảnh hoặc placeholder
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.category, size: 35, color: primaryColor))
                : const Icon(Icons.category, size: 35, color: primaryColor),
          ),
          const SizedBox(height: 8),
          Text(category['name'] ?? 'N/A', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ]),
      ),
    );
  }
}