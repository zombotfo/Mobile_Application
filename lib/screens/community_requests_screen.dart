import 'package:flutter/material.dart';

import '../models/community_model.dart';
import '../services/community_service.dart';

/// คำขอเข้าร่วมชุมชนที่รออนุมัติ (สำหรับเจ้าของชุมชนแบบ "ต้องอนุมัติ")
class CommunityRequestsScreen extends StatefulWidget {
  const CommunityRequestsScreen({super.key, required this.communityId});

  final String communityId;

  @override
  State<CommunityRequestsScreen> createState() =>
      _CommunityRequestsScreenState();
}

class _CommunityRequestsScreenState extends State<CommunityRequestsScreen> {
  final _service = CommunityService();
  List<CommunityMember>? _requests;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await _service.fetchPendingRequests(widget.communityId);
      if (mounted) setState(() { _requests = requests; _hasError = false; });
    } catch (e) {
      debugPrint('CommunityRequestsScreen._load error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คำขอเข้าร่วมชุมชน')),
      body: _hasError
          ? Center(
              child: TextButton(onPressed: _load, child: const Text('โหลดไม่สำเร็จ ลองใหม่')),
            )
          : _requests == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _requests!.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: Text(
                                  'ไม่มีคำขอที่รออนุมัติ',
                                  style: TextStyle(color: Colors.black45),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _requests!.length,
                          itemBuilder: (context, index) {
                            final r = _requests![index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  r.username.isNotEmpty
                                      ? r.username[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text('u/${r.username}'),
                              subtitle: const Text('ขอเข้าร่วมชุมชน'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'อนุมัติ',
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => _act(
                                      () => _service.approveRequest(
                                        widget.communityId,
                                        r.uid,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'ปฏิเสธ',
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _act(
                                      () => _service.declineRequest(
                                        widget.communityId,
                                        r.uid,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
