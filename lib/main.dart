import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io'; // <-- NEEDED FOR File()

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlendJam',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> playlist = []; // <-- DECLARE playlist HERE

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true, // so you can pick many songs
    );

    if (result != null) {
      setState(() { // <-- NOW setState WILL WORK
        playlist = result.paths.map((path) => File(path!)).toList(); // <-- LINE 64
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar( // <-- context WORKS NOW
        const SnackBar(content: Text('No file selected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlendJam')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickAudio,
              child: const Text('Pick Audio Files'),
            ),
            const SizedBox(height: 20),
            Text("Selected: ${playlist.length} songs"), // <-- playlist WORKS NOW
            if (playlist.length < 2) // <-- LINE 70
              const Text("Pick at least 2 songs to mix"),
          ],
        ),
      ),
    );
  }
} // <-- MAKE SURE THIS IS THE ONLY CLOSING BRACE FOR _HomeScreenState    if (result != null) {
      // Do something with result.files.first.path
      print(result.files.first.name);
    } else {
      // User canceled the picker
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlendJam')),
      body: Center(
        child: ElevatedButton(
          onPressed: _pickAudio,
          child: const Text('Pick Audio'),
        ),
      ),
    );
  }
}  Future<void> pickSongs() async {
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
