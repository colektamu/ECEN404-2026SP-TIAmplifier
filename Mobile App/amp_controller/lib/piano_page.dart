// piano_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import 'app_locale.dart';

class PianoPage2Octaves extends StatefulWidget {
  const PianoPage2Octaves({super.key});

  @override
  State<PianoPage2Octaves> createState() => _PianoPage2OctavesState();
}

class _PianoPage2OctavesState extends State<PianoPage2Octaves> {
  final AudioPlayer player = AudioPlayer();
  final Set<String> activeNotes = {};

  final List<String> whiteNotes = [
    'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4',
    'C5', 'D5', 'E5', 'F5', 'G5', 'A5', 'B5'
  ];

  final List<String> blackNotes = [
    'Db4', 'Eb4', 'Gb4', 'Ab4', 'Bb4',
    'Db5', 'Eb5', 'Gb5', 'Ab5', 'Bb5'
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> playNote(String note) async {
    try {
      setState(() => activeNotes.add(note));
      await player.stop();
      await player.play(AssetSource('piano/$note.mp3'));
      player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => activeNotes.remove(note));
      });
    } catch (e) {
      debugPrint('Error playing $note: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const double whiteKeyWidth = 90;
    const double whiteKeyHeight = 240;
    const double blackKeyWidth = 55;
    const double blackKeyHeight = 150;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            "Piano (C4–B5)",
            "钢琴（C4–B5）",
            "Piano (C4–B5)",
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Stack(
            children: [
              Row(
                children: whiteNotes.map((note) {
                  final isActive = activeNotes.contains(note);
                  return GestureDetector(
                    onTapDown: (_) => playNote(note),
                    onTapUp: (_) => setState(() => activeNotes.remove(note)),
                    child: Container(
                      width: whiteKeyWidth,
                      height: whiteKeyHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.blue[100] : Colors.white,
                        border: Border.all(color: Colors.black, width: 1.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        note,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              /// BLACK KEYS
              Positioned(
                top: 0,
                child: Row(
                  children: whiteNotes.map((note) {
                    final prefix = note[0];
                    final octave = note.substring(note.length - 1);
                    String? flatKey;

                    if (prefix == 'C') flatKey = 'Db$octave';
                    else if (prefix == 'D') flatKey = 'Eb$octave';
                    else if (prefix == 'F') flatKey = 'Gb$octave';
                    else if (prefix == 'G') flatKey = 'Ab$octave';
                    else if (prefix == 'A') flatKey = 'Bb$octave';

                    if (flatKey != null && blackNotes.contains(flatKey)) {
                      final isActive = activeNotes.contains(flatKey);
                      return Container(
                        width: whiteKeyWidth,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTapDown: (_) => playNote(flatKey!),
                          onTapUp: (_) =>
                              setState(() => activeNotes.remove(flatKey)),
                          child: Container(
                            width: blackKeyWidth,
                            height: blackKeyHeight,
                            margin:
                                const EdgeInsets.only(left: 30, right: 30),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.blueGrey[700]
                                  : Colors.black,
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox(width: whiteKeyWidth);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
