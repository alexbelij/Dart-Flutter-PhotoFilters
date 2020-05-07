import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera_ml_vision/flutter_camera_ml_vision.dart';

import 'camera_utils.dart';
import 'filters/filter_model.dart';
import 'image_utils.dart';

FaceDetector detector =
FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableClassification: false,
    enableLandmarks: true,
    enableTracking: true,
    mode: FaceDetectorMode.accurate,
    enableContours: true));

class ImageML {
  // If loaded from memory, these will be null
  String filename;
  ui.Image dartImage;

  bool get isFileBased => dartImage != null;

  double get width => dartImage.width.toDouble();

  double get height => dartImage.height.toDouble();

  Size get size => Size(width, height);

  // Regardless of how the image is loaded, this will be filled by the detector
  List<Face> faces = [];

  static Future<ImageML> fromFilename(String filename) async {
    if (filename == null || filename.isEmpty) return null;

    var dartImage = await getAppDartImage(filename);
    var firebaseImage = getAppFirebaseImage(filename);
    var faces = await detector.processImage(firebaseImage);

    return ImageML()
      ..filename = filename
      ..dartImage = dartImage
      ..faces = faces;
  }

  static Widget getPreviewWidget(BuildContext context, FilterModel model) {
//    print('getPreviewWidget: FileBased ${model.imageML?.isFileBased}');
//    double width = MediaQuery.of(context).size.width;
    // cameraMLVisionKey.currentState.cameraController.value.previewSize
    // Check if we can even display something
    if (model.imageML == null)
      return Text('[Image preview will go here]');
    // Check if we are displaying a static image
    else if (model.imageML.isFileBased) {
      return SizedBox(width: model.imageML.width, height: model.imageML.height, child: CustomPaint(painter: FacePainter(model.imageML.size, model)));
    }
    // Display real-time camera footage
    else
      return CameraMlVision<List<Face>>(
          key: cameraMLVisionKey,
          cameraLensDirection: cameraLensDirection,
          detector: detector.processImage,
          overlayBuilder: (c) {
            return CustomPaint(painter: FacePainter(cameraMLVisionKey.currentState.cameraValue.previewSize.flipped, model));
          },
          onResult: (resultFaces) {
            model.imageML.faces = resultFaces.toList();
            model.triggerRebuild();
//            print('Faces: ${resultFaces.length}');
          },
        );
  }
}

class FacePainter extends CustomPainter {
  FacePainter(this.imageSize, this.model) {
    if (model.imageML.isFileBased) {
      this.imageSize = model.imageML.size;
    }
  }

  bool get reflection => model.imageML.isFileBased ? false : (cameraLensDirection == CameraLensDirection.front);
  Size imageSize;
  final FilterModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    // Need to draw image to the canvas if file-based
    if (model.imageML.isFileBased) {
      canvas.drawImage(model.imageML.dartImage, Offset.zero, Paint());
    }

    model.imageML.faces.forEach((Face face) {
      // Draw the bounding boxes for the faces for debugging
      final faceRect = _reflectionRect(reflection, face.boundingBox, imageSize.width, imageSize.height);
      canvas.drawRect(_scaleRect(rect: faceRect, imageSize: imageSize, widgetSize: size), paint);

//    canvas.drawRect(faceRect, paint);

      model.landmarks.forEach((FaceLandmarkType landmarkType, FilterInfo filter) {
        FaceLandmark faceLandmark = face.getLandmark(landmarkType);
        if (faceLandmark == null) return;

        Rect landmarkRect = _scaleRect(rect: Rect.fromCenter(center: faceLandmark.position, width: filter.width, height: filter.height), imageSize: imageSize, widgetSize: size);

        ui.Image landmarkDartImage = filter.dartImage;
        if (landmarkDartImage == null) return;

        paintImage(
          canvas: canvas,
          rect: landmarkRect,
          image: landmarkDartImage,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        );
//
      });
      // Overlay the filter
    });

//    for (Face face in faces) {
//      final faceRect =
//      _reflectionRect(reflection, face.boundingBox, imageSize.width);
//      canvas.drawRect(
//        _scaleRect(
//          rect: faceRect,
//          imageSize: imageSize,
//          widgetSize: size,
//        ),
//        paint,
//      );
//    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return true;
//    return oldDelegate.imageSize != imageSize || oldDelegate.faces != faces;
  }
}

