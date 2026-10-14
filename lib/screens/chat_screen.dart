import 'package:flutter/material.dart';

/// หน้าแชทชั่วคราว ไว้ใส่ระบบคุยกับเพื่อนจริงๆ ในขั้นตอนถัดไป
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              'ระบบแชทกำลังอยู่ระหว่างพัฒนา',
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
