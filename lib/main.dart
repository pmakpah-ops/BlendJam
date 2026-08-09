import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlendJam',
      debugShowCheckedModeBanner: false,
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
  List<File> playlist = []; // This fixes "Setter not found: playlist"

  Future<void> _pickAudio() async { // This fixes "Undefined name _pickAudio"
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() { // This fixes "Method not found: setState"
        playlist = result.paths.map((path) => File(path!)).toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) { // ONLY ONE build function
    return Scaffold(
      appBar: AppBar(title: const Text('BlendJam')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickAudio, // Now this will work
              child: const Text('Pick Audio Files'),
            ),
            const SizedBox(height: 20),
            Text("Selected: ${playlist.length} songs"),
            if (playlist.length < 2)
              const Text("Pick at least 2 songs to mix"),
          ],
        ),
      ),
    );
  }
} // Only 1 closing brace here  Widget build(BuildContext context) {
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
