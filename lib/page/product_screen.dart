import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:flutter/services.dart';

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
  List<mongo.ObjectId> _favoriteProductIds = [];

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
    _searchController.addListener(() => setState(() {}));
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFavorites() async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    _favoriteProductIds = await MongoDatabase.getUserFavorites(userId);
    if (mounted) setState(() {});
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        MongoDatabase.productCollection.find().toList(),
        MongoDatabase.categoryCollection.find().toList(),
        _fetchFavorites(),
        updateCartBadge(),
      ]);

      final products = results[0] as List<Map<String, dynamic>>;
      final categories = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _categories = categories;
          _isLoading = false;
          if (_allProducts.isNotEmpty) {
            _maxPrice = _allProducts.map((p) => (p['price'] as num).toDouble()).reduce(max);
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
      setState(() => _cartTotalQuantity = count);
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
        final bool categoryMatch = _selectedCategoryId == null ||
            (productCategoryId is mongo.ObjectId && productCategoryId.oid == _selectedCategoryId) ||
            (productCategoryId.toString() == _selectedCategoryId);
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
        builder: (context) => PriceRangeDialog(
            maxPrice: _maxPrice, initialRange: _selectedPriceRange));
    if (mounted && newRange != _selectedPriceRange) {
      setState(() => _selectedPriceRange = newRange);
      _applyFilters();
    }
  }

  void _handleAddToCart(Map<String, dynamic> product) async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    await MongoDatabase.addToCart(userId, product);
    await updateCartBadge();
    widget.onProductAdded();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Đã thêm '${product['name']}' vào giỏ hàng!"),
        backgroundColor: Colors.green,
      ));
    }
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

  void performSearch(String query) {
    if (mounted) {
      _searchController.text = query;
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Sản phẩm",
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [_buildCartIcon()],
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: primaryColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAndFilterBar(),
            const SizedBox(height: 8),
            _buildCategoryFilters(),
            const SizedBox(height: 8),
            if (_searchController.text.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: RichText(
                      text: TextSpan(
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    children: [
                      const TextSpan(text: 'Kết quả tìm kiếm cho: '),
                      TextSpan(
                          text: '"${_searchController.text}"',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ))),
            Expanded(child: _buildBodyContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
        child: Row(children: [
          Expanded(
              child: TextField(
            controller: _searchController,
            onSubmitted: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm sản phẩm...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      })
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5)),
            ),
          )),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.filter_list_rounded,
                color: _selectedPriceRange != null
                    ? primaryColor
                    : secondaryTextColor),
            onPressed: _showPriceFilterDialog,
            tooltip: 'Lọc theo giá',
          ),
        ]),
      );

  Widget _buildCategoryFilters() {
    if (_isLoading) return const SizedBox(height: 50);
    if (_categories.isEmpty) return const SizedBox.shrink();
    return Container(height: 50, padding: const EdgeInsets.symmetric(vertical: 8.0), child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length + 1,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        if (index == 0) return Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ChoiceChip(
          label: const Text('Tất cả'),
          selected: _selectedCategoryId == null,
          onSelected: (selected) => filterByCategory(null),
          selectedColor: primaryColor,
          labelStyle: TextStyle(color: _selectedCategoryId == null ? Colors.white : textColor, fontWeight: FontWeight.bold),
          backgroundColor: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
        ));
        final category = _categories[index - 1];
        final categoryId = (category['_id'] as mongo.ObjectId).oid;
        final isSelected = _selectedCategoryId == categoryId;
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ChoiceChip(
          label: Text(category['name'] ?? 'N/A'),
          selected: isSelected,
          onSelected: (selected) => filterByCategory(categoryId),
          selectedColor: primaryColor,
          labelStyle: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold),
          backgroundColor: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
        ));
      },
    ));
  }

  Widget _buildCartIcon() => Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Stack(alignment: Alignment.center, children: [
        IconButton(
            icon: Icon(Icons.shopping_cart_outlined,
                color: Colors.grey.shade700, size: 28),
            onPressed: widget.onCartIconTapped),
        if (_cartTotalQuantity > 0)
          Positioned(
              right: 6,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10)),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text('$_cartTotalQuantity',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              )),
      ]));

  Widget _buildBodyContent() {
    if (_isLoading)
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    if (_errorMessage.isNotEmpty)
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryTextColor, fontSize: 16))));
    if (_filteredProducts.isEmpty)
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Không tìm thấy sản phẩm phù hợp.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryTextColor, fontSize: 16))));
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) =>
          _buildProductGridCard(_filteredProducts[index]),
    );
  }

  Widget _buildProductGridCard(Map<String, dynamic> product) {
    final productId = product['_id'] as mongo.ObjectId;
    final isFavorite = _favoriteProductIds.contains(productId);
    
    // **SỬA LỖI**: Lấy URL và kiểm tra trước khi hiển thị
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
                selectedAddress: widget.selectedAddress,
                isFavorite: isFavorite,
                onFavoriteToggle: () => _toggleFavorite(productId),
              ),
            ));
        if (result == 'favorite_toggled') _fetchFavorites();
      },
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  blurRadius: 5,
                  offset: const Offset(0, 5))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 5,
              child: Stack(children: [
                Positioned.fill(
                    child: Hero(
                        tag: productId,
                        child: ClipRRect(
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(16)),
                          child: (imageUrl != null && imageUrl.isNotEmpty)
                            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.error))
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_not_supported, color: Colors.grey),
                              )
                        ))),
                Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          splashRadius: 20,
                          icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite
                                  ? Colors.redAccent
                                  : Colors.grey.shade600,
                              size: 24),
                          onPressed: () => _toggleFavorite(productId),
                        ))),
              ])),
          Expanded(
              flex: 3,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(product['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                                child: Text(currencyFormatter.format(product['price']),
                                    style: const TextStyle(
                                        color: primaryColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis)),
                            InkWell(
                                onTap: () => _handleAddToCart(product),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 20,
                                      color: Colors.white),
                                )),
                          ]),
                    ],
                  ))),
        ]),
      ),
    );
  }
}

