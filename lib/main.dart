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
    if (result != null) {
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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Mixing disabled for now. Build successful first!"))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("BlendJam DJ")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: pickSongs, child: Text("Pick Songs")),
            SizedBox(height: 20),
            Text("Selected: ${playlist.length} songs"),
            SizedBox(height: 20),
            ElevatedButton(onPressed: exportMix, child: Text("Export Mix")),
          ],
        ),
      ),
    );
  }
}
