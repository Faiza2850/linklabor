import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// Renamed to WorkerProfile to match dashboard usage
class WorkerProfile extends StatefulWidget {
  final int workerId;

  const WorkerProfile({super.key, required this.workerId});

  @override
  State<WorkerProfile> createState() => _WorkerProfileState();
}

class _WorkerProfileState extends State<WorkerProfile> {
  // Data State
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  // Network Configuration
  final String _baseUrl = "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // --- API: Fetch Profile ---
  Future<void> _fetchProfile() async {
    if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/worker/${widget.workerId}'));
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _profile = jsonDecode(response.body);
          });
        } else {
          _showError("Failed to load profile. Status: ${response.statusCode}");
        }
      }
    } catch (e) {
      _showError("Connection Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- API: Update Document ---
  Future<void> _updateDocument(String field) async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;

      _showLoadingDialog();

      var uri = Uri.parse('$_baseUrl/api/worker/${widget.workerId}/documents?field=$field');
      var request = http.MultipartRequest('PUT', uri);
      request.files.add(await http.MultipartFile.fromPath('file', picked.path));

      var response = await request.send();

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        _showSuccess("Document updated successfully");
        await _fetchProfile(); // Re-fetch data to show update
      } else {
        _showError("Update failed");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading if error
      _showError("Error: $e");
    }
  }

  // --- API: Delete Document ---
  Future<void> _deleteDocument(String field) async {
    bool confirm = await _showConfirmDialog("Delete this document?");
    if (!confirm) return;

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/worker/${widget.workerId}/documents?field=$field'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _profile![field] = null; // Remove from local UI
        });
        _showSuccess("Document deleted");
      } else {
        _showError("Failed to delete");
      }
    } catch (e) {
      _showError("Error: $e");
    }
  }

  // --- Helper: Sign Out ---
  void _handleSignOut() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E8449),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProfile,
            tooltip: "Refresh Profile",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text("Worker not found or failed to load."))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildInfoCard("About", _profile!['about'] ?? "No description provided."),
                      const SizedBox(height: 16),
                      _buildSkillsCard(),
                      const SizedBox(height: 16),
                      _buildDocumentsSection(),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _handleSignOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                        child: const Text("Sign Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  // === WIDGET BUILDERS ===

  Widget _buildHeaderCard() {
    final profilePicBase64 = _profile!['profilePic'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                image: profilePicBase64 != null
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(profilePicBase64)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profilePicBase64 == null
                  ? const Icon(Icons.person, size: 40, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile!['fullName'] ?? "Worker Name",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 5),
                  Text("📞 ${_profile!['phone'] ?? 'N/A'}", style: TextStyle(color: Colors.grey[700])),
                  Text("📍 ${_profile!['city'] ?? 'N/A'} • CNIC: ${_profile!['cnic'] ?? 'N/A'}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 8),
                  if (_profile!['availableHours'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        "✔ Available: ${_profile!['availableHours']}",
                        style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Text(content, style: const TextStyle(color: Colors.black87, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsCard() {
    List<String> skills = [];
    if (_profile!['skill'] != null) {
      skills = _profile!['skill'].toString().split(',').map((e) => e.trim()).toList();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Skills", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) => Chip(
                label: Text(skill),
                backgroundColor: const Color(0xFFE8F5E9),
                labelStyle: const TextStyle(color: Color(0xFF1E8449), fontWeight: FontWeight.bold),
                side: BorderSide.none,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final docs = [
      {'field': 'cnicFront', 'label': 'CNIC Front'},
      {'field': 'cnicBack', 'label': 'CNIC Back'},
      {'field': 'workCert', 'label': 'Work Certificate'},
      {'field': 'license', 'label': 'Driver License'},
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Documents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            ...docs.map((doc) => _buildDocumentRow(doc['field']!, doc['label']!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentRow(String field, String label) {
    bool hasFile = _profile![field] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            hasFile ? Icons.check_circle : Icons.error_outline,
            color: hasFile ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          if (hasFile)
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.blue),
              tooltip: "View",
              onPressed: () => _viewImage(_profile![field]),
            ),
          IconButton(
            icon: const Icon(Icons.cloud_upload, color: Color(0xFF1E8449)),
            tooltip: "Update",
            onPressed: () => _updateDocument(field),
          ),
          if (hasFile)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              tooltip: "Delete",
              onPressed: () => _deleteDocument(field),
            ),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  void _viewImage(String base64String) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(base64Decode(base64String), fit: BoxFit.contain),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String msg) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm"),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }
}
