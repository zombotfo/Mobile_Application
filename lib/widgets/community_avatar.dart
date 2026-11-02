import 'dart:convert';

import 'package:flutter/material.dart';

/// ไอคอนชุมชน: โชว์รูปถ้ามี ไม่งั้นโชว์ตัวอักษรแรกของชื่อ
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    super.key,
    required this.name,
    this.imageBase64,
    this.radius = 20,
  });

  final String name;
  final String? imageBase64;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundImage:
          imageBase64 != null ? MemoryImage(base64Decode(imageBase64!)) : null,
      child: imageBase64 == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'r',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
}
