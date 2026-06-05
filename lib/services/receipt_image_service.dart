import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiptImageService {
  ReceiptImageService._();

  static final ReceiptImageService instance = ReceiptImageService._();
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickReceiptImage(BuildContext context) async {
    final source = await _selectSource(context);
    if (source == null) {
      return null;
    }

    final hasPermission = await _ensurePermission(source);
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'Cần cấp quyền camera để quét ảnh.'
                  : 'Không thể truy cập thư viện ảnh.',
            ),
          ),
        );
      }
      return null;
    }

    return _picker.pickImage(
      source: source,
      imageQuality: 92,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  Future<ImageSource?> _selectSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Chụp bằng camera'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Chọn từ thư viện'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _ensurePermission(ImageSource source) async {
    if (kIsWeb) {
      return true;
    }

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return (await Permission.photos.request()).isGranted;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
    }
  }
}
