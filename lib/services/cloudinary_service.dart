import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

class CloudinaryService {
  Future<String> uploadImage(
    Uint8List bytes, {
    required String filename,
  }) async {
    if (CloudinaryConfig.cloudName == 'YOUR_CLOUD_NAME' ||
        CloudinaryConfig.uploadPreset == 'YOUR_UPLOAD_PRESET') {
      throw StateError('กรุณาตั้งค่า Cloudinary cloudName และ uploadPreset');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      String? detail;
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (data['error'] as Map<String, dynamic>?)?['message'] as String?;
      } catch (_) {}
      throw Exception(
        'อัปโหลดรูปไม่สำเร็จ (${response.statusCode})${detail == null ? '' : ': $detail'}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  Future<String> uploadVideo(
    Uint8List bytes, {
    required String filename,
  }) async {
    if (CloudinaryConfig.cloudName == 'YOUR_CLOUD_NAME' ||
        CloudinaryConfig.uploadPreset == 'YOUR_UPLOAD_PRESET') {
      throw StateError('กรุณาตั้งค่า Cloudinary cloudName และ uploadPreset');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/video/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      String? detail;
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (data['error'] as Map<String, dynamic>?)?['message'] as String?;
      } catch (_) {
        // Use the status code below when Cloudinary returns a non-JSON body.
      }
      throw Exception(
        'อัปโหลดวิดีโอไม่สำเร็จ (${response.statusCode})${detail == null ? '' : ': $detail'}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }
}
