/// แปลงเวลาเป็นข้อความแบบ "x นาทีที่แล้ว" โดยไม่ต้องพึ่ง package เพิ่ม
String timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
  if (diff.inDays < 30) return '${diff.inDays} วันที่แล้ว';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} เดือนที่แล้ว';
  return '${(diff.inDays / 365).floor()} ปีที่แล้ว';
}