class PriceRangeDialog extends StatefulWidget {
  final double maxPrice;
  final RangeValues? initialRange;

  const PriceRangeDialog({super.key, required this.maxPrice, this.initialRange});

  @override
  PriceRangeDialogState createState() => PriceRangeDialogState();
}

class PriceRangeDialogState extends State<PriceRangeDialog> {
  late RangeValues _currentRange;
  late TextEditingController _minController;
  late TextEditingController _maxController;

  final NumberFormat _numberFormatter = NumberFormat("###,###");

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialRange ?? RangeValues(0, widget.maxPrice);
    _minController = TextEditingController(
        text: _numberFormatter.format(_currentRange.start.round()));
    _maxController = TextEditingController(
        text: _numberFormatter.format(_currentRange.end.round()));
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _updateTextFields(RangeValues values) {
    setState(() {
      _minController.text = _numberFormatter.format(values.start.round());
      _maxController.text = _numberFormatter.format(values.end.round());
    });
  }

  void _updateRangeFromTextFields() {
    final double min =
        double.tryParse(_minController.text.replaceAll(',', '')) ?? 0;
    final double max =
        double.tryParse(_maxController.text.replaceAll(',', '')) ??
            widget.maxPrice;
    if (min <= max && min >= 0 && max <= widget.maxPrice) {
      setState(() => _currentRange = RangeValues(min, max));
    }
  }

  Widget _buildPriceTextField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _ThousandsSeparatorInputFormatter()
        ],
        decoration: InputDecoration(
            labelText: label,
            prefixText: 'đ ',
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        onChanged: (value) => _updateRangeFromTextFields(),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lọc theo giá'),
      content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: _buildPriceTextField(_minController, 'Giá thấp nhất')),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('-')),
          Expanded(child: _buildPriceTextField(_maxController, 'Giá cao nhất')),
        ]),
        const SizedBox(height: 20),
        RangeSlider(
          values: _currentRange,
          min: 0,
          max: widget.maxPrice,
          divisions: widget.maxPrice > 0
              ? (widget.maxPrice / 1000).round().clamp(1, 500)
              : 1,
          labels: RangeLabels(_numberFormatter.format(_currentRange.start.round()),
              _numberFormatter.format(_currentRange.end.round())),
          onChanged: (values) {
            setState(() => _currentRange = values);
            _updateTextFields(values);
          },
          activeColor: ProductScreenState.primaryColor,
        ),
      ])),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Xóa bộ lọc', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_currentRange),
          style: ElevatedButton.styleFrom(
              backgroundColor: ProductScreenState.primaryColor),
          child: const Text('Áp dụng', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('###,###');
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    final num plainNumber = num.tryParse(newValue.text.replaceAll(',', '')) ?? 0;
    final String formattedText = _formatter.format(plainNumber);
    return newValue.copyWith(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length));
  }
}