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
  List<File> playlist = []; // 1. DECLARE VARIABLE HERE

  Future<void> _pickAudio() async { // 2. FUNCTION INSIDE CLASS
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() { // 3. setState WORKS HERE
        playlist = result.paths.where((p) => p != null).map((p) => File(p!)).toList();
      });
    } else {
      if (mounted) { // safe way to use context
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) { // 4. ONLY ONE BUILD
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
            Text("Selected: ${playlist.length} songs"), // playlist WORKS HERE
            if (playlist.length < 2)
              const Text("Pick at least 2 songs to mix"),
          ],
        ),
      ),
    );
  }
} // END OF CLASS
