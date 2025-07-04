// lib/page/product_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class ProductScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;
  final VoidCallback onCartIconTapped;
  final String selectedAddress;

  const ProductScreen({
    super.key,
    required this.userDocument,
    required this.onProductAdded,
    required this.onCartIconTapped,
    required this.selectedAddress,
  });

  @override
  ProductScreenState createState() => ProductScreenState();
}

class ProductScreenState extends State<ProductScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];

  String? _selectedCategoryId;
  RangeValues? _selectedPriceRange;
  double _maxPrice = 1000000;

  bool _isLoading = true;
  String _errorMessage = '';
  int _cartTotalQuantity = 0;

  static const Color primaryColor = Color(0xFFE57373);
  static const Color scaffoldBackgroundColor = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF212529);
  static final Color secondaryTextColor = Colors.grey.shade600;

  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
      _applyFilters();
    });
    _fetchData();
    updateCartBadge();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  void filterByCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _applyFilters();
    });
  }

  Future<void> updateCartBadge() async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final count = await MongoDatabase.getCartTotalQuantity(userId);
    if (mounted) {
      setState(() {
        _cartTotalQuantity = count;
      });
    }
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        MongoDatabase.productCollection.find().toList(),
        MongoDatabase.categoryCollection.find().toList(),
      ]);
      final products = results[0];
      final categories = results[1];

      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _categories = categories;
          _isLoading = false;
          if (_allProducts.isNotEmpty) {
            _maxPrice = _allProducts
                .map((p) => (p['price'] as num).toDouble())
                .reduce(max);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Không thể tải dữ liệu. Vui lòng thử lại.";
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final productName = (product['name'] as String? ?? '').toLowerCase();
        final productPrice = (product['price'] as num).toDouble();
        final productCategoryId = product['categoryId'];
        final bool searchMatch = productName.contains(query);
        final bool categoryMatch;
        if (_selectedCategoryId == null) {
          categoryMatch = true;
        } else if (productCategoryId is mongo.ObjectId) {
          categoryMatch = productCategoryId.oid == _selectedCategoryId;
        } else {
          categoryMatch = productCategoryId.toString() == _selectedCategoryId;
        }
        final bool priceMatch = _selectedPriceRange == null ||
            (productPrice >= _selectedPriceRange!.start &&
                productPrice <= _selectedPriceRange!.end);
        return searchMatch && categoryMatch && priceMatch;
      }).toList();
    });
  }

  Future<void> _showPriceFilterDialog() async {
    final newRange = await showDialog<RangeValues>(
      context: context,
      builder: (context) {
        return PriceRangeDialog(
          maxPrice: _maxPrice,
          initialRange: _selectedPriceRange,
        );
      },
    );
    if (mounted) {
      setState(() {
        _selectedPriceRange = newRange;
      });
      _applyFilters();
    }
  }

  void _handleAddToCart(Map<String, dynamic> product) async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final productName = product['name'] ?? 'Sản phẩm';
    await MongoDatabase.addToCart(userId, product);
    await updateCartBadge();
    widget.onProductAdded();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Đã thêm '$productName' vào giỏ hàng!"),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ));
    }
  }

  void performSearch(String query) {
    _searchController.text = query;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Sản phẩm", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [_buildCartIcon()],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFilterBar(),
          _buildCategoryFilters(),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Kết quả tìm kiếm cho: '),
                    TextSpan(
                      text: '"${_searchController.text}"',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0), 
                  borderSide: BorderSide(color: Colors.grey.shade200)
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0), 
                  borderSide: const BorderSide(color: primaryColor, width: 1.5)
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: _selectedPriceRange != null ? primaryColor : secondaryTextColor,
            ),
            onPressed: _showPriceFilterDialog,
            tooltip: 'Lọc theo giá',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    if (_isLoading) return const SizedBox(height: 50);
    if (_categories.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: const Text('Tất cả'),
                selected: _selectedCategoryId == null,
                onSelected: (selected) => filterByCategory(null),
                selectedColor: primaryColor,
                labelStyle: TextStyle(color: _selectedCategoryId == null ? Colors.white : textColor, fontWeight: FontWeight.bold),
                backgroundColor: Colors.white,
                shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
              ),
            );
          }
          final category = _categories[index - 1];
          final categoryId = category['_id'] is mongo.ObjectId ? (category['_id'] as mongo.ObjectId).oid : category['_id'].toString();
          final isSelected = _selectedCategoryId == categoryId;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(category['name'] ?? 'N/A'),
              selected: isSelected,
              onSelected: (selected) => filterByCategory(categoryId),
              selectedColor: primaryColor,
              labelStyle: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold),
              backgroundColor: Colors.white,
              shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartIcon() => Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Stack(alignment: Alignment.center, children: [
        IconButton(
          icon: Icon(Icons.shopping_cart_outlined, color: Colors.grey.shade700, size: 28),
          onPressed: widget.onCartIconTapped,
        ),
        if (_cartTotalQuantity > 0)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$_cartTotalQuantity',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ]));

  Widget _buildBodyContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: primaryColor));
    if (_errorMessage.isNotEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: secondaryTextColor, fontSize: 16))));
    if (_filteredProducts.isEmpty) return Center(child: Text(_searchController.text.isNotEmpty || _selectedCategoryId != null || _selectedPriceRange != null ? "Không tìm thấy sản phẩm." : "Chưa có sản phẩm nào.", style: TextStyle(color: secondaryTextColor, fontSize: 16)));
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        // *** BẮT ĐẦU SỬA LỖI: Điều chỉnh tỷ lệ để thẻ cao hơn ***
        childAspectRatio: 0.68,
        // *** KẾT THÚC SỬA LỖI ***
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductGridCard(product);
      },
    );
  }

  Widget _buildProductGridCard(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'Chưa có tên';
    final String imageUrl = product['imageUrl'] ?? '';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final productId = product['_id'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailScreen(
            product: product,
            userDocument: widget.userDocument,
            onProductAdded: widget.onProductAdded,
            selectedAddress: widget.selectedAddress,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.0),
          boxShadow: [BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 5, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 5,
            child: Stack(children: [
              Positioned.fill(
                child: Hero(
                  tag: productId,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.bakery_dining_outlined, color: Colors.black26, size: 40),
                          )
                        : const Icon(Icons.bakery_dining_outlined, color: Colors.black26, size: 40),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(204), shape: BoxShape.circle),
                  child: Icon(Icons.favorite_border, color: Colors.grey.shade600, size: 20),
                ),
              )
            ]),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Flexible(
                    child: Text(currencyFormatter.format(price), style: const TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis,),
                  ),
                  InkWell(
                    onTap: () => _handleAddToCart(product),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add_shopping_cart_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ])
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class PriceRangeDialog extends StatefulWidget {
  final double maxPrice;
  final RangeValues? initialRange;

  const PriceRangeDialog({
    Key? key,
    required this.maxPrice,
    this.initialRange,
  }) : super(key: key);

  @override
  PriceRangeDialogState createState() => PriceRangeDialogState();
}

class PriceRangeDialogState extends State<PriceRangeDialog> {
  late RangeValues _currentRange;
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialRange ?? RangeValues(0, widget.maxPrice);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lọc theo giá'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          'Từ ${currencyFormatter.format(_currentRange.start)} - ${currencyFormatter.format(_currentRange.end)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        RangeSlider(
          values: _currentRange,
          min: 0,
          max: widget.maxPrice,
          divisions: widget.maxPrice > 0 ? (widget.maxPrice / 50000).round().clamp(1, 100) : 1,
          labels: RangeLabels(
            currencyFormatter.format(_currentRange.start),
            currencyFormatter.format(_currentRange.end),
          ),
          onChanged: (values) => setState(() => _currentRange = values),
          activeColor: ProductScreenState.primaryColor,
        ),
      ]),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Xóa bộ lọc', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_currentRange),
          style: ElevatedButton.styleFrom(backgroundColor: ProductScreenState.primaryColor),
          child: const Text('Áp dụng', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}