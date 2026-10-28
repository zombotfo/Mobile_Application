import 'package:flutter/material.dart';

import '../models/friendship_model.dart';
import '../services/friend_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final _friendService = FriendService();
  List<Friendship>? _requests;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requests = await _friendService.fetchIncomingRequests();
    if (mounted) setState(() => _requests = requests);
  }

  Future<void> _accept(Friendship request) async {
    try {
      await _friendService.acceptFriendRequest(request.otherUid);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  Future<void> _decline(Friendship request) async {
    try {
      await _friendService.removeFriendship(request.otherUid);
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
      appBar: AppBar(title: const Text('คำขอเป็นเพื่อน')),
      body: _requests == null
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
                              'ไม่มีคำขอเป็นเพื่อน',
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
                              r.otherUsername.isNotEmpty
                                  ? r.otherUsername[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text('u/${r.otherUsername}'),
                          subtitle: const Text('ขอเป็นเพื่อนกับคุณ'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'ยอมรับ',
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                onPressed: () => _accept(r),
                              ),
                              IconButton(
                                tooltip: 'ปฏิเสธ',
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () => _decline(r),
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
