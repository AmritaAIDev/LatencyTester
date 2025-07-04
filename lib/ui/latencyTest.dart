import 'dart:async';
import 'dart:convert';
import 'dart:developer' as console;
import 'dart:io';
//import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';

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
import 'package:universal_html/html.dart' as html;

class LatencyTestPage extends StatefulWidget {
  final String voiceService;
  //final String llmModel;
  final String langauge;

  const LatencyTestPage({
    required this.voiceService,
    //required this.llmModel,
    required this.langauge,
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
  String bhasiniResponse = "";
  Duration voiceLatency = Duration.zero;
  Duration llmLatency = Duration.zero;
  bool isRecording = false;
  bool isProcessing = false;
  stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isSpeaking = false;
  bool _isAudioPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
      String mimeType = '';
      if (html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
        mimeType = 'audio/webm;codecs=opus';
      } else if (html.MediaRecorder.isTypeSupported('audio/mp4')) {
        mimeType = 'audio/mp4';
      } else if (html.MediaRecorder.isTypeSupported('audio/aac')) {
        mimeType = 'audio/aac';
      } else {
        //print("isRunning on Iphone:-$isRunningOnIphone()");
        mimeType = ''; // Let browser choose
      }

      print("Using mime type: $mimeType"); //webm
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

    if(_isAudioPlaying) {
      _stopVoiceResponse();
    }
    if (audioPath != null) {
      print("Audio path: $audioPath");
      if (audioPath.startsWith('blob:')) {
        // Fetch the blob data
        console.log(audioPath);
        // final response = await http.get(Uri.parse(audioPath));
        //
        // if (response.statusCode == 200) {
        //   final contentType = response.headers['content-type'];
        //   print('MIME Type: $contentType');  // e.g., audio/wav, audio/mpeg
        // }
        // final audioBytes = await _fetchBlobData(audioPath);
        // await _processAudio(audioBytes);

        //final base64String = await audioUrlToBase64(audioPath);
        final base64String = await blobUrlToBase64(audioPath);
        console.log(base64String);
        await callBhasiniASR(base64String);
      } else {
        // Handle non-web platforms
        //await _processAudio(audioPath);
      }
    }
  }

  Future<String> blobUrlToBase64(String blobUrl) async {
    // Fetch blob from blob URL using JS interop
    final html.Blob blob = await html.window.fetch(blobUrl).then((r) => r.blob());

    final reader = html.FileReader();
    final completer = Completer<String>();

    reader.readAsDataUrl(blob); // Reads as: data:audio/webm;base64,...

    reader.onLoadEnd.listen((_) {
      final result = reader.result as String;
      console.log("mimetype:${result.split(',').first}");
      final base64 = result.split(',').last;
      completer.complete(base64);
    });

    return completer.future;
  }

  Future<String> audioUrlToBase64(String audioUrl) async {
    final response = await http.get(Uri.parse(audioUrl));

    if (response.statusCode == 200) {
      Uint8List audioBytes = response.bodyBytes;
      return base64Encode(audioBytes); // Base64 encoded audio
    } else {
      throw Exception('Failed to fetch audio: ${response.statusCode}');
    }
  }

  // Future<Uint8List> _fetchBlobData(String blobUrl) async {
  //   final response = await http.get(Uri.parse(blobUrl));
  //   if (response.statusCode == 200) {
  //     return response.bodyBytes;
  //   } else {
  //     throw Exception('Failed to fetch audio blob: ${response.statusCode}');
  //   }
  // }
  //
  // Future<void> _processAudio(Uint8List audioBytes) async {
  //   setState(() {
  //     isProcessing = true;
  //     recognizedText = "";
  //     llmResponse = "";
  //     voiceLatency = Duration.zero;
  //     llmLatency = Duration.zero;
  //   });
  //
  //
  //   final voiceStart = Stopwatch()
  //     ..start();
  //   switch (widget.voiceService) {
  //   // case "Flutter Package":
  //   //   recognizedText = await _transcribeWithFlutter();
  //   //   break;
  //     case "Azure Speech":
  //     //recognizedText = await _transcribeWithAzure(audioPath);
  //       break;
  //     case "Google Speech":
  //       recognizedText = await _transcribeWithGoogle(audioBytes);
  //       print('recognizedText: $recognizedText');
  //       break;
  //     case "OpenAI Whisper":
  //     //recognizedText = await _transcribeWithWhisper(audioPath);
  //       break;
  //     default:
  //     //recognizedText = "Unsupported service selected";
  //   }
  //   voiceLatency = voiceStart.elapsed;
  //   final llmStart = Stopwatch()
  //     ..start();
  //
  //   /*
  //   LLM part -currently commented
  //
  //   var response = await _sendToLLM(
  //       recognizedText); // Replace with actual LLM API call
  //   setState(() {
  //     llmResponse = response;
  //   });
  //   print('LLM Response: $llmResponse');
  //   llmLatency = llmStart.elapsed;
  //
  //   */
  //
  //   //var response = await _bhasiniResponse(recognizedText);
  //   // setState(() {
  //   //   bhasiniResponse = response;
  //   // });
  //
  //   // Generate voice response using the selected Voice-to-Voice service (Text-to-Speech)
  //   //await _generateVoiceResponse(llmResponse);
  //
  //   setState(() {
  //     isProcessing = false;
  //   });
  // }

  // Future<String> _sendToLLM(String inputText) async {
  //
  //   switch (widget.llmModel) {
  //
  //     case "GPT":
  //       return await _gptResponse(inputText);
  //
  //     case "Llama":
  //       return await _llamaResponse(inputText);
  //
  //     case "Gemini":
  //       return await _geminiResponse(inputText);
  //     default:
  //       return "Oops";
  //   }

  //}


  // Future<String> _geminiResponse(String inputText) async {
  //
  //   const String apiKey = Constants.geminiApiKey;
  //
  //   // Gemini API endpoint
  //   final String apiUrl =
  //       "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey";
  //
  //
  //   // Corrected request payload
  //   final Map<String, dynamic> requestPayload = {
  //     "model": "models/gemini-1.5-flash", // Specify the model explicitly
  //     "prompt": {
  //       "text": inputText // Input text for the model
  //     },
  //     "parameters": {
  //       "temperature": 0.7,    // Adjust creativity
  //       "maxOutputTokens": 100, // Limit response length
  //       "topP": 0.8           // Token sampling probability
  //     }
  //   };
  //
  //   try {
  //     // Send request to the Gemini API
  //     final http.Response response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: {
  //         "Content-Type": "application/json",
  //       },
  //       body: jsonEncode(requestPayload),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       // Parse the API response
  //       final Map<String, dynamic> responseData = jsonDecode(response.body);
  //       final String reply = responseData['candidates']?[0]?['output'] ?? "No response content";
  //       print("Gemini Response: $reply");
  //       return reply;
  //     } else {
  //       print("Gemini API Error: ${response.body}");
  //       throw Exception("Failed to get response from Gemini API: ${response.body}");
  //     }
  //   } catch (error) {
  //     print("Error: $error");
  //     throw Exception("Failed to communicate with Gemini API: $error");
  //   }
  // }

  // Future<String> _llamaResponse(String inputText) async {
  //   final apiUrl = "https://api-inference.huggingface.co/models/meta-llama/Llama-3.3-70B-Instruct"; // Model endpoint
  //   final apiKey = Constants.lLamaApiKey; // Replace with your API key
  //
  //   print("input text: $inputText");
  //
  //   // Request payload
  //   final requestPayload = {
  //     "inputs": inputText,
  //     "parameters": {
  //       "max_new_tokens": 150, // Maximum response length
  //       "temperature": 0.7,   // Controls creativity
  //     }
  //   };
  //
  //   try {
  //     // Send request to Hugging Face Inference API
  //     final response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: {
  //         "Authorization": "Bearer $apiKey", // API key for authentication
  //         "Content-Type": "application/json",
  //       },
  //       body: jsonEncode(requestPayload),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       // Parse the response
  //       final responseData = jsonDecode(response.body);
  //       final reply = responseData[0]['generated_text']; // Adjust key based on API's response
  //       print("LLaMA Response: $reply");
  //       return reply;
  //     } else {
  //       print("Error: ${response.body}");
  //       throw Exception("Failed to get response from LLaMA: ${response.body}");
  //     }
  //   } catch (error) {
  //     print("Error: $error");
  //     throw Exception("Failed to communicate with Hugging Face API: $error");
  //   }
  // }

  // Future<String> _gptResponse(String inputText) async {
  //   final apiKey = Constants.openaiApiKey;
  //   final url = Constants.CHAT;
  //
  //   final requestPayload = {
  //     "model": "gpt-3.5-turbo",
  //     // Replace with your LLM model (e.g., GPT-4, etc.)
  //     "messages": [
  //       {"role": "system", "content": "You are a helpful assistant."},
  //       {"role": "user", "content": inputText}
  //     ],
  //     "temperature": 0.7
  //   };
  //
  //   final response = await http.post(
  //     Uri.parse(url),
  //     headers: {
  //       "Authorization": "Bearer $apiKey",
  //       "Content-Type": "application/json",
  //     },
  //     body: jsonEncode(requestPayload),
  //   );
  //
  //   if (response.statusCode == 200) {
  //     final responseData = jsonDecode(response.body);
  //     final reply = responseData['choices'][0]['message']['content'];
  //     return reply;
  //   } else {
  //     print("Error: ${response.body}");
  //     throw Exception("Failed to get response from LLM: ${response.body}");
  //   }
  // }
  //
  // Future<void> _generateVoiceResponse(String message) async {
  //   switch (widget.voiceService) {
  //     case "Azure Speech":
  //     // TODO: Integrate Azure TTS API
  //       break;
  //     case "Google Speech":
  //       await _googleTextToSpeech(message);
  //       break;
  //     case "OpenAI Whisper":
  //     // TODO: Integrate Whisper for TTS
  //       break;
  //     default:
  //     // Use Flutter TTS as fallback
  //       var res = await _tts.speak(message);
  //       setState(() {
  //         _isSpeaking = true;
  //       });
  //       print(res);
  //   }
  // }


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
        title: Text('Recording page'),
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
            // Text(
            //   "LLM Model: ${widget.llmModel}",
            //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            // ),
            Text(
              "Langauge: ${widget.langauge}",
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
            // const Text("Recognized Text:",style: TextStyle(fontWeight: FontWeight.bold),),
            // Text("$recognizedText"),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text("Recognized Text:",style: TextStyle(fontWeight: FontWeight.bold),),
                Text("$recognizedText"),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text("Translated text: ",style: TextStyle(fontWeight: FontWeight.bold),),
                Flexible(child: Text("$bhasiniResponse")),
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


  // Future<String> _transcribeWithGoogle(Uint8List audioBytes) async {
  //   final jsonString = await rootBundle.loadString(
  //       'assets/speech-to-text-service.json');
  //   final jsonKey = jsonDecode(jsonString);
  //
  //   final accessToken = await _getGoogleAccessToken(jsonKey);
  //   print("Access Token: $accessToken");
  //
  //   final audioContent = base64Encode(audioBytes);
  //
  //   final requestPayload = {
  //     "config": {
  //       "encoding": "WEBM_OPUS", // Adjust based on your audio file format
  //       "sampleRateHertz": 48000, // Adjust based on your audio file
  //       "languageCode": "en-US"
  //     },
  //     "audio": {
  //       "content": audioContent,
  //     }
  //   };
  //
  //
  //   //Google STT API
  //   final response = await http.post(
  //     Uri.parse('https://speech.googleapis.com/v1/speech:recognize'),
  //     headers: {
  //       'Authorization': 'Bearer $accessToken',
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode(requestPayload),
  //   );
  //
  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body);
  //     final transcription = data['results'][0]['alternatives'][0]['transcript'];
  //     print('Transcription: $transcription');
  //     return transcription;
  //   } else {
  //     print('Error: ${response.body}');
  //     throw Exception('Failed to transcribe audio: ${response.body}');
  //   }
  // }


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
    print("_stopVoiceResponse().");
    switch (widget.voiceService) {
      case "Azure Speech":
      // TODO: Integrate Azure TTS API
        break;
      case "Google Speech":
        if (_isAudioPlaying) {
          await _audioPlayer.stop(); // Stop the audio player
          setState(() {
            _isAudioPlaying = false; // Update the state
          });
          print("Google Speech playback stopped.");
        }
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

  // Future<void> _googleTextToSpeech(String text) async {
  //   final jsonString = await rootBundle.loadString(
  //       'assets/speech-to-text-service.json');
  //   final jsonKey = jsonDecode(jsonString);
  //
  //   // Generate an access token using the service account
  //   final accessToken = await _getGoogleAccessToken(jsonKey);
  //   print("Access Token: $accessToken");
  //
  //   // Prepare the TTS API request payload
  //   final requestPayload = {
  //     "input": {"text": text},
  //     "voice": {
  //       "languageCode": "en-US", // Specify language and voice type
  //       "name": "en-US-Wavenet-D" // Replace with a desired Wavenet voice
  //     },
  //     "audioConfig": {
  //       "audioEncoding": "MP3" // Specify audio encoding
  //     }
  //   };
  //
  //   // Send the request to Google TTS API
  //   final response = await http.post(
  //     Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize'),
  //     headers: {
  //       'Authorization': 'Bearer $accessToken',
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode(requestPayload),
  //   );
  //
  //   // Process the response
  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body);
  //     final audioContent = data['audioContent'];
  //
  //     // Decode the audio content (Base64)
  //     final audioBytes = base64Decode(audioContent);
  //
  //     // Play the audio using an audio player
  //     await _playAudio(audioBytes);
  //   } else {
  //     print("Error in Google TTS API: ${response.body}");
  //     throw Exception('Failed to synthesize speech: ${response.body}');
  //   }
  // }

  Future<void> _playAudio(Uint8List audioBytes) async {
    //final audioPlayer = AudioPlayer();
    try {
      setState(() {
        _isAudioPlaying = true;
        //isRecording = true;
      });
      await _audioPlayer.play(BytesSource(audioBytes));
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isAudioPlaying = false; // Reset when playback completes
        });
      });
    } catch (error) {
      print("Error playing audio: $error");
    }
  }

  // Future<String> _bhasiniResponse(String inputText) async {
  //
  //   final authorisationKey = Constants.authorisationKey;
  //   //url = ;
  //
  //   final requestPayload = {
  //     "pipelineTasks": [
  //       {
  //         "taskType": "translation",
  //         "config": {
  //           "language": {
  //             "sourceLanguage": "en",
  //             "targetLanguage": "hi"
  //           }
  //         }
  //       }
  //     ],
  //     "inputData": {
  //       "input": [
  //         {
  //           "source": '$recognizedText'
  //         }
  //       ]
  //     },
  //     "pipelineRequestConfig": {
  //       "pipelineId": "64392f96daac500b55c543cd"
  //     }
  //   };
  //
  //   final response = await http.post(
  //     Uri.parse(Constants.BHASINI_URL),
  //     headers: {
  //       "Authorization": '$authorisationKey',
  //       "Content-Type": "application/json",
  //     },
  //     body: jsonEncode(requestPayload),
  //   );
  //
  //   if (response.statusCode == 200) {
  //     console.log("API sucess");
  //     final decodedBody = utf8.decode(response.bodyBytes);
  //     final jsonData = jsonDecode(decodedBody);
  //     console.log('${jsonData.runtimeType}');
  //     final Map<String, dynamic> data = jsonData;
  //     console.log('${data}');
  //     //console.log('${data[]}');
  //     console.log(data['pipelineResponse'][0]['output'][0]['target']);
  //     //console.log('datatype:${responseData.runtimeType}');
  //     // final reply = responseData['choices'][0]['message']['content'];
  //     // return reply;
  //     return data['pipelineResponse'][0]['output'][0]['target'];
  //   } else {
  //     print("Error: ${response.body}");
  //     throw Exception("Failed to get response from Bhasini: ${response.body}");
  //   }
  // }

  Future<void> callBhasiniASR(String base64string) async {

    setState(() {
      isProcessing = true;
      recognizedText = "";
      llmResponse = "";
      voiceLatency = Duration.zero;
      llmLatency = Duration.zero;
    });

    final authorisationKey = Constants.authorisationKey;
    //url = ;

    final requestPayload = {
      "pipelineTasks": [
        {
          "taskType": "asr",
          "config": {
            "language": {
              "sourceLanguage": "hi"
            },
            //"pipelineId": "64392f96daac500b55c543cd",
            "serviceId": "bhashini/ai4bharat/conformer-multilingual-asr",
            "audioFormat": "webm",
            "samplingRate": 48000,
            "postprocessors": [
              "itn"
            ]
          }
        },
        {
          "taskType": "translation",
          "config": {
            "language": {
              "sourceLanguage": "hi",
              "targetLanguage": "en"
            },
            "serviceId": "ai4bharat/indictrans-v2-all-gpu--t4"
          }
        }
      ],
      "inputData": {
        "audio": [
          {
            "audioContent": base64string
          }
        ]
      }
    };

    final response = await http.post(
      Uri.parse(Constants.BHASINI_URL),
      headers :
      {'Authorization': authorisationKey,
        "ulcaApiKey": "241a980cc4-224b-4ab2-8845-d1a75281b458",
        "Content-Type": "application/json",
        "userID":"4158ee12a8814b4283a059c921f16cf8"
      },
      body: jsonEncode(requestPayload),
    );

    if (response.statusCode == 200) {
      console.log("API sucess");
      final decodedBody = utf8.decode(response.bodyBytes);
      final jsonData = jsonDecode(decodedBody);
      console.log('${jsonData.runtimeType}');
      final Map<String, dynamic> data = jsonData;
      console.log('${data}');
      //console.log('${data[]}');
      //console.log(data['pipelineResponse'][0]['output'][0]['target']);
      setState(() {
        recognizedText = data['pipelineResponse'][0]['output'][0]['source'];
        bhasiniResponse = data['pipelineResponse'][1]['output'][0]['target'];
        isProcessing = false;

      });

    } else {
      print("Error: ${response.body}");
      throw Exception("Failed to get response from ASR API: ${response.body}");
    }

    // var convertedText = await _bhasiniResponse(recognizedText);


  }

}