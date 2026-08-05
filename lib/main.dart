import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() => runApp(BlendJamApp());

class BlendJamApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "BlendJam DJ",
      theme: ThemeData.dark(),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> playlist = [];
  final AudioPlayer _player = AudioPlayer();
  // REMOVED: final _ffmpeg = FlutterFFmpeg(); LINE 25 FIXED

  @override
  void initState() {
    super.initState();
    Permission.storage.request();
  }

  Future<void> pickSongs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result!= null) {
      setState(() {
        playlist = result.paths.map((path) => File(path!)).toList();
      });
    }
  }

  Future<void> exportMix() async {
    if (playlist.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pick at least 2 songs first"))
      );
      return;
    }
    
    // TEMPORARILY DISABLED: FFmpeg mixing until build works
    // LINE 45 FIXED - removed _ffmpeg.execute(cmd)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Mixing disabled for now. Build successful first!"))
    );

    /* OLD FFMPEG CODE - COMMENTED OUT
    String dir = (await getExternalStorageDirectory())!.path;
    String output = "$dir/BlendJam_Mix_${DateTime.now().millisecondsSinceEpoch}.mp3";
    String inputs = ""; 
    String filter = "";
    for (int i = 0; i < playlist.length; i++) {
      inputs += "-i '${playlist[i].path}' ";
      if (i >
