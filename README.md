# Agora

Agora คือแอปชุมชนและโซเชียลสำหรับสร้างพื้นที่พูดคุยตามความสนใจ โพสต์และแลกเปลี่ยนความคิดเห็น ติดตามเพื่อน และส่งข้อความหากัน พัฒนาด้วย Flutter และ Dart

## ความสามารถหลัก

- สมัครสมาชิกและเข้าสู่ระบบด้วย Firebase Authentication
- สร้างโพสต์ ดูฟีด แสดงความคิดเห็น โหวต และแสดง reaction
- สร้างและค้นหาชุมชน เข้าร่วมชุมชน และจัดการคำขอเข้าร่วม
- ดูรายชื่อสมาชิกและโพสต์ภายในชุมชน
- เพิ่มเพื่อน ติดตามผู้ใช้ และดูโปรไฟล์
- แชตส่วนตัว พร้อมแสดงเวลาและข้อมูลโปรไฟล์ของผู้สนทนา
- ส่งข้อเสนอแนะให้ทีมพัฒนาผ่านแอป
- อัปโหลดรูปภาพและวิดีโอของโพสต์ไปยัง Cloudinary

## เทคโนโลยี

- **Flutter** สำหรับพัฒนาแอปหลายแพลตฟอร์ม
- **Dart** เป็นภาษาเขียนโปรแกรม
- **Firebase Authentication** สำหรับบัญชีผู้ใช้และการเข้าสู่ระบบ
- **Cloud Firestore** สำหรับข้อมูลโปรไฟล์ โพสต์ ชุมชน เพื่อน และแชต
- **Cloudinary** สำหรับจัดเก็บสื่อรูปภาพและวิดีโอของโพสต์
- แพ็กเกจ Flutter ที่ใช้ เช่น `cloud_firestore`, `firebase_auth`, `firebase_core`, `image_picker` และ `video_player`

## เริ่มต้นใช้งาน

### สิ่งที่ต้องมี

- Flutter SDK ที่รองรับ Dart SDK constraint ใน `pubspec.yaml`
- โปรเจกต์ Firebase ที่เปิดใช้ Authentication และ Cloud Firestore
- ค่า Cloudinary `cloudName` และ `uploadPreset` สำหรับการอัปโหลดสื่อ

### ติดตั้งและรัน

1. ติดตั้ง dependencies:

   ```sh
   flutter pub get
   ```

2. ตั้งค่า Firebase สำหรับแพลตฟอร์มที่ต้องการ โดยใช้ FlutterFire CLI เพื่อสร้าง `lib/firebase_options.dart` และเพิ่มไฟล์ตั้งค่าของแพลตฟอร์มนั้น
3. ตั้งค่า Cloudinary ใน `lib/config/cloudinary_config.dart` และใช้ unsigned upload preset สำหรับการอัปโหลดจากแอป
4. เริ่มแอป:

   ```sh
   flutter run
   ```

Firestore Rules อยู่ใน `firestore.rules` สามารถนำไปตรวจสอบและเผยแพร่ผ่าน Firebase Console ได้
