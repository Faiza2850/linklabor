import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/worker/dashboard.dart';

class VerificationScreen extends StatefulWidget {
  final Map<String, String> workerData;

  const VerificationScreen({super.key, required this.workerData});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // ================= FILES =================
  File? _cnicFront;
  File? _cnicBack;
  File? _profilePic;
  File? _workCert;
  File? _license;
  File? _licenseBack;

  static const String _baseUrl = "http://10.0.2.2:5000";
  static const double maxFileSizeKB = 500;

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // ================= IMAGE COMPRESSION =================
  Future<File> _compressAndResize(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();

      String getTargetPath() =>
          "${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg";

      int quality = 80; // Start with a decent quality
      var targetPath = getTargetPath();

      XFile? resultXFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (resultXFile == null) return file; // If compression fails, return original.

      File resultFile = File(resultXFile.path);

      // Loop to reduce size until under the limit
      while (resultFile.lengthSync() / 1024 > maxFileSizeKB && quality > 10) {
        quality -= 15; // Reduce quality for the next attempt
        targetPath = getTargetPath(); // Use a new path

        resultXFile = await FlutterImageCompress.compressAndGetFile(
          file.path, // Compress from the original file
          targetPath,
          quality: quality,
          format: CompressFormat.jpeg,
        );

        if (resultXFile == null) break; // If this attempt fails, stick with the last good one
        resultFile = File(resultXFile.path);
      }

      return resultFile;
    } catch (_) {
      return file; // On any error, fall back to the original file
    }
  }

  // ================= PICK IMAGE =================
  Future<void> _pickImage(ImageSource source, Function(File) onSelect) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final compressed = await _compressAndResize(File(picked.path));
      final sizeKB = compressed.lengthSync() / 1024;

      setState(() {
        onSelect(compressed); // Update file
      });

      if (sizeKB > maxFileSizeKB) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Image still too large (${sizeKB.toStringAsFixed(0)} KB)."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
    }
  }

  // ================= SUBMIT REGISTRATION =================
  Future<void> _submitFullRegistration() async {
    if (_cnicFront == null || _cnicBack == null || _profilePic == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile picture, CNIC front & back are required."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    int? newWorkerId;

    try {
      final request =
          http.MultipartRequest("POST", Uri.parse("$_baseUrl/api/worker"));

      // TEXT FIELDS
      request.fields.addAll(widget.workerData);

      // FILES
      await _addFile(request, "cnicFront", _cnicFront);
      await _addFile(request, "cnicBack", _cnicBack);
      await _addFile(request, "profilePic", _profilePic);
      await _addFile(request, "workCert", _workCert);
      await _addFile(request, "license", _license);
      await _addFile(request, "licenseBack", _licenseBack);

      final response = await http.Response.fromStream(await request.send());

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        
        // Safer parsing of workerId
        try {
          newWorkerId = int.parse(responseBody['workerId'].toString());
        } catch (e) {
          throw Exception("Invalid workerId format from server");
        }

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
        SnackBar(content: Text("An error occurred: $e")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }

    if (newWorkerId != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerDashboard(workerId: newWorkerId!),
        ),
        (route) => route.isFirst,
      );
    }
  }

  Future<void> _addFile(
      http.MultipartRequest request, String field, File? file) async {
    if (file == null) return;

    request.files.add(
      await http.MultipartFile.fromPath(
        field,
        file.path,
        filename: path.basename(file.path),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Documents"),
        backgroundColor: const Color(0xFF1E8449),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                _buildUploadRow(
                    "CNIC Front", _cnicFront, (f) => setState(() => _cnicFront = f)),
                _buildUploadRow(
                    "CNIC Back", _cnicBack, (f) => setState(() => _cnicBack = f)),
                _buildUploadRow("Profile Picture", _profilePic,
                    (f) => setState(() => _profilePic = f)),
                _buildUploadRow("Work Certificate (Optional)", _workCert,
                    (f) => setState(() => _workCert = f)),
                _buildUploadRow(
                    "License Front", _license, (f) => setState(() => _license = f)),
                _buildUploadRow("License Back", _licenseBack,
                    (f) => setState(() => _licenseBack = f)),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitFullRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E8449),
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Submit Application",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadRow(String title, File? file, Function(File) onSelect) {
    String? fileName = file != null ? path.basename(file.path) : null;
    double? fileSizeKB = file != null ? file.lengthSync() / 1024 : null;
    double progress =
        (fileSizeKB != null) ? (fileSizeKB / maxFileSizeKB).clamp(0, 1) : 0;

    Color progressColor;
    if (progress < 0.7) {
      progressColor = Colors.green;
    } else if (progress < 1.0) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.gallery, onSelect),
                  child: Text(file == null ? "Upload" : "Update"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.camera, onSelect),
                  child: const Text("Scan"),
                ),
              ),
            ],
          ),
          if (fileName != null && fileSizeKB != null) ...[
            const SizedBox(height: 5),
            Text(
              "Selected: $fileName (${fileSizeKB.toStringAsFixed(1)} KB)",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 3),
            LinearProgressIndicator(
              value: progress,
              color: progressColor,
              backgroundColor: Colors.grey[300],
              minHeight: 5,
            ),
          ],
        ],
      ),
    );
  }
}
