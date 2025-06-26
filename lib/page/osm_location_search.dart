import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Màn hình tìm kiếm địa điểm bằng OpenStreetMap (miễn phí)
class OsmLocationSearch extends StatefulWidget {
  const OsmLocationSearch({Key? key}) : super(key: key);

  @override
  State<OsmLocationSearch> createState() => _OsmLocationSearchState();
}

class _OsmLocationSearchState extends State<OsmLocationSearch> {
  List<dynamic> _results = [];

  Future<void> _search(String q) async {
    if (q.isEmpty) return setState(() => _results = []);
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$q&format=json&limit=10',
    );
    final res = await http.get(uri, headers: {
      'User-Agent': 'doan_ltmobi/1.0 (email@example.com)' // OSM yêu cầu
    });
    if (res.statusCode == 200) {
      setState(() => _results = jsonDecode(res.body));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn vị trí')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập tên TP, quận…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  title: Text(name),
                  onTap: () => Navigator.pop(context, name), // trả về địa chỉ
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
