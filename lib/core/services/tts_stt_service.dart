import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class TtsSttService {
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();

  TtsSttService() {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> startListening(Function(String) onResult) async {
    bool available = await _speechToText.initialize();
    if (available) {
      _speechToText.listen(onResult: (val) {
        //Check if the recognized words string is not empty
        if (val.recognizedWords.isNotEmpty) {
          onResult(val.recognizedWords);
        }
      });
    }
  }
}