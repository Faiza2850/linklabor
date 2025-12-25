import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import 'screens/customer/dashboard.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedCity;

  File? _cnicFront;
  File? _cnicBack;
  File? _profilePic;

  static const String _baseUrl = "http://10.0.2.2:5000";
  static const double maxFileSizeKB = 500;

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final List<String> _cities = ["Karachi", "Lahore", "Islamabad", "Quetta", "Peshawar", "Multan", "Faisalabad"];

  @override
  void dispose() {
    _fullNameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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

  Future<void> _pickImage(ImageSource source, Function(File) onSelect) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final compressed = await _compressAndResize(File(picked.path));

      setState(() {
        onSelect(compressed);
      });

      final sizeKB = compressed.lengthSync() / 1024;
      if (sizeKB > maxFileSizeKB) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Image still large (${sizeKB.toStringAsFixed(0)} KB) but compressed."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
    }
  }

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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Server error: ${response.body}"), backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }

    if (newCustomerId != null) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => CustomerDashboard(customerId: newCustomerId!),
          ),
            (route) => route.isFirst, // This keeps the RoleSelectionScreen on the stack
      );
    }
  }

  Future<void> _addFile(http.MultipartRequest request, String field, File? file) async {
    if (file == null) return;
    request.files.add(await http.MultipartFile.fromPath(field, file.path, filename: path.basename(file.path)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Become a Verified User"),
        backgroundColor: const Color(0xFF1E8449),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_fullNameController, "Enter your full name", "e.g. Ali Abbas"),
              _buildTextField(_cnicController, "Enter CNIC", "e.g. 37201-5267698-8", isNumeric: true),
              _buildTextField(_phoneController, "Enter Phone no.", "e.g. 03316634986", isNumeric: true),
              _buildCityDropdown(),
              const SizedBox(height: 20),
              _buildUploadRow("Upload CNIC Front", _cnicFront, (f) => setState(() => _cnicFront = f)),
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

  Widget _buildUploadRow(String title, File? file, Function(File) onSelect) {
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
                  onPressed: () => _pickImage(ImageSource.gallery, onSelect),
                  child: Text(file == null ? "Upload" : "Update"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.camera, onSelect),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
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