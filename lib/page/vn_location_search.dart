import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VnLocationSearch extends StatefulWidget {
  const VnLocationSearch({super.key});

  @override
  State<VnLocationSearch> createState() => _VnLocationSearchState();
}

class _VnLocationSearchState extends State<VnLocationSearch> {
  // --- UI Constants ---
  static const Color primaryColor = Color(0xFFE57373);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;
  String _message = 'Nhập địa điểm bạn muốn tìm kiếm.';

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Lắng nghe sự thay đổi trong thanh tìm kiếm để thực hiện tìm kiếm
    _searchController.addListener(() {
      _search(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Thực hiện cuộc gọi API để tìm kiếm địa điểm với cơ chế debouncing.
  Future<void> _search(String query) async {
    // Hủy timer cũ nếu người dùng tiếp tục gõ để tránh gọi API không cần thiết
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Đặt một timer mới. API chỉ được gọi sau 500ms người dùng ngừng gõ.
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      if (query.isEmpty) {
        setState(() {
          _results = [];
          _isLoading = false;
          _message = 'Nhập địa điểm bạn muốn tìm kiếm.';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _message = '';
      });

      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=$query&format=jsonv2&limit=20&countrycodes=vn&addressdetails=1',
        );
        final res = await http.get(
          uri,
          headers: {'User-Agent': 'doan_ltmobi/1.0 (yourmail@example.com)'},
        );

        if (!mounted) return;

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          setState(() {
            _results = data;
            if (data.isEmpty) {
              _message = 'Không tìm thấy kết quả nào.';
            }
          });
        } else {
          setState(() {
            _results = [];
            _message = 'Đã xảy ra lỗi. Vui lòng thử lại.';
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _results = [];
          _message = 'Lỗi kết nối. Vui lòng kiểm tra mạng.';
        });
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Chọn địa điểm",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // --- Thanh tìm kiếm ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              // Bỏ onChanged ở đây vì đã dùng addListener trong initState
              decoration: InputDecoration(
                hintText: 'Nhập tỉnh/thành phố, quận/huyện...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
          ),
          // --- Nội dung chính ---
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }

  /// Xây dựng nội dung chính dựa trên trạng thái: đang tải, có thông báo hoặc hiển thị kết quả.
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_message.isNotEmpty) {
      return Center(
        child: Text(
          _message,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final result = _results[i];
        final displayName = result['display_name'] as String? ?? 'N/A';

        // Sử dụng cấu trúc Row và Expanded để đảm bảo không bị tràn giao diện
        return InkWell(
          onTap: () => Navigator.pop(context, displayName),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon vị trí
                const Padding(
                  padding: EdgeInsets.only(top: 2.0),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16.0),
                // Địa chỉ (nằm trong Expanded để tự động co giãn và xuống dòng)
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(fontSize: 15.0, height: 1.4),
                    maxLines: 3, // Cho phép hiển thị tối đa 3 dòng
                    overflow: TextOverflow.ellipsis, // Hiển thị "..." nếu quá dài
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}