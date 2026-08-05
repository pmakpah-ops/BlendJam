import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() => runApp(BlendJamApp());

class BlendJamApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: "BlendJam DJ", theme: ThemeData.dark(), home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> playlist = [];
  final _ffmpeg = FlutterFFmpeg();

  @override
  void initState() { super.initState(); Permission.storage.request(); }

  Future<void> pickSongs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result != null) { setState(() { playlist = result.paths.map((path) => File(path!)).take(30).toList(); }); }
  }

  Future<void> exportMix() async {
    if (playlist.length < 2) return;
    String dir = (await getExternalStorageDirectory())!.path;
    String output = "$dir/BlendJam_Mix_${DateTime.now().millisecondsSinceEpoch}.mp3";
    String inputs = ""; String filter = "";
    for (int i = 0; i < playlist.length; i++) {
      inputs += "-i '${playlist[i].path}' ";
      if (i > 0) { filter += "[${i-1}][${i}]acrossfade=d=5:c1=tri:c2=tri[a$i];"; }
    }
    String cmd = "$inputs -filter_complex '$filter' -map [a${playlist.length-1}] '$output'";
    await _ffmpeg.execute(cmd);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Exported to Downloads")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("BlendJam DJ")),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton(onPressed: pickSongs, child: Text("1. Pick Songs")),
        Text("Selected: ${playlist.length} songs"),
        ElevatedButton(onPressed: exportMix, child: Text("2. Export 1 MP3")),
      ])),
    );
  }
}
