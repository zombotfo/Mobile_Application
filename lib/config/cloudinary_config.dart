/// ตั้งค่า Cloudinary สำหรับอัปโหลดวิดีโอโพสต์ (รูปภาพยังใช้ Base64 ฝังใน
/// Firestore เหมือนเดิม เปลี่ยนมาใช้ Cloudinary เฉพาะวิดีโอ เพราะไฟล์ใหญ่
/// เกินกว่าจะฝังในเอกสาร Firestore ได้)
///
/// สมัครบัญชีฟรีที่ https://cloudinary.com แล้วแก้ 2 ค่าด้านล่างให้ตรงกับของคุณ:
/// - cloudName: ดูได้ที่หน้า Dashboard หลังล็อกอิน (เขียนว่า "Cloud name")
/// - uploadPreset: สร้างที่ Settings → Upload → Upload presets → Add upload preset
///   ต้องตั้ง Signing Mode เป็น "Unsigned" ไม่งั้นอัปโหลดจากแอปไม่ได้
/// (ถ้าเคยสมัครไว้ก่อนหน้านี้แล้ว ใช้ค่าเดิมได้เลย ไม่ต้องสมัครใหม่)
class CloudinaryConfig {
  static const String cloudName = 'YOUR_CLOUD_NAME';
  static const String uploadPreset = 'YOUR_UPLOAD_PRESET';
}
