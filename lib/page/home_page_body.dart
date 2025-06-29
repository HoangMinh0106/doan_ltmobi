// lib/page/home_page_body.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:doan_ltmobi/page/promotion_detail_screen.dart';
import 'package:doan_ltmobi/page/promotions_screen.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/vn_location_search.dart';

class HomePageBody extends StatefulWidget {
  final String userName;
  final String? profileImageBase64;
  final Function(String) onSearchSubmitted;
  final Function(String?) onCategorySelected; // THÊM MỚI: Khai báo tham số
  final String initialAddress;
  final Function(String) onAddressChanged;

  const HomePageBody({
    Key? key,
    required this.userName,
    this.profileImageBase64,
    required this.onSearchSubmitted,
    required this.onCategorySelected, // THÊM MỚI: Thêm vào constructor
    required this.initialAddress,
    required this.onAddressChanged,
  }) : super(key: key);

  @override
  State<HomePageBody> createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _bannersFuture;
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  final PageController _pageController = PageController();
  int _currentBannerIndex = 0;
  Timer? _timer;
  late String _currentCity;

  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _currentCity = widget.initialAddress;
    _bannersFuture = _fetchBanners();
    _categoriesFuture = _fetchCategories();
    _bannersFuture.then((banners) {
      if (banners.isNotEmpty) _startAutoScroll(banners.length);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchBanners() async {
    try {
      return await MongoDatabase.bannerCollection.find().toList();
    } catch (e) {
      print("Lỗi khi lấy dữ liệu banner: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    try {
      return await MongoDatabase.categoryCollection.find().toList();
    } catch (e) {
      print("Lỗi khi lấy dữ liệu danh mục: $e");
      return [];
    }
  }

  void _startAutoScroll(int pageCount) {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      _currentBannerIndex = (_currentBannerIndex + 1) % pageCount;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeIn,
        );
      }
    });
  }
  
  Future<void> _chooseLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VnLocationSearch()),
    );
    if (result != null && mounted) {
      setState(() => _currentCity = result as String);
      widget.onAddressChanged(_currentCity);
    }
  }

  // SỬA ĐỔI: Thêm sự kiện onTap để gọi callback
  Widget _buildCategoryItem(Map<String, dynamic> category) => GestureDetector(
        onTap: () {
          final categoryId = category['_id']?.toHexString();
          if (categoryId != null) {
            widget.onCategorySelected(categoryId);
          }
        },
        child: Container(
          color: Colors.transparent, // for hit testing
          width: 90,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              Container(
                height: 70,
                width: 70,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F0), shape: BoxShape.circle),
                child: (category['imageUrl'] != null && category['imageUrl'].isNotEmpty)
                    ? Image.network(category['imageUrl'], fit: BoxFit.contain)
                    : const Icon(Icons.category, size: 35, color: primaryColor),
              ),
              const SizedBox(height: 8),
              Text(category['name'] ?? 'N/A',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))
            ],
          ),
        ),
      );

  Widget _buildCategorySection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Danh mục",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              // SỬA ĐỔI: Nút "Xem tất cả" sẽ gọi callback với giá trị null (để hiển thị tất cả)
              TextButton(
                  onPressed: () => widget.onCategorySelected(null),
                  child: const Text("Xem tất cả",
                      style: TextStyle(color: primaryColor))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _categoriesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryColor));
                if (snap.hasError || !snap.hasData || snap.data!.isEmpty) return const Center(child: Text("Không thể tải danh mục."));
                final cats = snap.data!;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  itemBuilder: (_, i) => _buildCategoryItem(cats[i]),
                );
              },
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            children: [
              _buildProfileAvatar(),
              const SizedBox(width: 12),
              Flexible(
                child: InkWell(
                  onTap: _chooseLocation,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: primaryColor, size: 20),
                        const SizedBox(width: 6),
                        Flexible(child: Text(_currentCity, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        const SizedBox(width: 4), 
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("Xin chào,", style: TextStyle(fontSize: 22, color: Colors.grey.shade600)),
          Text("${widget.userName}!", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            onSubmitted: widget.onSearchSubmitted,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm sản phẩm, dịch vụ...',
              prefixIcon: const Icon(Icons.search, color: secondaryTextColor),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Ưu đãi đặc biệt", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PromotionsScreen()),
                  );
                },
                child: const Text("Xem tất cả", style: TextStyle(color: primaryColor))
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPromoSlider(),
          const SizedBox(height: 24),
          _buildCategorySection(),
        ],
      ),
    );
  }
  
  Widget _buildProfileAvatar() {
    if (widget.profileImageBase64 != null && widget.profileImageBase64!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(widget.profileImageBase64!);
        return CircleAvatar(radius: 24, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    return const CircleAvatar(radius: 24, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white));
  }
  
  Widget _buildPromoSlider() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bannersFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 204, child: Center(child: CircularProgressIndicator(color: primaryColor)));
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return const SizedBox(height: 204, child: Center(child: Text("Không thể tải ưu đãi.")));
        }
        final banners = snap.data!;
        return Column(
          children: [
            SizedBox(
              height: 204,
              child: PageView.builder(
                controller: _pageController,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _currentBannerIndex = i),
                itemBuilder: (_, i) {
                  final banner = banners[i];
                  final url = banner['imageUrl'] ?? '';
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PromotionDetailScreen(promotion: banner),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(url, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 50))),
                          loadingBuilder: (_, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(color: primaryColor, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
                        ),
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
              effect: const WormEffect(dotWidth: 8, dotHeight: 8, activeDotColor: primaryColor, dotColor: Colors.grey),
            ),
          ],
        );
      },
    );
  }
}