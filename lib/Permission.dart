import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:toast/toast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io' as io;
import 'package:audioplayers/audioplayers.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionWidget extends StatefulWidget {
  final LocalFileSystem localFileSystem;
  PermissionWidget({localFileSystem})
      : this.localFileSystem = localFileSystem ?? LocalFileSystem();

  @override
  _PermissionWidgetState createState() => _PermissionWidgetState();
}

class _PermissionWidgetState extends State<PermissionWidget> {
  //for permission
  PermissionStatus status = PermissionStatus.undetermined;
  //for recording
  FlutterAudioRecorder _recorder;
  Recording _current;
  RecordingStatus _currentStatus = RecordingStatus.Unset;

  var nameList = List<String>();
  var pathList = List<String>();
  var durList = List<String>();
  var count = 0;

  @override
  void initState() {
    super.initState();
    listenForStatus();
  }

  listenForStatus() async {
    //taking permission
    var s = PermissionStatus.undetermined;
    var s1 = PermissionStatus.undetermined;
    s = await Permission.microphone.status;
    await Permission.microphone.request();
    s1 = await Permission.storage.status;
    await Permission.storage.request();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    nameList = prefs.getStringList('names') ?? List<String>();
    pathList = prefs.getStringList('path') ?? List<String>();
    durList = prefs.getStringList('duration') ?? List<String>();
    count = prefs.getInt('count') ?? (0.toInt());

    print('pathList(init): $pathList');

    //if has permission initializing the recorder and file paths.
    try {
      if (await FlutterAudioRecorder.hasPermissions) {
        //'flutter_audio_recorder is the subpart of the name of the audio file
        String customPath = 'flutter_audio_recorder';

        //accessing directories in the phone to store audio locally.
        io.Directory appDocDirectory;
        if (io.Platform.isIOS) {
          appDocDirectory = await getApplicationDocumentsDirectory();
        } else {
          appDocDirectory = await getExternalStorageDirectory();
        }

        //the entire path stored in customPath depending on the date and time.
        customPath = appDocDirectory.path +
            customPath +
            DateTime.now().millisecondsSinceEpoch.toString();

        //initializing the FlutterAudioRecorder object.
        _recorder =
            FlutterAudioRecorder(customPath, audioFormat: AudioFormat.WAV);
        await _recorder.initialized;

        //after initialization
        var current = await _recorder.current(channel: 0);
        print('current : $current');

        //setting some variables as state objects
        setState(() {
          _current = current;
          _currentStatus = current.status;
          print('currentStatus : $_currentStatus');
          //this is for the use to change the name of the audio file
        });
      } else {
        Scaffold.of(context).showSnackBar(
            new SnackBar(content: new Text("You must accept permissions")));
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Watson'),
          backgroundColor: Colors.blueGrey[900],
        ),
        body: Container(
          margin: EdgeInsets.all(10),
          color: Colors.white,
          child: Column(children: <Widget>[
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  FloatingActionButton(
                    child: button(_currentStatus),
                    onPressed: () {
                      switch (_currentStatus) {
                        case RecordingStatus.Initialized:
                          {
                            _start();
                            break;
                          }
                        case RecordingStatus.Recording:
                          {
                            _pause();
                            break;
                          }
                        case RecordingStatus.Paused:
                          {
                            _resume();
                            break;
                          }
                        case RecordingStatus.Stopped:
                          {
                            listenForStatus();
                            break;
                          }
                        default:
                          break;
                      }
                    },
                    backgroundColor: Colors.deepPurple,
                  ),
                  FloatingActionButton(
                    child: Icon(
                      Icons.stop,
                      color: Colors.white,
                    ),
                    onPressed:
                        _currentStatus != RecordingStatus.Unset ? _stop : null,
                    //_currentStatus != RecordingStatus.Unset ? _stop() : null,
                    backgroundColor: Colors.deepPurple,
                  ),
                ]),
            SizedBox(
              height: 20,
            ),
            (_current?.duration != null)
                ? Text(_current?.duration.toString().substring(0, 7))
                : Text(''),
            SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Scaffold(
                backgroundColor: Colors.white,
                body: populateList(),
              ),
            )
          ]),
        ),
      ),
    );
  }

  Widget button(_currentStatus) {
    switch (_currentStatus) {
      case RecordingStatus.Initialized:
        {
          var i = Icon(Icons.mic, color: Colors.white);
          return i;
          break;
        }
      case RecordingStatus.Recording:
        {
          var i = Icon(Icons.pause, color: Colors.white);
          return i;
          break;
        }
      case RecordingStatus.Paused:
        {
          var i = Icon(Icons.play_arrow, color: Colors.white);
          return i;
          break;
        }
      case RecordingStatus.Stopped:
        {
          var i = Icon(Icons.replay, color: Colors.white);
          return i;
          break;
        }

      default:
        return (Icon(Icons.hourglass_empty));
    }
  }

  _start() async {
    try {
      await _recorder.start();
      var recording = await _recorder.current(channel: 0);
      setState(() {
        _current = recording;
      });

      const tick = const Duration(seconds: 1);
      new Timer.periodic(tick, (Timer t) async {
        if (_currentStatus == RecordingStatus.Stopped) {
          t.cancel();
        }
        var current = await _recorder.current(channel: 0);
        setState(() {
          _current = current;
          _currentStatus = _current.status;
        });
      });
    } catch (e) {
      print(e);
    }
  }

  _resume() async {
    await _recorder.resume();
    setState(() {});
  }

  _pause() async {
    await _recorder.pause();
    setState(() {});
  }

  _stop() async {
    var result = await _recorder.stop();
    print('stop recording : ${result.path}');
    print('stop recording : ${result.duration}');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    var n = prefs.getStringList('names');
    var p = prefs.getStringList('path');
    var d = prefs.getStringList('duration');
    var c = prefs.getInt('count') ?? 0;

    n.add('Recording: $c');
    c = ++c;
    p.add(result.path);
    d.add(result.duration.toString().substring(0, 7));

    prefs.setStringList('names', n);
    prefs.setStringList('duration', d);
    prefs.setStringList('path', p);
    prefs.setInt('count', c);

    File file = widget.localFileSystem.file(result.path);
    //file.rename(pathToEdit + 'rename' + '.wav');
    print("File length: ${await file.length()}");
    setState(() {
      _current = result;
      _currentStatus = _current.status;
      nameList = n;
      durList = d;
      pathList = p;
      count = c;
      print('pathList(stop): $pathList');
    });
  }

  Widget populateList() {
    if (nameList.length != 0) {
      return ListView.builder(
        itemBuilder: (context, index) {
          double scale = 1;
          return StatefulBuilder(builder: (context, setState) {
            return ListTile(
              title: Transform.scale(
                  scale: scale,
                  child: Container(
                    child: Text(nameList[index]),
                  )),
              subtitle: Text(durList[index]),
              leading: Icon(Icons.music_note, color: Colors.pink),
              onTap: () {
                setState(() {
                  scale = 1;
                });
                audioPlayerFunc(pathList[index]);
              },
            );
          });
        },
        itemCount: nameList.length,
      );
    } else {
      return Center(child: Text('Recording List Here'));
    }
  }

  audioPlayerFunc(String path) async {
    AudioPlayer audioPlayer = AudioPlayer();
    await audioPlayer.play(path, isLocal: true);
  }
}
