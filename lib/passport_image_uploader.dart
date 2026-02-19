import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef OnImageSelected = void Function(File file);

class PassportImageUploader extends StatefulWidget {
  final OnImageSelected? onImageSelected;
  final String title;
  final double previewHeight;
  final double previewWidth;

  const PassportImageUploader({
    Key? key,
    required this.title,
    this.onImageSelected,
    this.previewHeight = 180,
    this.previewWidth = 140,
  }) : super(key: key);

  static const double passportRatio = 35.0 / 45.0;

  @override
  State<PassportImageUploader> createState() => _PassportImageUploaderState();
}

class _PassportImageUploaderState extends State<PassportImageUploader> {
  File? _imageFile;
  bool _isProcessing = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    try {
      setState(() => _isProcessing = true);

      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 95, // You can remove or reduce this if needed
      );

      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final File image = File(picked.path);

      setState(() {
        _imageFile = image;
        _isProcessing = false;
      });

      widget.onImageSelected?.call(image);
    } catch (e, st) {
      setState(() => _isProcessing = false);
      debugPrint("PassportImageUploader error: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  void _clear() {
    setState(() {
      _imageFile = null;
    });
    widget.onImageSelected?.call(File(''));
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pick(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth * 0.4;
        double height = width / PassportImageUploader.passportRatio;

        return Container(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _isProcessing
                  ? SizedBox(
                      height: height,
                      width: width,
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : _imageFile == null
                      ? GestureDetector(
                          onTap: _showPickOptions,
                          child: Container(
                            height: height + 40,
                            width: width + 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 32,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap to upload',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                _imageFile!,
                                height: height,
                                width: width,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showPickOptions,
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Change'),
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: _clear,
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          ],
                        ),
            ],
          ),
        );
      },
    );
  }
}
