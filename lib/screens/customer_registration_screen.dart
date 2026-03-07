import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'customer/dashboard.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState extends State<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ================= CONTROLLERS & STATE =================
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedCity;
  File? _cnicFront;
  File? _cnicBack;
  File? _profilePic;

  static const String _baseUrl = "http://10.0.2.2:5000";
  static const double maxFileSizeKB = 500;

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isOcrLoading = false; // To show loading while AI reads CNIC

  final List<String> _cities = ["Karachi", "Lahore", "Islamabad", "Quetta", "Peshawar", "Multan", "Faisalabad", "Rawalpindi"];

  // ================= VOICE ASSISTANT VARIABLES =================
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isVoiceAssistantActive = false;
  String _voicePrompt = "";
  String _userSpokenText = "";

  @override
  void initState() {
    super.initState();
    _initVoiceAssistant();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // ================= VOICE ASSISTANT SETUP & LOGIC =================
  void _initVoiceAssistant() async {
    _speechEnabled = await _speechToText.initialize();
    await _flutterTts.setLanguage("ur-PK");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    if (mounted) setState(() {});
  }

  Future<void> _startVoiceFlow() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission is required."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isVoiceAssistantActive = true);

    // For the Customer, we only need to ask for the City!
    await _askAndListen(
        prompt: "Aap kis shehar mein rehte hain?",
        onProcessed: (text) {
          text = text.toLowerCase();
          if (text.contains('lahore')) _selectedCity = 'Lahore';
          else if (text.contains('karachi')) _selectedCity = 'Karachi';
          else if (text.contains('islamabad')) _selectedCity = 'Islamabad';
          else if (text.contains('rawalpindi') || text.contains('pindi')) _selectedCity = 'Rawalpindi';
          else if (text.contains('quetta')) _selectedCity = 'Quetta';
          else if (text.contains('peshawar')) _selectedCity = 'Peshawar';
          else if (text.contains('multan')) _selectedCity = 'Multan';
          else if (text.contains('faisalabad')) _selectedCity = 'Faisalabad';
        }
    );

    if (!_isVoiceAssistantActive) return;

    setState(() {
      _voicePrompt = "Shukriya!";
      _userSpokenText = "";
    });

    await _flutterTts.speak("Shukriya! Shehar darj ho gaya hai.");
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isVoiceAssistantActive = false);
  }

  Future<void> _askAndListen({required String prompt, required Function(String) onProcessed}) async {
    setState(() {
      _voicePrompt = prompt;
      _userSpokenText = "Listening...";
    });

    await _flutterTts.speak(prompt);
    Completer<void> completer = Completer<void>();

    await _speechToText.listen(
      onResult: (result) {
        setState(() => _userSpokenText = result.recognizedWords);
        if (result.finalResult) {
          onProcessed(result.recognizedWords);
          if (!completer.isCompleted) completer.complete();
        }
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 3),
      localeId: "ur-PK",
    );

    Future.delayed(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        _speechToText.stop();
        completer.complete();
      }
    });

    await completer.future;
  }

  void _stopVoiceAssistant() {
    _flutterTts.stop();
    _speechToText.stop();
    setState(() => _isVoiceAssistantActive = false);
  }

  // ================= IMAGE COMPRESSION & OCR LOGIC =================
  Future<File> _compressAndResize(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      String getTargetPath() => "${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg";
      var targetPath = getTargetPath();
      int quality = 80;

      XFile? resultXFile = await FlutterImageCompress.compressAndGetFile(
        file.path, targetPath, quality: quality, format: CompressFormat.jpeg,
      );

      if (resultXFile == null) return file;
      File resultFile = File(resultXFile.path);

      while (resultFile.lengthSync() / 1024 > maxFileSizeKB && quality > 10) {
        quality -= 15;
        targetPath = getTargetPath();
        resultXFile = await FlutterImageCompress.compressAndGetFile(
          file.path, targetPath, quality: quality, format: CompressFormat.jpeg,
        );
        if (resultXFile == null) break;
        resultFile = File(resultXFile.path);
      }
      return resultFile;
    } catch (_) {
      return file;
    }
  }

  Future<void> _pickImage(ImageSource source, Function(File) onSelect, {bool isCnicFront = false}) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final compressed = await _compressAndResize(File(picked.path));

      setState(() {
        onSelect(compressed);
      });

      // If they uploaded the CNIC Front, run the AI OCR Scanner!
      if (isCnicFront) {
        _scanCnic(compressed);
      }

      final sizeKB = compressed.lengthSync() / 1024;
      if (sizeKB > maxFileSizeKB) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image still large (${sizeKB.toStringAsFixed(0)} KB) but compressed."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
    }
  }

  // --- AI OCR API CALL ---
  Future<void> _scanCnic(File imageFile) async {
    setState(() => _isOcrLoading = true);
    try {
      // Connects to your Python AI Microservice
      String verifyUrl = "http://10.0.2.2:5000/api/verify-cnic";
      var request = http.MultipartRequest('POST', Uri.parse(verifyUrl));
      request.files.add(await http.MultipartFile.fromPath('cnic_image', imageFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          var data = json['data'];
          setState(() {
            if (data['name'] != null) _fullNameController.text = data['name'];
            if (data['cnic'] != null) _cnicController.text = data['cnic'].replaceAll('-', '');
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CNIC Scanned Successfully!"), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      print("OCR Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to auto-fill. Please type manually."), backgroundColor: Colors.orange));
    } finally {
      if (mounted) setState(() => _isOcrLoading = false);
    }
  }

  // ================= SUBMIT REGISTRATION =================
  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cnicFront == null || _cnicBack == null || _profilePic == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Profile picture, CNIC front & back are required."),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _isUploading = true);

    int? newCustomerId;

    try {
      final request = http.MultipartRequest("POST", Uri.parse("$_baseUrl/api/customer"));
      request.fields['fullName'] = _fullNameController.text;
      request.fields['cnic'] = _cnicController.text;
      request.fields['phone'] = _phoneController.text;
      request.fields['city'] = _selectedCity!;
      await _addFile(request, "cnicFront", _cnicFront);
      await _addFile(request, "cnicBack", _cnicBack);
      await _addFile(request, "profilePic", _profilePic);
      final response = await http.Response.fromStream(await request.send());

      if (mounted) {
        if (response.statusCode == 201) {
          final responseBody = jsonDecode(response.body);
          newCustomerId = int.parse(responseBody['customerId'].toString());
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Customer registered successfully"),
            backgroundColor: Colors.green,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server error: ${response.body}"), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }

    if (newCustomerId != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => CustomerDashboard(customerId: newCustomerId!)),
            (route) => route.isFirst,
      );
    }
  }

  Future<void> _addFile(http.MultipartRequest request, String field, File? file) async {
    if (file == null) return;
    request.files.add(await http.MultipartFile.fromPath(field, file.path, filename: path.basename(file.path)));
  }

  // ================= UI BUILDER =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Become a Verified User"),
        backgroundColor: const Color(0xFF1E8449),
        foregroundColor: Colors.white,
      ),
      // --- AI INTEGRATION: Floating Button for Voice ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isVoiceAssistantActive ? _stopVoiceAssistant : _startVoiceFlow,
        backgroundColor: _isVoiceAssistantActive ? Colors.red : const Color(0xFF1E8449),
        icon: Icon(_isVoiceAssistantActive ? Icons.stop : Icons.mic, color: Colors.white),
        label: Text(_isVoiceAssistantActive ? "Stop Listening" : "Voice Assistant", style: const TextStyle(color: Colors.white)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- AI INTEGRATION: Voice Assistant UI Card ---
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

              if (_isOcrLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20.0),
                  child: Center(child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF1E8449)),
                      SizedBox(height: 8),
                      Text("AI is reading your CNIC...", style: TextStyle(color: Color(0xFF1E8449), fontWeight: FontWeight.bold))
                    ],
                  )),
                ),

              _buildTextField(_fullNameController, "Enter your full name", "e.g. Ali Abbas"),
              _buildTextField(_cnicController, "Enter CNIC", "e.g. 3720152676988", isNumeric: true),
              _buildTextField(_phoneController, "Enter Phone no.", "e.g. 03316634986", isNumeric: true),
              _buildCityDropdown(),
              const SizedBox(height: 20),

              // Notice the 'isCnicFront: true' here. This triggers the AI OCR!
              _buildUploadRow("Upload CNIC Front", _cnicFront, (f) => setState(() => _cnicFront = f), isCnicFront: true),
              _buildUploadRow("Upload CNIC Back", _cnicBack, (f) => setState(() => _cnicBack = f)),
              _buildUploadRow("Upload Profile Picture", _profilePic, (f) => setState(() => _profilePic = f)),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E8449),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Submit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 60), // Extra space so the Floating Action Button doesn't cover the Submit button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            validator: (value) => (value == null || value.isEmpty) ? '$label is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select City (where you're resident)", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCity,
            hint: const Text("Select City"),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            items: _cities.map((String city) => DropdownMenuItem<String>(value: city, child: Text(city))).toList(),
            onChanged: (newValue) => setState(() => _selectedCity = newValue),
            validator: (value) => value == null ? 'Please select a city' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadRow(String title, File? file, Function(File) onSelect, {bool isCnicFront = false}) {
    double? fileSizeKB = file != null ? file.lengthSync() / 1024 : null;
    double progress = (fileSizeKB != null) ? (fileSizeKB / maxFileSizeKB).clamp(0, 1) : 0;
    Color progressColor = progress < 0.7 ? Colors.green : (progress < 1.0 ? Colors.orange : Colors.red);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickImage(ImageSource.gallery, onSelect, isCnicFront: isCnicFront),
                  child: Text(file == null ? "Upload" : "Update"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.camera, onSelect, isCnicFront: isCnicFront),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E8449), foregroundColor: Colors.white),
                  child: Text(file == null ? "Scan" : "Re-Scan"),
                ),
              ),
            ],
          ),
          if (file != null && fileSizeKB != null) ...[
            const SizedBox(height: 8),
            Text(
              "✓ ${path.basename(file.path)} (${fileSizeKB.toStringAsFixed(1)} KB)",
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              color: progressColor,
              backgroundColor: Colors.grey[300],
              minHeight: 5,
            ),
          ] else ... [
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "*Image must be less than ${maxFileSizeKB.toInt()}KB",
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ),
          ]
        ],
      ),
    );
  }
}