import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Màn hình tìm kiếm địa điểm (giới hạn country=VN)
class VnLocationSearch extends StatefulWidget {
  const VnLocationSearch({Key? key}) : super(key: key);

  @override
  State<VnLocationSearch> createState() => _VnLocationSearchState();
}

class _VnLocationSearchState extends State<VnLocationSearch> {
  List<dynamic> _results = [];

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=$q&format=json&limit=15&countrycodes=vn&addressdetails=1',
    );
    final res = await http.get(
      uri,
      headers: {
        'User-Agent': 'doan_ltmobi/1.0 (yourmail@example.com)', // OSM yêu cầu
      },
    );

    if (res.statusCode == 200) {
      setState(() => _results = jsonDecode(res.body));
    } else {
      setState(() => _results = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn địa điểm (VN)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập tên TP, quận…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                final name = r['display_name'];
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Container(
                    padding: const EdgeInsets.only(right: 12), // tránh sát viền
                    child: Text(
                      r['display_name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  onTap: () => Navigator.pop(context, r['display_name']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
