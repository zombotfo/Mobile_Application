import 'package:flutter/material.dart';

import '../models/community_model.dart';
import '../services/community_service.dart';
import '../widgets/community_avatar.dart';
import 'community_screen.dart';
import 'create_community_screen.dart';

/// แท็บ "ชุมชน": ช่องค้นหา + ชุมชนของฉัน + ปุ่มสร้างชุมชนใหม่
class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key, required this.searchQuery});

  final String searchQuery;

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final _service = CommunityService();
  List<Community>? _mine;
  List<Community> _results = [];
  bool _hasError = false;
  bool _searching = false; // กำลังมีข้อความในช่องค้นหา
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMine();
    if (widget.searchQuery.trim().isNotEmpty) _search(widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant CommunitiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _search(widget.searchQuery);
    }
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
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityScreen(communityId: community.id),
      ),
    );
    _loadMine();
    if (deleted == true && _searching) {
      _search(widget.searchQuery);
    }
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
          ? Icon(
              Icons.lock_outline,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
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
            'ไม่พบชุมชนที่ตรงกับ "${widget.searchQuery}"',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
              children: [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'ยังไม่ได้เข้าร่วมชุมชนไหนเลย\nค้นหาชุมชนด้านบน หรือกดปุ่ม "สร้างชุมชน" เพื่อเริ่มต้น',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCommunity,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'สร้างชุมชน',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
