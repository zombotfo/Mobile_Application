/// แสดงรายชื่อสมาชิกของชุมชนที่เลือก
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/community_model.dart';
import '../services/chat_service.dart';
import '../services/community_service.dart';
import 'profile_screen.dart';

class CommunityMembersScreen extends StatefulWidget {
  const CommunityMembersScreen({super.key, required this.communityId});

  final String communityId;

  @override
  State<CommunityMembersScreen> createState() =>
      _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  final _communityService = CommunityService();
  final _chatService = ChatService();
  List<CommunityMember>? _members;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await _communityService.fetchActiveMembers(
        widget.communityId,
      );
      if (mounted) {
        setState(() {
          _members = members;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('CommunityMembersScreen._load error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมาชิกในชุมชน')),
      body: _hasError
          ? Center(
              child: TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('โหลดรายชื่อไม่สำเร็จ ลองอีกครั้ง'),
              ),
            )
          : _members == null
              ? const Center(child: CircularProgressIndicator())
              : _members!.isEmpty
                  ? const Center(child: Text('ยังไม่มีสมาชิกในชุมชนนี้'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _members!.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final member = _members![index];
                          return StreamBuilder<Map<String, dynamic>?>(
                            stream: _chatService.userProfileStream(member.uid),
                            builder: (context, snapshot) {
                              final profile = snapshot.data;
                              final username =
                                  profile?['username'] as String? ??
                                      member.username;
                              ImageProvider<Object>? photo;
                              final encodedPhoto =
                                  profile?['photoBase64'] as String?;
                              if (encodedPhoto != null &&
                                  encodedPhoto.isNotEmpty) {
                                try {
                                  photo = MemoryImage(base64Decode(encodedPhoto));
                                } on FormatException {
                                  // Use the initial when the stored image is invalid.
                                }
                              }
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: photo,
                                  child: photo == null
                                      ? Text(username.isEmpty
                                          ? '?'
                                          : username[0].toUpperCase())
                                      : null,
                                ),
                                title: Text('u/$username'),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(uid: member.uid),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
