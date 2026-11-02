import 'package:flutter/material.dart';

import '../models/community_model.dart';
import '../services/community_service.dart';
import '../widgets/community_avatar.dart';
import 'community_screen.dart';
import 'create_community_screen.dart';

/// แท็บ "ชุมชน": ช่องค้นหา + ชุมชนของฉัน + ปุ่มสร้างชุมชนใหม่
class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final _service = CommunityService();
  final _searchController = TextEditingController();

  List<Community>? _mine;
  List<Community> _results = [];
  bool _hasError = false;
  bool _searching = false; // กำลังมีข้อความในช่องค้นหา
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    try {
      final mine = await _service.fetchMyCommunities();
      if (mounted) setState(() { _mine = mine; _hasError = false; });
    } catch (e) {
      debugPrint('CommunitiesScreen._loadMine error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _searching = false; _results = []; });
      return;
    }
    setState(() { _searching = true; _searchLoading = true; });
    try {
      final results = await _service.searchCommunities(query);
      if (mounted) setState(() { _results = results; _searchLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _searchLoading = false; });
    }
  }

  Future<void> _open(Community community) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityScreen(communityId: community.id),
      ),
    );
    _loadMine(); // เข้า/ออกชุมชนมาแล้ว ลิสต์ของฉันอาจเปลี่ยน
  }

  Future<void> _createCommunity() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
    );
    if (id == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CommunityScreen(communityId: id)),
    );
    _loadMine();
  }

  Widget _tile(Community c) {
    return ListTile(
      leading: CommunityAvatar(name: c.name, imageBase64: c.imageBase64),
      title: Text(
        'r/${c.name}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${c.memberCount} สมาชิก'),
      trailing: c.requiresApproval
          ? const Icon(Icons.lock_outline, size: 18, color: Colors.black38)
          : null,
      onTap: () => _open(c),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      if (_searchLoading) return const Center(child: CircularProgressIndicator());
      if (_results.isEmpty) {
        return Center(
          child: Text(
            'ไม่พบชุมชนที่ตรงกับ "${_searchController.text}"',
            style: const TextStyle(color: Colors.black45),
          ),
        );
      }
      return ListView(children: _results.map(_tile).toList());
    }

    if (_hasError) {
      return Center(
        child: TextButton(onPressed: _loadMine, child: const Text('โหลดไม่สำเร็จ ลองใหม่')),
      );
    }
    if (_mine == null) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadMine,
      child: _mine!.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'ยังไม่ได้เข้าร่วมชุมชนไหนเลย\nค้นหาชุมชนด้านบน หรือกดปุ่ม "สร้างชุมชน" เพื่อเริ่มต้น',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
              ],
            )
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'ชุมชนของฉัน',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ..._mine!.map(_tile),
                const SizedBox(height: 72), // กันปุ่มสร้างชุมชนบังรายการล่างสุด
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'ค้นหาชุมชน...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF0F0F1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCommunity,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('สร้างชุมชน'),
      ),
    );
  }
}
