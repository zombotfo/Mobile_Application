import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'chat_list_screen.dart';
import 'create_post_screen.dart';
import 'edit_profile_screen.dart';
import 'feed_screen.dart';
import 'friends_list_screen.dart';

/// โครงหลักของแอปหลังล็อกอิน: top bar (โปรไฟล์ / ค้นหา / เมนู)
/// + bottom nav (หน้าหลัก / สร้างโพสต์ / แชท)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0; // 0 = หน้าหลัก, 1 = แชท ("สร้างโพสต์" ไม่ใช่แท็บ แต่ push หน้าใหม่)
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // ใช้ GlobalKey อ้างถึง state ของ FeedScreen จากข้างนอก เพื่อสั่งรีเฟรช
  // ทันทีได้ (เช่นตอนสร้างโพสต์สำเร็จ หรือกดปุ่มรีเฟรชเอง) โดยไม่ต้องรอ
  // รอบ poll อัตโนมัติทุก 1 นาทีของ FeedScreen
  final _feedKey = GlobalKey<FeedScreenState>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created == true) {
      // สลับมาแท็บหน้าหลักด้วย เผื่อผู้ใช้กด "สร้างโพสต์" จากตอนอยู่แท็บแชท
      setState(() => _tabIndex = 0);
      _feedKey.currentState?.refreshNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initial = (user.displayName?.isNotEmpty ?? false)
        ? user.displayName![0].toUpperCase()
        : (user.email?.isNotEmpty ?? false)
            ? user.email![0].toUpperCase()
            : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              initial: initial,
              username: user.displayName ?? '',
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              onRefresh: _tabIndex == 0
                  ? () => _feedKey.currentState?.refreshNow()
                  : null,
            ),
            const Divider(height: 1),
            Expanded(
              child: _tabIndex == 0
                  ? FeedScreen(key: _feedKey, searchQuery: _searchQuery)
                  : const ChatListScreen(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _tabIndex,
        onHome: () => setState(() => _tabIndex = 0),
        onChat: () => setState(() => _tabIndex = 1),
        onCreate: _openCreatePost,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.initial,
    required this.username,
    required this.controller,
    required this.onChanged,
    this.onRefresh,
  });

  final String initial;
  final String username;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  // null เมื่ออยู่แท็บที่ไม่มีฟีดให้รีเฟรช (เช่นแท็บแชท)
  final VoidCallback? onRefresh;

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบบัญชี'),
        content: const Text(
          'บัญชีและโพสต์ทั้งหมดของคุณจะถูกลบถาวร ไม่สามารถกู้คืนได้ ยืนยันหรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ลบบัญชี',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirestoreService().deleteAccount();
      // สำเร็จแล้ว: Firebase Auth user กลายเป็น null อัตโนมัติ
      // AuthGate ใน main.dart จะพากลับไปหน้า Login เอง ไม่ต้อง navigate เอง
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ลบบัญชีไม่สำเร็จ กรุณาออกจากระบบแล้วเข้าสู่ระบบใหม่ก่อนลองอีกครั้ง',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          // โปรไฟล์: แตะเพื่อเปิดเมนู แก้ไขโปรไฟล์ / ออกจากระบบ / ลบบัญชี
          PopupMenuButton<String>(
            tooltip: 'โปรไฟล์',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          EditProfileScreen(currentUsername: username),
                    ),
                  );
                  break;
                case 'friends':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FriendsListScreen(),
                    ),
                  );
                  break;
                case 'logout':
                  AuthService().signOut();
                  break;
                case 'delete':
                  _confirmDeleteAccount(context);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('แก้ไขโปรไฟล์')),
              PopupMenuItem(value: 'friends', child: Text('เพื่อนของฉัน')),
              PopupMenuItem(value: 'logout', child: Text('ออกจากระบบ')),
              PopupMenuItem(
                value: 'delete',
                child: Text('ลบบัญชี', style: TextStyle(color: Colors.red)),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.black45,
                  ),
                  hintText: 'ค้นหาโพสต์...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.black45),
                ),
              ),
            ),
          ),
          if (onRefresh != null)
            IconButton(
              tooltip: 'รีเฟรชฟีด',
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
          IconButton(
            tooltip: 'เมนู',
            icon: const Icon(Icons.menu),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('เมนูนี้จะเปิดใช้งานเร็วๆ นี้')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onHome,
    required this.onChat,
    required this.onCreate,
  });

  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onChat;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'หน้าหลัก',
              selected: currentIndex == 0,
              onTap: onHome,
            ),
            _CreateButton(onTap: onCreate),
            _NavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'แชท',
              selected: currentIndex == 1,
              onTap: onChat,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Theme.of(context).colorScheme.primary : Colors.black45;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ปุ่ม "สร้างโพสต์" ตรงกลาง ไม่ใช่แท็บ แต่กดแล้ว push หน้าสร้างโพสต์ทันที
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}
