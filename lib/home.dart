import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'dart:math' as math;
import 'package:test2/models.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomePage(this.cameras);

  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {

  late List<dynamic> _recognitions;
  late CameraController _controller;
  // int _imageHeight = 0;
  // int _imageWidth = 0;
  int _selectedCameraIdx = 0;
  bool isDetecting = false;
  String _model = "";
  String _result = "";
  String app_save_dir = "";
  var globalKey = new GlobalKey();

  int avgElapsedTime = 0;
  double avgConcScore = 0;
  double avgRecognition = 0;
  int count = 0;
  int Ncount = 0;

  // 얼굴인식을 못할 때 카운트
  @override
  void initState() {
    super.initState();
    _controller = new CameraController(
      widget.cameras[_selectedCameraIdx],
      ResolutionPreset.high,
    );
  }

  void loadModel() async {
    String res;
    res = (await Tflite.loadModel(
        model: "assets/mobilenet_v2_conface.tflite",
        labels: "assets/mobilenet_v2_conface.txt",
        useGpuDelegate: false))!;
    print(res);
  }

  void onSelect(model) async {
    setState(() {
      _model = model;
    });
    loadModel();
    if (widget.cameras == null || widget.cameras.length < 1) {
      print('No camera is found');
    } else {
      await _initializeCameraController();
    }
  }

  // 화면 캡쳐 함수
  void _capture() async {
    print("START CAPTURE");
    var renderObject = globalKey.currentContext!.findRenderObject();
    if (renderObject is RenderRepaintBoundary) {
      var boundary = renderObject;
      ui.Image image = await boundary.toImage();
      final directory = (await getApplicationDocumentsDirectory()).path;
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      print(pngBytes);
      File imgFile = new File('$directory/screenshot.png');
      imgFile.writeAsBytes(pngBytes);
      print("FINISH CAPTURE ${imgFile.path}");
    }
  }
  // setRecognitions(recognitions, imageHeight, imageWidth) {
  //   setState(() {
  //     _recognitions = recognitions;
  //     _result =
  //         "${_recognitions[0]["label"]} ${(_recognitions[0]['confidence'] * 100).toStringAsFixed(0)}%";
  //     _imageHeight = imageHeight;
  //     _imageWidth = imageWidth;
  //   });
  // }
  switchCameraDirection() async {
    setState(() {
      _selectedCameraIdx = _selectedCameraIdx == 0 ? 1 : 0;
    });
    // _controller.dispose();
    if (_controller != null) {
      await _controller.dispose();
      await Tflite.close();
    }
    // loadModel();
    // await _initializeCameraController();
    await _initializeCameraController();
  }

  Future _initializeCameraController() async {
    _controller = new CameraController(
      widget.cameras[_selectedCameraIdx],
      ResolutionPreset.medium,
    );
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      _controller.startImageStream((CameraImage img) {
        if (!isDetecting) {
          isDetecting = true;
          int startTime = new DateTime.now().millisecondsSinceEpoch;
          if(_model == mobilenet) {
            // print('img h,w ${img.height} ${img.width}');
            Tflite.runModelOnFrame(
              bytesList: img.planes.map((plane) {
                return plane.bytes;
              }).toList(),
              imageHeight: img.height,
              imageWidth: img.width,
              numResults: 3,
            ).then((recognitions) {
              int endTime = new DateTime.now().millisecondsSinceEpoch;
              //print("Detection took ${extime}ms");
              // print(recognitions[0]['confidence']);
              // print(recognitions[0]['label']);
              // setRecognitions(recognitions, img.height, img.width);
              // bool fileExist =
              //     File('/storage/emulated/0/DCIM/orig_image.jpg').existsSync();
              // print('/storage/emulated/0/DCIM/orig_image.jpg');
              // print("orig_image.jpg is ${fileExist}");
              setState(() { //1초 마다 정확률을 갱신함 1초 지나면 5
                if (recognitions!.isEmpty) {
                  _result = "score < 10%";
                } else {
                  // String res1 =
                  //     "${recognitions[0]["label"]} ${(recognitions[0]['confidence'] * 100).toStringAsFixed(0)}%\n";
                  // String res2 =
                  //     "${recognitions[1]["label"]} ${(recognitions[1]['confidence'] * 100).toStringAsFixed(0)}%\n";
                  // String res3 =
                  //     "${recognitions[2]["label"]} ${(recognitions[2]['confidence'] * 100).toStringAsFixed(0)}%";
                  // _result = res1 + res2 + res3;


                  // 얼굴인식을 하지 못했을 때
                  if (recognitions[0]['label'] == '얼굴을 찾을 수 없음') {
                    avgRecognition += recognitions[0]['confidence'];
                    Ncount++;
                    if (Ncount == 10) {
                      _capture();
                      _result = '얼굴을 찾을 수 없음. 인식률: ${((1 - (avgRecognition / 10)) * 100).toStringAsFixed(1)}%';
                      avgRecognition = 0;
                      Ncount = 0;
                      print(_result);
                    }
                  } else { // 얼굴인식에 성공했을 때


                    // 집중할 경우 confidence의 값만큼 집중도를 측정
                    if(_recognitions[0]['label'] == '집중하고 있음') {
                      avgConcScore += recognitions[0]['confidence'].toStringAsFixed(1);
                    }
                    else{ // 인식결과가 집중하지 않음일 경우 100-confidence의 값을 가지고
                      avgConcScore += 100 - recognitions[0]['confidence'].toStringAsFixed(1);
                      print('집중안할때 confidence 수치');
                      print(recognitions[0]['confidence']);
                      print(recognitions[0]['confidence'].toStringAsFixed(0));
                    }

                    int elapsedTime = endTime - startTime;
                    avgElapsedTime += elapsedTime;

                    if (count == 10) {
                      avgElapsedTime = avgElapsedTime ~/ 10;

                      // 평균 얼굴인식 시간에 따른 점수부여를 위해 40 < avgElapsedTime < 60의 범위로 제한.
                      if (avgElapsedTime < 40) {
                        avgElapsedTime = 40;
                      } else if (avgElapsedTime > 60) {
                        avgElapsedTime = 60;
                      }
                      // 얼굴인식 시간에 따른 점수값의 비중. 20%
                      int timeScore = (60 - avgElapsedTime);

                      print("avgElapsedTime took ${avgElapsedTime}ms");

                      // 집중도 점수, 10프레임의 영상에 대한 집중도를 평균으로 환산하여 점수를 매김. 80%의 비중을 차지
                      int concScore = (avgConcScore ~/ 100) * 80;
                      _result =
                      "집중도: ${timeScore + concScore}";
                      print(_result);

                      // 집중도가 낮을시 화면 캡쳐해 aws서버로 전송
                      if(timeScore + concScore < 30) {
                        _capture();
                      }

                      avgConcScore = 0;
                      avgElapsedTime = 0;
                      count = 0;
                    }
                    count++;
                  }
                }
              });
              isDetecting = false;
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return RepaintBoundary(
      key: globalKey,
      child: Scaffold(
        appBar: AppBar(title: Text(_result), backgroundColor: Colors.redAccent),
        body: _model == "" ?
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              RaisedButton(
                child: const Text('Start'),
                onPressed: () => onSelect(mobilenet),
              ),
            ],
          ),
        ) : GestureDetector(
            child: CameraPreview(_controller),
            onDoubleTap: switchCameraDirection
        ),

        floatingActionButton: _controller != null ?
        FloatingActionButton(
          onPressed: switchCameraDirection,
          child: Icon(Icons.switch_camera),
        ) : null,
      )
    );
  }
}