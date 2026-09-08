import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';

void main() => runApp(const BlendJamApp());

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlendJam',
      theme: ThemeData().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: const DJPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DJPage extends StatefulWidget {
  const DJPage({super.key});
  @override
  State<DJPage> createState() => _DJPageState();
}

class _DJPageState extends State<DJPage> {
  late AudioPlayer playerA, playerB;
  String? fileAName, fileBName;
  double tempoA = 1.0, tempoB = 1.0;
  double volA = 0.8, volB = 0.8;
  double crossfade = 0.5;
  List<String> queuePaths = [], queueNames = [];
  bool autoMix = false;
  int autoMixIndex = 0;
  bool isTransitioning = false;

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer(); playerB = AudioPlayer();
    _updateVolumes();
    playerA.positionStream.listen((_) => _autoMixCheck());
  }

  @override
  void dispose() { playerA.dispose(); playerB.dispose(); super.dispose(); }

  void _updateVolumes() {
    playerA.setVolume(volA * (1.0 - crossfade) * 2.0 > 1.0? 1.0 : volA * (1.0 - crossfade) * 2.0);
    playerB.setVolume(volB * (crossfade) * 2.0 > 1.0? 1.0 : volB * crossfade * 2.0);
  }

  Future<void> _loadToDeck(bool isDeckA) async {
    String? path; String? name;
    if (queuePaths.isNotEmpty) {
      final sel = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pick a song'),
          content: SizedBox(width: double.maxFinite, height: 300,
            child: ListView.builder(
              itemCount: queueNames.length + 1,
              itemBuilder: (c,i) {
                if(i==queueNames.length) return ListTile(leading: const Icon(Icons.folder_open), title: const Text('Browse files'), onTap: ()=>Navigator.pop(c,-1));
                return ListTile(leading: const Icon(Icons.music_note), title: Text(queueNames[i]), onTap: ()=>Navigator.pop(c,i));
              },
            )),
        ));
      if(sel==null) return;
      if(sel==-1){ path=queuePaths[sel]; name=queueNames[sel]; }
    }
    if(path==null){
      FilePickerResult? r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
      if(r!=null && r.files.single.path!=null){ path=r.files.single.path; name=r.files.single.name; }
    }
    if(path==null||name==null) return;
    try{
      if(isDeckA){ await playerA.setFilePath(path); await playerA.setSpeed(tempoA); setState(()=>fileAName=name); }
      else { await playerB.setFilePath(path); await playerB.setSpeed(tempoB); setState(()=>fileBName=name); }
      _updateVolumes();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded $name to Deck ${isDeckA?'A':'B'}')));
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _addToQueue() async {
    FilePickerResult? r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if(r==null) return;
    setState((){
      for(var f in r.files){ if(f.path!=null){ queuePaths.add(f.path!); queueNames.add(f.name); } }
    });
  }

  void _autoMixCheck() async {
    if(!autoMix || isTransitioning || queuePaths.isEmpty) return;
    final dur = playerA.duration; final pos = playerA.position;
    if(dur==null) return;
    if(dur - pos < const Duration(seconds: 15)){
      isTransitioning = true;
      autoMixIndex = (autoMixIndex+1) % queuePaths.length;
      await playerB.setFilePath(queuePaths[autoMixIndex]);
      await playerB.setSpeed(tempoB);
      setState(()=>fileBName=queueNames[autoMixIndex]);
      playerB.play();
      for(int i=0;i<10;i++){
        await Future.delayed(const Duration(seconds: 1));
        if(!autoMix) break;
        setState(()=>crossfade = i/10);
        _updateVolumes();
      }
      await playerA.stop();
      await playerA.setFilePath(queuePaths[autoMixIndex]);
      playerA.play();
      setState(()=>{fileAName=queueNames[autoMixIndex], crossfade = 0.0});
      _updateVolumes();
      isTransitioning = false;
    }
  }

  Widget _waveform(bool isA){
    final player = isA? playerA : playerB;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (c,snap){
        final pos = snap.data?.inMilliseconds?? 0;
        final rand = Random(pos ~/ 500 + (isA?0:999));
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(30, (i){
            final h = 8 + rand.nextDouble()*32;
            return Container(width: 4, height: h, margin: const EdgeInsets.symmetric(horizontal:1.5),
              decoration: BoxDecoration(color: isA?Colors.deepPurpleAccent:Colors.orangeAccent, borderRadius: BorderRadius.circular(2)));
          }),
        );
      });