Rect _reflectionRect(bool reflection, Rect boundingBox, double width, double height) {
  if (!reflection) return boundingBox;

  final centerX = width / 2;
  final centerY = height / 2;
  final left = ((boundingBox.left - centerX) * -1) + centerX;
  final right = ((boundingBox.right - centerX) * -1) + centerX;

//  final top = ((boundingBox.top - centerY) * -1) + centerY;
//  final bottom = ((boundingBox.bottom - centerY) * -1) + centerY;

  final top = boundingBox.top;
  final bottom = boundingBox.bottom;

  return Rect.fromLTRB(left, top, right, bottom);
}

Rect _scaleRect({@required Rect rect, @required Size imageSize, @required Size widgetSize}) {
  final scaleX = widgetSize.width / imageSize.width;
  final scaleY = widgetSize.height / imageSize.height;

  final scaledRect = Rect.fromLTRB(
    rect.left.toDouble() * scaleX,
    rect.top.toDouble() * scaleY,
    rect.right.toDouble() * scaleX,
    rect.bottom.toDouble() * scaleY,
  );
  return scaledRect;
}

//class FacePainter extends CustomPainter {
//  FilterModel model;
//
//  FacePainter({@required this.model});
//
//  @override
//  void paint(Canvas canvas, Size size) async {
////    print('paint()');
////    ImageML imageML = model.imageML;
////    if (imageML.imageWrapper.libImage != null) {
////      for (int i = 0; i < imageML.imageWrapper.libImage.width; i++)
////        for (int j = 0; j < imageML.imageWrapper.libImage.height; j++) {
////          int pixel = imageML.imageWrapper.libImage.getPixel(i, j);
////          print('Pixel: $pixel');
//////          canvas.drawRect(Rect.fromCenter(center: Offset(i.toDouble(), j.toDouble()), width: 1, height: 1), Paint()..color = Color.);
////        }
////    } else
//    if (model.imageML.imageWrapper.dartImage != null) canvas.drawImage(model.imageML.imageWrapper.dartImage, Offset.zero, Paint());
//
//    model.imageML.faces.forEach((Face face) {
//      canvas.drawRect(
//          face.boundingBox,
//          Paint()
//            ..color = Colors.teal
//            ..strokeWidth = 6
//            ..style = PaintingStyle.stroke);
//
//      var faceCont = face.getContour(FaceContourType.face);
//      if (faceCont != null) {
//        canvas.drawPoints(
//            ui.PointMode.points,
//            faceCont.positionsList,
//            Paint()
//              ..strokeWidth = 3
//              ..color = Colors.white);
//        print('Face Contours: ${faceCont.positionsList.length}');
//      }
//
//      model.landmarks.forEach((landmarkType, filterInfo) {
//        var landmark = face.getLandmark(landmarkType);
//        var landmarkImage = filterInfo.imageWrapper.dartImage;
//        if (landmark != null && landmarkImage != null) {
//          paintImage(
//            canvas: canvas,
//            rect: Rect.fromCenter(
//              center: landmark.position,
//              width: filterInfo.width ?? 0,
//              height: filterInfo.height ?? 0,
//            ),
//            image: filterInfo.imageWrapper.dartImage,
//            fit: BoxFit.fill,
//            filterQuality: FilterQuality.high,
//          );
//        }
//      });
//    });
//  }
//
//  @override
//  bool shouldRepaint(CustomPainter oldDelegate) {
//    return true;
//  }
//}
