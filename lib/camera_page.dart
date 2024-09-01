import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController controller;
  late List<CameraDescription> cameras;
  bool isCameraInitialized = false;
  bool isUploading = false;
  Timer? timer;
  bool _isDialogActive = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  @override
  void dispose() {
    controller?.dispose();
    timer?.cancel();
    super.dispose();
  }

  Future<void> initializeCamera() async {
    try {
      if (await Permission.camera.request().isGranted) {
        cameras = await availableCameras();
        final firstCamera = cameras[0];

        if (cameras.isNotEmpty) {
          controller = CameraController(firstCamera, ResolutionPreset.high, enableAudio: false);

          await controller?.initialize();

          if (!mounted) return;

          setState(() {
            isCameraInitialized = true;
          });

          controller!.startImageStream((CameraImage image) {
            if (!isUploading) {
              isUploading = true;
              captureFrame(image);
            }
          });

          timer = Timer.periodic(const Duration(milliseconds: 333), (Timer t) => captureFrameFromStream()); // 3 fps
        } else {
          print('No cameras available');
        }
      } else {
        print('Camera permissions not granted');
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void captureFrameFromStream() {
    if (controller != null && controller!.value.isStreamingImages) {
      isUploading = false;
    }
  }

  Future<void> captureFrame(CameraImage image) async {
    if (_isDialogActive) return; // Skip frame capture if a dialog is active

    try {
      final List<int> bytes = [];
      for (var plane in image.planes) {
        bytes.addAll(plane.bytes);
      }
      final Location location = Location();
      final LocationData locationData = await location.getLocation();

      final img.Image convertedImage = convertYUV420ToImage(image);
      final img.Image croppedImage = cropCenterSquare(convertedImage, 416);
      final List<int> jpegBytes = img.encodeJpg(croppedImage);

      final String filename = 'frame_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.0.115:5000/upload_frame'),
      );

      request.files.add(http.MultipartFile.fromBytes('file', jpegBytes, filename: filename));

      request.fields['latitude'] = locationData.latitude.toString();
      request.fields['longitude'] = locationData.longitude.toString();

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseBody);

        if (jsonResponse['message'] == 'Pothole detected. Confirm?') {
          _isDialogActive = true; // Mark dialog as active
          bool? confirmed = await showConfirmationDialog(
            jsonResponse['filename'],
            jsonResponse['latitude'],
            jsonResponse['longitude']
          );

          await confirmDetection(
            jsonResponse['filename'],
            jsonResponse['latitude'],
            jsonResponse['longitude'],
            confirmed
          );
        } else {
          print(jsonResponse['message']);
        }
      } else {
        print('Failed to upload frame');
      }
    } catch (e) {
      print(e);
    } finally {
      isUploading = false;
    }
  }

  img.Image cropCenterSquare(img.Image src, int size) {
    int x = (src.width - size) ~/ 2;
    int y = (src.height - size) ~/ 2;
    return img.copyCrop(src, x: x, y: y, width: size, height: size);
  }

  img.Image convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final img.Image imgImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvRowStride * (y >> 1) + (x >> 1) * uvPixelStride;

        final int yp = image.planes[0].bytes[y * width + x];
        final int up = image.planes[1].bytes[uvIndex];
        final int vp = image.planes[2].bytes[uvIndex];

        final int r = (yp + (1.370705 * (vp - 128))).clamp(0, 255).toInt();
        final int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128))).clamp(0, 255).toInt();
        final int b = (yp + (1.732446 * (up - 128))).clamp(0, 255).toInt();

        imgImage.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    // Rotate the image to correct the orientation
    final img.Image rotatedImage = img.copyRotate(imgImage, angle: 90);

    return rotatedImage;
  }

  int yuv2rgb(int y, int u, int v) {
    int r = (y + (1.370705 * (v - 128))).toInt();
    int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).toInt();
    int b = (y + (1.732446 * (u - 128))).toInt();

    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);

    return (255 << 24) | (r << 16) | (g << 8) | b; // ARGB format
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Stream'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.previewSize!.height,
                    height: controller!.value.previewSize!.width,
                    child: CameraPreview(controller!),
                  ),
                ),
              );
            },
          ),
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red,
                  width: 3,
                  style: BorderStyle.solid,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> showConfirmationDialog(String filename, String latitude, String longitude) async {
    _isDialogActive = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pothole Detected'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('A pothole was detected in the image. Do you confirm this detection?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
    _isDialogActive = false;
    return result;
  }

  Future<void> confirmDetection(String filename, String latitude, String longitude, bool? confirmed) async {
    final response = await http.post(
      Uri.parse('http://192.168.0.115:5000/confirm_detection'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'filename': filename,
        'latitude': latitude,
        'longitude': longitude,
        'confirmed': confirmed ?? false,
      }),
    );

    if (response.statusCode == 200) {
      print('Confirmation received and data saved');
    } else {
      print('Failed to confirm detection');
    }
  }
}
