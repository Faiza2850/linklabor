import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'verification_screen.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  const WorkerRegistrationScreen({super.key});

  @override
  State<WorkerRegistrationScreen> createState() =>
      _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ================= CONTROLLERS =================
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  // ================= DROPDOWN STATE =================
  String? _selectedCity;
  String? _selectedSkill;
  String? _selectedDuration;

  // --- AI INTEGRATION: IMAGE STATE VARIABLES ---
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // --- AI INTEGRATION: VOICE ASSISTANT VARIABLES ---
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;

  bool _isVoiceAssistantActive = false;
  String _voicePrompt = "";
  String _userSpokenText = "";

  // ================= DROPDOWN DATA =================
  final List<String> _cities = ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi'];
  final List<String> _skills = ['Electrician', 'Plumber', 'Carpenter', 'Painter'];
  final List<String> _durations = ['1-3 Hours', '4-6 Hours', 'Full Day'];

  @override
  void initState() {
    super.initState();
    _initVoiceAssistant();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _aboutController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // ================= VOICE ASSISTANT SETUP =================
  void _initVoiceAssistant() async {
    _speechEnabled = await _speechToText.initialize();
    await _flutterTts.setLanguage("ur-PK");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    if (mounted) setState(() {});
  }

  // --- Speak Text Function ---
  Future<void> _speakText(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  // ================= THE BACKEND AI CONVERSATION LOGIC =================
  Future<void> _startVoiceFlow() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission is required."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isVoiceAssistantActive = true;
      _voicePrompt = "Aap kya kaam karte hain, kahan rehte hain, aur kitni der kaam chahiye?";
      _userSpokenText = "Listening...";
    });

    await _flutterTts.speak("Aap kya kaam karte hain, kahan rehte hain, aur kitni der kaam chahiye?");

    Completer<void> completer = Completer<void>();

    await _speechToText.listen(
      onResult: (result) async {
        setState(() {
          _userSpokenText = result.recognizedWords;
        });

        if (result.finalResult) {
          if (!completer.isCompleted) completer.complete();
          // SEND TEXT TO BACKEND!
          await _sendTextToPythonBackend(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: "ur-PK",
    );

    await completer.future;
  }

  // --- Send the text to Node.js / Python ---
  Future<void> _sendTextToPythonBackend(String text) async {
    try {
      setState(() {
        _voicePrompt = "AI is thinking...";
      });

      String backendUrl = "http://10.0.2.2:5000/api/process-voice";
      var response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text}),
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json['success'] == true) {
          var data = json['data'];

          // AUTO FILL THE UI!
          setState(() {
            if (data['skill'] != "") _selectedSkill = data['skill'];
            if (data['city'] != "") _selectedCity = data['city'];
            if (data['duration'] != "") _selectedDuration = data['duration'];

            _voicePrompt = "Done!";
          });

          await _flutterTts.speak("Shukriya! Aapki maloomat darj ho gayi hain.");
        }
      }
    } catch (e) {
      print("AI Backend Error: $e");
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isVoiceAssistantActive = false);
    }
  }

  void _stopVoiceAssistant() {
    _flutterTts.stop();
    _speechToText.stop();
    setState(() {
      _isVoiceAssistantActive = false;
    });
  }

  // --- AI INTEGRATION: CAMERA & SCAN LOGIC ---
  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo != null) {
      setState(() {
        _image = File(photo.path);
      });
      _scanCnic();
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Upload CNIC Image",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E8449),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF17A589)),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF17A589)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanCnic() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String backendUrl = "http://10.0.2.2:5000/api/verify-cnic";
      var request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.files.add(await http.MultipartFile.fromPath('cnic_image', _image!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          var data = json['data'];

          setState(() {
            if (data['name'] != null) {
              _nameController.text = data['name'];
            }
            if (data['cnic'] != null) {
              _cnicController.text = data['cnic'].replaceAll('-', '');
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("CNIC Scanned Successfully!"), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to read CNIC. Please try again."), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print("OCR Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection error. Is the server running?"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ================= NEXT BUTTON HANDLER =================
  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      final Map<String, String> workerData = {
        'fullName': _nameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _selectedCity ?? '',
        'skill': _selectedSkill ?? '',
        'availableHours': _selectedDuration ?? '',
        'about': _aboutController.text.trim(),
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(workerData: workerData),
        ),
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isVoiceAssistantActive ? _stopVoiceAssistant : _startVoiceFlow,
        backgroundColor: _isVoiceAssistantActive ? Colors.red : const Color(0xFF1E8449),
        icon: Icon(_isVoiceAssistantActive ? Icons.stop : Icons.mic, color: Colors.white),
        label: Text(_isVoiceAssistantActive ? "Stop Listening" : "Voice Assistant", style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_isVoiceAssistantActive)
                Card(
                  color: const Color(0xFFE8F8F5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Color(0xFF1E8449), width: 2)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.record_voice_over, color: Color(0xFF1E8449), size: 40),
                        const SizedBox(height: 10),
                        Text(_voicePrompt, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E8449)), textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        Text('"$_userSpokenText"', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black54), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              if (_isVoiceAssistantActive) const SizedBox(height: 20),

              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,  children: [
                          // Wrap the text in Flexible to prevent horizontal overflow
                          Flexible(
                            child: Text(
                              "Create your Profile",
                              textAlign: TextAlign.center, // Ensure text stays centered if it wraps
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E8449),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up, color: Color(0xFF1E8449)),
                            onPressed: () => _speakText("Apni profile banayein, as a worker"),
                          )
                        ],
                        ),
                        const Center(
                          child: Text(
                            "( As a Worker )",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF17A589),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        GestureDetector(
                          onTap: _showImageSourceOptions,
                          child: Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8F5),
                              border: Border.all(color: const Color(0xFF17A589), width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _image != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_image!, fit: BoxFit.cover),
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.document_scanner, size: 40, color: Color(0xFF1E8449)),
                                const SizedBox(height: 8),
                                const Text(
                                  "Tap to Auto-Fill via CNIC",
                                  style: TextStyle(
                                    color: Color(0xFF1E8449),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                    onPressed: () => _speakText("Apna shanakhti card scan karne ke liye yahan dabayein"),
                                    icon: const Icon(Icons.volume_up, size: 16),
                                    label: const Text("Sunye")
                                )
                              ],
                            ),
                          ),
                        ),

                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 15.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF1E8449),
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        // --- THE FIXED LABELS WITH URDU TEXT ---
                        _buildLabel("Enter your full name", "Apna mukammal naam darj karein"),
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration("e.g. Muhammad Ali"),
                          validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
                        ),

                        _buildLabel("Enter CNIC", "Apna shanakhti card number darj karein"),
                        TextFormField(
                          controller: _cnicController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration("e.g. 3720152676988"),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Enter CNIC";
                            if (v.length < 13) return "Invalid CNIC";
                            return null;
                          },
                        ),

                        _buildLabel("Enter Phone no.", "Apna phone number likhein"),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration("e.g. 03332343654"),
                          validator: (v) => v == null || v.isEmpty ? "Enter phone number" : null,
                        ),

                        _buildLabel("Select City", "Apna shehar muntakhib karein"),
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration("City"),
                          value: _selectedCity,
                          items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _selectedCity = v),
                          validator: (v) => v == null ? "Select a city" : null,
                        ),

                        _buildLabel("Select Skill", "Apna hunar ya kaam batayein"),
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration("Skill"),
                          value: _selectedSkill,
                          items: _skills.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _selectedSkill = v),
                          validator: (v) => v == null ? "Select a skill" : null,
                        ),

                        _buildLabel("Daily Availability", "Aap din mein kitni der kaam kar sakte hain?"),
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration("Duration"),
                          value: _selectedDuration,
                          items: _durations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (v) => setState(() => _selectedDuration = v),
                          validator: (v) => v == null ? "Select duration" : null,
                        ),

                        _buildLabel("About (Optional)", "Apne tajarbe ke baare mein mazeed batayein"),
                        TextFormField(
                          controller: _aboutController,
                          decoration: _inputDecoration("Tell us about your experience..."),
                          maxLines: 3,
                        ),

                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: _handleNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E8449),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Next",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================
  Widget _buildLabel(String text, String urduText) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          GestureDetector(
            onTap: () => _speakText(urduText),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.volume_up, size: 20, color: Color(0xFF17A589)),
            ),
          )
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E8449), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}