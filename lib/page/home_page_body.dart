import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/vn_location_search.dart';

class HomePageBody extends StatefulWidget {
  final String userName;
  final String? profileImageBase64;

  const HomePageBody({
    Key? key,
    required this.userName,
    this.profileImageBase64,
  }) : super(key: key);

  @override
  State<HomePageBody> createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> {
  // ---- DATA ----
  late Future<List<Map<String, dynamic>>> _bannersFuture;
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  // ---- SLIDER ----
  final PageController _pageController = PageController();
  int _currentBannerIndex = 0;
  Timer? _timer;

  // ---- CITY ----
  String _currentCity = 'Vui lòng chọn địa chỉ của bạn';

  // --- UI CONSTANTS ---
  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _bannersFuture = _fetchBanners();
    _categoriesFuture = _fetchCategories();

    _bannersFuture.then((banners) {
      if (banners.isNotEmpty) _startAutoScroll(banners.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /* ============== API / DB ============== */
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

  /* ============== SLIDER auto scroll ============== */
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

  /* ============== CHỌN THÀNH PHỐ ============== */
  Future<void> _chooseLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VnLocationSearch()),
    );
    if (result != null && mounted) {
      setState(() => _currentCity = result as String);
    }
  }

  /* ============== WIDGETS ============== */
  Widget _buildProfileAvatar() {
    if (widget.profileImageBase64 != null &&
        widget.profileImageBase64!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(widget.profileImageBase64!);
        return CircleAvatar(radius: 24, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    return const CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, color: Colors.white),
    );
  }

  Widget _buildPromoSlider() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bannersFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 204,
            child: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return const SizedBox(
            height: 204,
            child: Center(child: Text("Không thể tải ưu đãi.")),
          );
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
                  final url = banners[i]['imageUrl'] ?? '';
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.grey, size: 50),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : Center(
                                    child: CircularProgressIndicator(
                                      color: primaryColor,
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                    ),
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
              effect: const WormEffect(
                dotWidth: 8,
                dotHeight: 8,
                activeDotColor: primaryColor,
                dotColor: Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryItem(String name, String? img) => Container(
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
              child: img != null && img.isNotEmpty
                  ? Image.network(img, fit: BoxFit.contain)
                  : const Icon(Icons.category,
                      size: 35, color: primaryColor),
            ),
            const SizedBox(height: 8),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))
          ],
        ),
      );

  Widget _buildCategorySection() => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Danh mục",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, "/category"),
                child: const Text("Xem tất cả",
                    style: TextStyle(color: primaryColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _categoriesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: primaryColor));
                }
                if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
                  return const Center(child: Text("Không thể tải danh mục."));
                }

                final cats = snap.data!;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  itemBuilder: (_, i) =>
                      _buildCategoryItem(cats[i]['name'] ?? 'N/A', cats[i]['imageUrl']),
                );
              },
            ),
          ),
        ],
      );

  /* ============== BUILD ============== */
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // -------- Header Avatar + City (Đã sửa để co giãn) ----------
          Row(
            children: [
              _buildProfileAvatar(),
              const SizedBox(width: 12),
              // Dùng Flexible thay cho Expanded
              // Flexible cho phép widget con có kích thước nhỏ hơn không gian tối đa
              Flexible(
                child: InkWell(
                  onTap: _chooseLocation,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      // Thêm mainAxisSize.min
                      // Thuộc tính này bảo Row hãy co lại để vừa khít với nội dung bên trong
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: primaryColor, size: 20),
                        const SizedBox(width: 6),
                        // Vẫn cần Flexible ở đây để xử lý text dài
                        Flexible(
                          child: Text(
                            _currentCity,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        // Thêm khoảng trống nhỏ để không bị sát vào icon
                        const SizedBox(width: 4), 
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text("Xin chào,",
              style: TextStyle(fontSize: 22, color: Colors.grey.shade600)),
          Text("${widget.userName}!",
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),

          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm sản phẩm, dịch vụ...',
              prefixIcon: const Icon(Icons.search, color: secondaryTextColor),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: const BorderSide(color: primaryColor, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Ưu đãi đặc biệt",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {},
                child: const Text("Xem tất cả",
                    style: TextStyle(color: primaryColor)),
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
}