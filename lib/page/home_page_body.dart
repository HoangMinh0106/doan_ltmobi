// lib/page/home_page_body.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:doan_ltmobi/page/product_detail_screen.dart';
import 'package:doan_ltmobi/page/promotion_detail_screen.dart';
import 'package:doan_ltmobi/page/promotions_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/vn_location_search.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

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
  List<mongo.ObjectId> _favoriteProductIds = [];

  final PageController _pageController = PageController();
  int _currentBannerIndex = 0;
  Timer? _timer;
  late String _currentCity;

  static const Color primaryColor = Color(0xFFE57373);
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _currentCity = widget.initialAddress;
    _bannersFuture = MongoDatabase.bannerCollection.find().toList();
    _categoriesFuture = MongoDatabase.categoryCollection.find().toList();
    _bestSellersFuture = _fetchBestSellers();
    _bannersFuture.then((banners) {
      if (banners.isNotEmpty) _startAutoScroll(banners.length);
    });
    _fetchFavorites();
  }
  
  Future<void> _fetchFavorites() async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    _favoriteProductIds = await MongoDatabase.getUserFavorites(userId);
    if(mounted) setState(() {});
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
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
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
        onRefresh: () async {
          setState(() {
            _bestSellersFuture = _fetchBestSellers();
          });
          await _fetchFavorites();
        },
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildHeader()),
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Xin chào,", style: TextStyle(fontSize: 22, color: Colors.grey.shade600)),
                Text("${widget.userName}!", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              ])),
              const SizedBox(height: 24),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildSearchBar()),
              const SizedBox(height: 24),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildSectionHeader("Ưu đãi đặc biệt", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PromotionsScreen())))),
              const SizedBox(height: 12),
              _buildPromoSlider(),
              const SizedBox(height: 24),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildSectionHeader("Bán chạy nhất", () => widget.onCategorySelected(null))),
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

  Widget _buildHeader() => Row(children: [_buildProfileAvatar(), const SizedBox(width: 12), Expanded(child: InkWell(
    onTap: _chooseLocation,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.location_on, color: primaryColor, size: 20),
        const SizedBox(width: 6),
        Expanded(child: Text(_currentCity, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1)),
        const SizedBox(width: 4), 
        const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: primaryColor),
      ]),
    ),
  ))]);
  
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
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      TextButton(onPressed: onViewAll, child: const Text("Xem tất cả", style: TextStyle(color: primaryColor))),
    ],
  );

  Widget _buildPromoSlider() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _bannersFuture,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 210, child: Center(child: CircularProgressIndicator(color: primaryColor)));
      if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
      final banners = snap.data!;
      return Column(children: [
        SizedBox(height: 210, child: PageView.builder(
          controller: _pageController,
          itemCount: banners.length,
          onPageChanged: (i) => setState(() => _currentBannerIndex = i),
          itemBuilder: (_, i) => InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PromotionDetailScreen(promotion: banners[i]))),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(banners[i]['imageUrl'] ?? '', fit: BoxFit.cover)),
            ),
          ),
        )),
        const SizedBox(height: 12),
        AnimatedSmoothIndicator(activeIndex: _currentBannerIndex, count: banners.length, effect: const WormEffect(dotWidth: 8, dotHeight: 8, activeDotColor: primaryColor, dotColor: Colors.grey)),
      ]);
    },
  );

  Widget _buildBestSellersSection() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _bestSellersFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 255, child: Center(child: CircularProgressIndicator(color: primaryColor)));
      if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
      final products = snapshot.data!;
      return SizedBox(height: 255, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) => _buildProductCard(products[index]),
      ));
    },
  );

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productId = product['_id'] as mongo.ObjectId;
    final isFavorite = _favoriteProductIds.contains(productId);
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context, MaterialPageRoute(
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
        width: 160, margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 5, offset: const Offset(0, 5))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: AspectRatio(aspectRatio: 1.1, child: Image.network(product['imageUrl'] ?? '', fit: BoxFit.cover))),
            Positioned(top: 4, right: 4, child: Material(color: Colors.transparent, child: IconButton(
              splashRadius: 20,
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.redAccent : Colors.white, size: 24),
              onPressed: () => _toggleFavorite(productId),
            ))),
          ])),
          Padding(padding: const EdgeInsets.all(10.0), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 36, child: Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(currencyFormatter.format(product['price']), style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                InkWell(onTap: () => _handleAddToCart(product), borderRadius: BorderRadius.circular(20), child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                  child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                )),
              ]),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildCategorySection() => SizedBox(
    height: 110,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _categoriesFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryColor));
        if (!snap.hasData || snap.data!.isEmpty) return const Center(child: Text("Không thể tải danh mục."));
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

  Widget _buildCategoryItem(Map<String, dynamic> category) => GestureDetector(
    onTap: () => widget.onCategorySelected((category['_id'] as mongo.ObjectId).oid),
    child: Container(
      color: Colors.transparent,
      width: 90, margin: const EdgeInsets.only(right: 12),
      child: Column(children: [
        Container(
          height: 70, width: 70, padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFFFFF0F0), shape: BoxShape.circle),
          child: (category['imageUrl'] != null && category['imageUrl'].isNotEmpty)
              ? Image.network(category['imageUrl'], fit: BoxFit.contain)
              : const Icon(Icons.category, size: 35, color: primaryColor),
        ),
        const SizedBox(height: 8),
        Text(category['name'] ?? 'N/A', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ]),
    ),
  );

  Widget _buildProfileAvatar() {
    if (widget.profileImageBase64 != null && widget.profileImageBase64!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(widget.profileImageBase64!);
        return CircleAvatar(radius: 24, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    return const CircleAvatar(radius: 24, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white));
  }
}