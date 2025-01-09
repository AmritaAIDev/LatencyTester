import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ui/latencyTest.dart';
//import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Latency Tester',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SelectionPage(),
    );
  }
}

class SelectionPage extends StatefulWidget {
  @override
  _SelectionPageState createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  String? selectedVoiceService;
  String? selectedLLMModel;

  final List<String> voiceServices = [
    "Flutter Package",
    "Azure Speech",
    "Google Speech",
    "OpenAI Whisper",
    "11 Labs",
  ];

  final List<String> llmModels = [
    "GPT",
    "Llama",
    "Gemini",
  ];

  void _navigateToTestPage() {
    if (selectedVoiceService != null && selectedLLMModel != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LatencyTestPage(
            voiceService: selectedVoiceService!,
            llmModel: selectedLLMModel!,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select both a Voice Service and an LLM Model.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Services for Latency Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedLLMModel,
              items: llmModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedLLMModel = value),
              decoration: InputDecoration(
                labelText: "Select LLM Model",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: selectedVoiceService,
              items: voiceServices.map((service) {
                return DropdownMenuItem<String>(
                  value: service,
                  child: Text(service),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedVoiceService = value),
              decoration: InputDecoration(
                labelText: "Select Voice-to-Voice Service",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _navigateToTestPage,
              child: Text("Start Latency Test"),
            ),
          ],
        ),
      ),
    );
  }
}


