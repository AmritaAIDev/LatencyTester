import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latency_tester/constants/constants.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class LatencyTestPage extends StatefulWidget {
  final String voiceService;
  final String llmModel;

  const LatencyTestPage({
    required this.voiceService,
    required this.llmModel,
  });

  @override
  _LatencyTestPageState createState() => _LatencyTestPageState();
}

class _LatencyTestPageState extends State<LatencyTestPage> {
  //stt.SpeechToText? _speech;
  final FlutterTts _tts = FlutterTts();
  final Record _recorder = Record();
  String recognizedText = "";
  String llmResponse = "";
  Duration voiceLatency = Duration.zero;
  Duration llmLatency = Duration.zero;
  bool isRecording = false;
  bool isProcessing = false;
  stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    //_speech = stt.SpeechToText();
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      setState(() {
        isRecording = true;
      });
      await _recorder.start();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Recording permission denied.")),
      );
    }
  }

  Future<void> _stopRecording() async {
    final audioPath = await _recorder.stop();
    setState(() {
      isRecording = false;
    });

    if (audioPath != null) {
      print("Audio path: $audioPath");
      if (audioPath.startsWith('blob:')) {
        // Fetch the blob data
        final audioBytes = await _fetchBlobData(audioPath);
        await _processAudio(audioBytes);
      } else {
        // Handle non-web platforms
        //await _processAudio(audioPath);
      }
    }
  }

  Future<Uint8List> _fetchBlobData(String blobUrl) async {
    final response = await http.get(Uri.parse(blobUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to fetch audio blob: ${response.statusCode}');
    }
  }

  Future<void> _processAudio(Uint8List audioBytes) async {
    setState(() {
      isProcessing = true;
      recognizedText = "";
      llmResponse = "";
      voiceLatency = Duration.zero;
      llmLatency = Duration.zero;
    });

    // Send audio to the selected Voice-to-Voice service (Speech-to-Text)
    final voiceStart = Stopwatch()
      ..start();
    switch (widget.voiceService) {
    // case "Flutter Package":
    //   recognizedText = await _transcribeWithFlutter();
    //   break;
      case "Azure Speech":
      //recognizedText = await _transcribeWithAzure(audioPath);
        break;
      case "Google Speech":
        recognizedText = await _transcribeWithGoogle(audioBytes);
        print('recognizedText: $recognizedText');
        break;
      case "OpenAI Whisper":
      //recognizedText = await _transcribeWithWhisper(audioPath);
        break;
      default:
      //recognizedText = "Unsupported service selected";
    }
    voiceLatency = voiceStart.elapsed;
    final llmStart = Stopwatch()
      ..start();
    var response = await _sendToLLM(
        recognizedText); // Replace with actual LLM API call
    setState(() {
      llmResponse = response;
    });
    print('LLM Response: $llmResponse');
    llmLatency = llmStart.elapsed;

    // Generate voice response using the selected Voice-to-Voice service (Text-to-Speech)
    await _generateVoiceResponse(llmResponse);

    setState(() {
      isProcessing = false;
    });
  }

  Future<String> _sendToLLM(String inputText) async {
    final apiKey = Constants.openaiApiKey; // Replace with your OpenAI API key
    final url = Constants.CHAT;

    final requestPayload = {
      "model": "gpt-3.5-turbo",
      // Replace with your LLM model (e.g., GPT-4, etc.)
      "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": inputText}
      ],
      "temperature": 0.7
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(requestPayload),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final reply = responseData['choices'][0]['message']['content'];
      return reply;
    } else {
      print("Error: ${response.body}");
      throw Exception("Failed to get response from LLM: ${response.body}");
    }
  }


  Future<void> _generateVoiceResponse(String message) async {
    switch (widget.voiceService) {
      case "Azure Speech":
      // TODO: Integrate Azure TTS API
        break;
      case "Google Speech":
        await _googleTextToSpeech(message);
        break;
      case "OpenAI Whisper":
      // TODO: Integrate Whisper for TTS
        break;
      default:
      // Use Flutter TTS as fallback
        var res = await _tts.speak(message);
        setState(() {
          _isSpeaking = true;
        });
        print(res);
    }
  }

  Future<void> _testVoiceService() async {
    // if (!_speech!.isAvailable) {
    //   await _speech!.initialize();
    // }

    final stopwatch = Stopwatch()
      ..start();

    // await _speech!.listen(onResult: (result) {
    //   setState(() {
    //     recognizedText = result.recognizedWords;
    //     voiceLatency = stopwatch.elapsed;
    //   });
    // });
    //
    // await Future.delayed(Duration(seconds: 2)); // Simulate listening duration
    // _speech!.stop();
  }

  Future<void> _testLLMModel() async {
    final stopwatch = Stopwatch()
      ..start();

    // Simulate API call to LLM model
    await Future.delayed(Duration(seconds: 2)); // Replace with actual API call
    setState(() {
      llmResponse = "Simulated LLM Response for '${recognizedText}'";
      llmLatency = stopwatch.elapsed;
    });
  }

  Future<void> _stopRecordingFlutter() async {
    setState(() {
      isRecording = false;
    });
    print("_stopRecordingFlutter()");
    await _speechToText.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Latency Test Results'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Voice-to-Voice Service: ${widget.voiceService}",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "LLM Model: ${widget.llmModel}",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            if (isRecording)
              ElevatedButton(
                onPressed: widget.voiceService != "Flutter Package"
                    ? _stopRecording
                    : _stopRecordingFlutter,
                child: Text("Stop Recording"),
              )
            else
              if (!isRecording && widget.voiceService != "Flutter Package")
                ElevatedButton(
                  onPressed: _startRecording,
                  child: Text("Start Recording"),
                )
              else
                ElevatedButton(
                  onPressed: _transcribeWithFlutter,
                  child: Text("Start Recording"),
                ),
            if (isProcessing)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            SizedBox(height: 32),
            Text("Recognized Text: $recognizedText"),
            Row(
              children: [
                Flexible(child: Text("LLM Response: $llmResponse")),
                // IconButton(
                //     onPressed: _isSpeaking
                //         ? () async {
                //       await _stopVoiceResponse();
                //     }
                //         : () async {
                //       await _generateVoiceResponse(llmResponse);
                //     },
                //     icon: _isSpeaking
                //         ? Icon(Icons.volume_off)
                //         : Icon(Icons.volume_up))
              ],
            ),
            SizedBox(height: 16),
            // Text("Voice Service Latency: ${voiceLatency.inMilliseconds} ms"),
            // Text("LLM Model Latency: ${llmLatency.inMilliseconds} ms"),
          ],
        ),
      ),
    );
  }

  _transcribeWithWhisper(String audioPath) {}

  _transcribeWithAzure(String audioPath) {}

  Future<String> _transcribeWithGoogle(Uint8List audioBytes) async {
    final jsonString = await rootBundle.loadString(
        'assets/speech-to-text-service.json');
    final jsonKey = jsonDecode(jsonString);

    final accessToken = await _getGoogleAccessToken(jsonKey);
    print("Access Token: $accessToken");

    final audioContent = base64Encode(audioBytes);

    final requestPayload = {
      "config": {
        "encoding": "WEBM_OPUS", // Adjust based on your audio file format
        "sampleRateHertz": 48000, // Adjust based on your audio file
        "languageCode": "en-US"
      },
      "audio": {
        "content": audioContent,
      }
    };

    final response = await http.post(
      Uri.parse('https://speech.googleapis.com/v1/speech:recognize'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestPayload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final transcription = data['results'][0]['alternatives'][0]['transcript'];
      print('Transcription: $transcription');
      return transcription;
    } else {
      print('Error: ${response.body}');
      throw Exception('Failed to transcribe audio: ${response.body}');
    }
  }


  Future<String> _getGoogleAccessToken(Map<String, dynamic> jsonKey) async {
    final accountCredentials = ServiceAccountCredentials.fromJson(
        jsonEncode(jsonKey));

    // Define the scope for the Google Cloud APIs
    const scopes = ['https://www.googleapis.com/auth/cloud-platform'];

    // Obtain an authenticated client
    final client = http.Client();
    final authenticatedClient = await clientViaServiceAccount(
        accountCredentials, scopes);

    // Extract the access token from the authenticated client
    final accessToken = authenticatedClient.credentials.accessToken.data;

    client.close(); // Close the client to free resources
    return accessToken;
  }


  void _initSpeech() async {
    print("_initSpeech");
    bool available = await _speechToText.initialize();

    print("available:$available");
    setState(() {
      _speechEnabled = available;
    });
  }

  void _transcribeWithFlutter() async {
    setState(() {
      isRecording = true;
    });
    await _speechToText.listen(onResult: _onSpeechResult);
    print("_speechToText.isListening ,${_speechToText.isListening}");
    setState(() {});
  }

  //
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      recognizedText = result.recognizedWords;
    });

    print("recognizedText:$recognizedText");
  }

  Future<void> _stopVoiceResponse() async {
    switch (widget.voiceService) {
      case "Azure Speech":
      // TODO: Integrate Azure TTS API
        break;
      case "Google Speech":
      // TODO: Integrate Google TTS API
        break;
      case "OpenAI Whisper":
      // TODO: Integrate Whisper for TTS
        break;
      default:
      // Use Flutter TTS as fallback
        var res = await _tts.stop();
        setState(() {
          _isSpeaking = false;
        });
        print(res);
    }
  }

  Future<void> _googleTextToSpeech(String text) async {
    final jsonString = await rootBundle.loadString(
        'assets/speech-to-text-service.json');
    final jsonKey = jsonDecode(jsonString);

    // Generate an access token using the service account
    final accessToken = await _getGoogleAccessToken(jsonKey);
    print("Access Token: $accessToken");

    // Prepare the TTS API request payload
    final requestPayload = {
      "input": {"text": text},
      "voice": {
        "languageCode": "en-US", // Specify language and voice type
        "name": "en-US-Wavenet-D" // Replace with a desired Wavenet voice
      },
      "audioConfig": {
        "audioEncoding": "MP3" // Specify audio encoding
      }
    };

    // Send the request to Google TTS API
    final response = await http.post(
      Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestPayload),
    );

    // Process the response
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final audioContent = data['audioContent'];

      // Decode the audio content (Base64)
      final audioBytes = base64Decode(audioContent);

      // Play the audio using an audio player
      await _playAudio(audioBytes);
    } else {
      print("Error in Google TTS API: ${response.body}");
      throw Exception('Failed to synthesize speech: ${response.body}');
    }
  }

  Future<void> _playAudio(Uint8List audioBytes) async {
    final audioPlayer = AudioPlayer();
    await audioPlayer.play(BytesSource(audioBytes));
  }
}