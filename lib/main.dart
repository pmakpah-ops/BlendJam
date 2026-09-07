import 'package:flutter/material.dart';

void main() {
  runApp(const BlendJamApp());
}

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlendJam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DJHomePage(),
    );
  }
}

class DJHomePage extends StatefulWidget {
  const DJHomePage({super.key});
  @override
  State<DJHomePage> createState() => _DJHomePageState();
}

class _DJHomePageState extends State<DJHomePage> {
  double crossfade = 0.5;
  double tempoA = 1.0;
  double tempoB = 1.0;
  bool isPlayingA = false;
  bool isPlayingB = false;
  bool autoMix = false;
  int currentTrackIndex = 0;

  final List<String> tracks = List.generate(30, (i) => "Track ${i + 1} - DJ Mix ${i + 1}");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlendJam DJ Mixer'),
        backgroundColor: Colors.deepPurple,
        actions: [
          Switch(
            value: autoMix,
            onChanged: (v) => setState(() => autoMix = v),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12, top: 16),
            child: Text('Auto Mix'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(child: _buildDeck('DECK A', isPlayingA, tempoA, (v) {
                  setState(() => tempoA = v);
                }, () {
                  setState(() => isPlayingA = !isPlayingA);
                }, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildDeck('DECK B', isPlayingB, tempoB, (v) {
                  setState(() => tempoB = v);
                }, () {
                  setState(() => isPlayingB = !isPlayingB);
                }, Colors.red)),
              ],
            ),
          ),
