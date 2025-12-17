import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';


class VerificationScreen extends StatefulWidget {
  final Map<String, String> workerData;

  const VerificationScreen({super.key, required this.workerData});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // Store file objects
  File? _cnicFront;
  File? _cnicBack;
  File? _profilePic;
  File? _workCert;
  File? _licenseFront;
  File? _licenseBack;

  static const String _baseUrl = "http://10.0.2.2:5000";


  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;


  //compress
  Future<File?> _compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          "${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg";

      // 🔹 First attempt (balanced)
      var result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      // 🔹 Fallback attempt (more aggressive)
      if (result == null) {
        result = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: 50,
          format: CompressFormat.jpeg,
        );
      }

      // 🔹 Final fallback: use original file (never block user)
      if (result == null) {
        debugPrint("Compression failed, using original image");
        return file;
      }

      final sizeKB = await result.length() / 1024;
      debugPrint("Final image size: ${sizeKB.toStringAsFixed(1)} KB");

      return File(result.path);
    } catch (e) {
      debugPrint("Compression exception: $e");
      return file; // never return null
    } 
  }

  // --- Helper to Pick and Compress Image ---
  Future<void> _pickImage(ImageSource source, Function(File) onSelect) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85, // initial mild compression
      );

      if (picked == null) return;

      final originalFile = File(picked.path);
      final compressedFile = await _compressImage(originalFile);

      if (compressedFile == null) return;

      final sizeKB = await compressedFile.length() / 1024;

      if (sizeKB > 500) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Image too large (${sizeKB.toStringAsFixed(0)}KB). Please retake closer photo.",
            ),
          ),
        );
        return;
      }

      setState(() => onSelect(compressedFile));
    } catch (e) {
      debugPrint("Pick error: $e");
    }
  }


  // --- Submit to Server ---
  Future<void> _submitFullRegistration() async {
    // 1. Client-side validation for required files
    if (_cnicFront == null || _cnicBack == null || _profilePic == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture, CNIC front, and CNIC back are required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse("$_baseUrl/register-api/worker");
      final request = http.MultipartRequest("POST", uri);

      // ✅ Add text fields (already validated earlier)
      request.fields.addAll(widget.workerData);

      // ✅ Add files (exact backend field names)
      await _addFile(request, "cnicFront", _cnicFront);
      await _addFile(request, "cnicBack", _cnicBack);
      await _addFile(request, "profilePic", _profilePic);
      await _addFile(request, "workCert", _workCert);
      await _addFile(request, "license", _licenseFront);
      await _addFile(request, "licenseBack", _licenseBack);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Worker registered successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Server error: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      } 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }


  Future<void> _addFile(
      http.MultipartRequest request,
      String fieldName,
      File? file,
      ) async {
    if (file == null) return;

    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        filename: path.basename(file.path),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light Gray Background
      appBar: AppBar(
        title: const Text("Verify Documents", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E8449), // Main Green
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // --- Header ---
                  const Text(
                    "Upload Documents",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E8449), // Green Header
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "( Secure Verification )",
                    style: TextStyle(fontSize: 14, color: Color(0xFF17A589)), // Teal Subtitle
                  ),
                  const SizedBox(height: 30),

                  // --- Upload Sections ---
                  _buildUploadRow("Upload CNIC Front", _cnicFront, (f) => _cnicFront = f),
                  _buildUploadRow("Upload CNIC Back", _cnicBack, (f) => _cnicBack = f),
                  _buildUploadRow("Upload Profile Picture", _profilePic, (f) => _profilePic = f),

                  const Divider(height: 40, color: Colors.grey), // Separator

                  _buildUploadRow("Work Certificate (Optional)", _workCert, (f) => _workCert = f),
                  _buildUploadRow("License Front (Drivers)", _licenseFront, (f) => _licenseFront = f),
                  _buildUploadRow("License Back (Drivers)", _licenseBack, (f) => _licenseBack = f),

                  const SizedBox(height: 20),

                  // --- Submit Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _submitFullRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E8449), // Main Green Button
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 3,
                      ),
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        "Submit Application",
                        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Styled Row for Upload/Scan ---
  Widget _buildUploadRow(String title, File? file, Function(File) onSelect) {
    // Calculate file size
    String sizeText = "";
    if (file != null) {
      double kb = file.lengthSync() / 1024;
      sizeText = "(${kb.toStringAsFixed(2)} KB)";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 10),

          Row(
            children: [
              // 1. Upload/Update Button (Light Green)
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.gallery, onSelect),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5E9), // Very Light Green
                    foregroundColor: const Color(0xFF1E8449), // Dark Green Text
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFA5D6A7)), // Light Green Border
                  ),
                  child: Text(
                    file != null ? "Update" : "Upload",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 15),

              // 2. Scan Button (Solid Green)
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.camera, onSelect),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E8449), // Solid Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  child: const Text("Scan", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          // 3. File Info
          if (file != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 4),
              child: Text(
                "Selected: ${path.basename(file.path)} $sizeText",
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E8449), fontWeight: FontWeight.w500),
              ),
            ),

          // 4. Helper Text
          if (file == null)
            const Padding(
              padding: EdgeInsets.only(top: 4.0, left: 4),
              child: Text(
                "*Image must be less than 500KB",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
