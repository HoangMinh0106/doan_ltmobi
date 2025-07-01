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
    Key? key,
    required this.userDocument,
    required this.onProductAdded,
    required this.onCartIconTapped,
    required this.selectedAddress,
  }) : super(key: key);

  @override
  ProductScreenState createState() => ProductScreenState();
}

class ProductScreenState extends State<ProductScreen> {
  final TextEditingController _searchController = TextEditingController();

  // State lists
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];

  // State for filters
  String? _selectedCategoryId;
  RangeValues? _selectedPriceRange;
  double _maxPrice = 1000000;

  // UI State
  bool _isLoading = true;
  String _errorMessage = '';
  int _cartTotalQuantity = 0;

  // Constants
  static const Color primaryColor = Color(0xFFF07167);
  static const Color scaffoldBackgroundColor = Color(0xFFF9F9F9);
  static const Color textColor = Color(0xFF333333);
  static final Color secondaryTextColor = Colors.grey.shade600;

  // Formatter
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _fetchData();
    updateCartBadge();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  /// Public method to be called from other screens (e.g., HomeScreen)
  void filterByCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _applyFilters();
    });
  }

  /// Fetches cart quantity and updates the badge
  Future<void> updateCartBadge() async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final count = await MongoDatabase.getCartTotalQuantity(userId);
    if (mounted) {
      setState(() {
        _cartTotalQuantity = count;
      });
    }
  }

  /// Fetches both products and categories from the database
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

  /// Applies all active filters (search, category, price) to the product list
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final productName = (product['name'] as String? ?? '').toLowerCase();
        final productPrice = (product['price'] as num).toDouble();
        final productCategoryId = product['categoryId']; // Can be ObjectId or String

        // Search Filter
        final bool searchMatch = productName.contains(query);

        // Category Filter
        final bool categoryMatch;
        if (_selectedCategoryId == null) {
          categoryMatch = true; // "All" is selected
        } else if (productCategoryId is mongo.ObjectId) {
          categoryMatch = productCategoryId.toHexString() == _selectedCategoryId;
        } else {
          categoryMatch = productCategoryId.toString() == _selectedCategoryId;
        }

        // Price Filter
        final bool priceMatch = _selectedPriceRange == null ||
            (productPrice >= _selectedPriceRange!.start &&
             productPrice <= _selectedPriceRange!.end);

        return searchMatch && categoryMatch && priceMatch;
      }).toList();
    });
  }
  
  /// Shows the price range filter dialog
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

    setState(() {
        _selectedPriceRange = newRange;
    });
    _applyFilters();
  }

  /// Handles adding a product to the cart
  void _handleAddToCart(Map<String, dynamic> product) async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final productName = product['name'] ?? 'Sản phẩm';
    await MongoDatabase.addToCart(userId, product);
    await updateCartBadge();
    widget.onProductAdded();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Đã thêm '$productName' vào giỏ hàng!"),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );
    }
  }

  /// Allows other screens to trigger a search
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
        children: [
          _buildSearchAndFilterBar(),
          _buildCategoryFilters(),
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  /// Builds the top bar with search field and filter button
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
                hintStyle: TextStyle(color: secondaryTextColor),
                prefixIcon: Icon(Icons.search, color: secondaryTextColor, size: 22),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _selectedPriceRange != null ? primaryColor : secondaryTextColor,
            ),
            onPressed: _showPriceFilterDialog,
            tooltip: 'Lọc theo giá',
          ),
        ],
      ),
    );
  }

  /// Builds the horizontal list of category filter chips
  Widget _buildCategoryFilters() {
    if (_isLoading) return const SizedBox(height: 50); // Placeholder
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1, // +1 for "All"
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" button
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ChoiceChip(
                label: const Text('Tất cả'),
                selected: _selectedCategoryId == null,
                onSelected: (selected) {
                  filterByCategory(null);
                },
                selectedColor: primaryColor.withOpacity(0.9),
                labelStyle: TextStyle(
                  color: _selectedCategoryId == null ? Colors.white : textColor,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: Colors.white,
                shape: StadiumBorder(
                    side: BorderSide(color: Colors.grey.shade300)),
              ),
            );
          }

          final category = _categories[index - 1];
          final categoryId = category['_id']?.toHexString() ?? category['_id'].toString();
          final isSelected = _selectedCategoryId == categoryId;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(category['name'] ?? 'N/A'),
              selected: isSelected,
              onSelected: (selected) {
                filterByCategory(categoryId);
              },
              selectedColor: primaryColor.withOpacity(0.9),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : textColor,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.white,
              shape: StadiumBorder(
                  side: BorderSide(color: Colors.grey.shade300)),
            ),
          );
        },
      ),
    );
  }

  /// Builds the cart icon with a badge
  Widget _buildCartIcon() {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.shopping_cart_outlined,
                color: Colors.grey.shade700, size: 28),
            onPressed: widget.onCartIconTapped,
          ),
          if (_cartTotalQuantity > 0)
            Positioned(
              right: 6,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$_cartTotalQuantity',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Builds the main content area (loading, error, empty, or product grid)
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(_errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryTextColor, fontSize: 16)),
      ));
    }
    if (_filteredProducts.isEmpty) {
      return Center(
          child: Text(
              _searchController.text.isNotEmpty || _selectedCategoryId != null || _selectedPriceRange != null
                  ? "Không tìm thấy sản phẩm."
                  : "Chưa có sản phẩm nào.",
              style: TextStyle(color: secondaryTextColor, fontSize: 16)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65, // <-- ĐÃ THAY ĐỔI: Thẻ cao hơn
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
  
  /// Builds a single product card for the grid view
  Widget _buildProductGridCard(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'Chưa có tên';
    final String imageUrl = product['imageUrl'] ?? '';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              userDocument: widget.userDocument,
              onProductAdded: widget.onProductAdded,
              selectedAddress: widget.selectedAddress,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Hero(
                  tag: product['_id'],
                  child: Container(
                    color: Colors.grey.shade100,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.image_not_supported, color: secondaryTextColor, size: 40),
                          )
                        : Icon(Icons.image_not_supported, color: secondaryTextColor, size: 40),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible( // <-- ĐÃ THAY ĐỔI: Chống tràn
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              currencyFormatter.format(price),
                              style: const TextStyle(
                                color: primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: () => _handleAddToCart(product),
                              icon: const Icon(Icons.add, size: 18, color: Colors.white),
                              padding: EdgeInsets.zero,
                              splashRadius: 20,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stateful dialog for selecting a price range.
class PriceRangeDialog extends StatefulWidget {
  final double maxPrice;
  final RangeValues? initialRange;

  const PriceRangeDialog({
    Key? key,
    required this.maxPrice,
    this.initialRange,
  }) : super(key: key);

  @override
  _PriceRangeDialogState createState() => _PriceRangeDialogState();
}

class _PriceRangeDialogState extends State<PriceRangeDialog> {
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Từ ${currencyFormatter.format(_currentRange.start)} - ${currencyFormatter.format(_currentRange.end)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          RangeSlider(
            values: _currentRange,
            min: 0,
            max: widget.maxPrice,
            divisions: 20,
            labels: RangeLabels(
              currencyFormatter.format(_currentRange.start),
              currencyFormatter.format(_currentRange.end),
            ),
            onChanged: (values) {
              setState(() {
                _currentRange = values;
              });
            },
            activeColor: ProductScreenState.primaryColor,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            // Return null to signify clearing the filter
            Navigator.of(context).pop(null);
          },
          child: const Text('Xóa bộ lọc', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            // Return the selected range
            Navigator.of(context).pop(_currentRange);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: ProductScreenState.primaryColor,
          ),
          child: const Text('Áp dụng', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}