import 'dart:async'; 
import 'dart:convert';
import 'dart:typed_data';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// WIDGET CHO NỘI DUNG TRANG CHỦ (TAB 0)
class HomePageBody extends StatefulWidget {
  final String userName;
  final String? profileImageBase64;

  const HomePageBody({Key? key, required this.userName, this.profileImageBase64})
      : super(key: key);

  @override
  State<HomePageBody> createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> {
  late Future<List<Map<String, dynamic>>> _bannersFuture;
  int _currentBannerIndex = 0;
  final PageController _pageController = PageController(); 
  Timer? _timer; 

  @override
  void initState() {
    super.initState();
    _bannersFuture = _fetchBanners();
    
    _bannersFuture.then((banners) {
      if (banners.isNotEmpty) {
        _startAutoScroll(banners.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); 
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll(int pageCount) {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentBannerIndex < pageCount - 1) {
        _currentBannerIndex++;
      } else {
        _currentBannerIndex = 0;
      }
      if(_pageController.hasClients){
        _pageController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeIn,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> _fetchBanners() async {
    try {
      final banners = await MongoDatabase.bannerCollection.find().toList();
      return banners;
    } catch (e) {
      print("Lỗi khi lấy dữ liệu banner: $e");
      return [];
    }
  }

  Widget _buildProfileAvatar() {
    if (widget.profileImageBase64 != null && widget.profileImageBase64!.isNotEmpty) {
      try {
        final Uint8List imageBytes = base64Decode(widget.profileImageBase64!);
        return CircleAvatar(radius: 24, backgroundImage: MemoryImage(imageBytes));
      } catch (e) {
        return const CircleAvatar(radius: 24, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white));
      }
    }
    return const CircleAvatar(radius: 24, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white));
  }
  
  Widget _buildPromoSlider() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 204,
            child: Center(child: CircularProgressIndicator(color: const Color(0xFFE57373))),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 204,
            child: Center(child: Text("Không thể tải ưu đãi.")),
          );
        }
        
        final banners = snapshot.data!;
        return Column(
          children: [
            SizedBox(
              height: 204,
              child: PageView.builder(
                controller: _pageController,
                itemCount: banners.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentBannerIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  final imageUrl = banner['imageUrl'] ?? '';
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        // *** BẮT ĐẦU THAY ĐỔI ***
                        // Dùng 'cover' để ảnh lấp đầy khung và khớp viền
                        fit: BoxFit.cover, 
                        // *** KẾT THÚC THAY ĐỔI ***
                        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFFE57373),
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                          print("Lỗi tải ảnh banner: $imageUrl -> $exception");
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey,
                                size: 50,
                              ),
                            ),
                          );
                        },
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
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: Color(0xFFE57373),
                dotColor: Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            children: [
              _buildProfileAvatar(),
              const Spacer(),
              const Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFFE57373)),
                  SizedBox(width: 4),
                  Text("Hồ Chí Minh", style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("Xin chào,", style: TextStyle(fontSize: 22, color: Colors.grey.shade600)),
          Text("${widget.userName}!", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Ưu đãi đặc biệt", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: const Text("Xem tất cả", style: TextStyle(color: Color(0xFFE57373)))),
            ],
          ),
          const SizedBox(height: 12),
          _buildPromoSlider(),
        ],
      ),
    );
  }
}
