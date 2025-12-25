import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CustomerProfileScreen extends StatefulWidget {
  final int customerId;

  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  final String _baseUrl = "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    if (!_isLoading) setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/customer/${widget.customerId}'));
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() => _profile = jsonDecode(response.body));
        } else {
          _showError("Failed to load profile. Status: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) _showError("Connection Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: DOCUMENT MANAGEMENT LOGIC (ADAPTED FROM WORKER PROFILE) ---

  Future<void> _updateDocument(String field) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    _showLoadingDialog();

    try {
      // Uses the correct customer API endpoint
      var uri = Uri.parse('$_baseUrl/api/customer/${widget.customerId}/documents?field=$field');
      var request = http.MultipartRequest('PUT', uri);
      request.files.add(await http.MultipartFile.fromPath('file', picked.path));

      var response = await request.send();

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        _showSuccess("Document updated successfully!");
        await _fetchProfile(); // Refresh data to show the new image
      } else {
        final respStr = await response.stream.bytesToString();
        _showError("Update failed: $respStr");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError("Error: $e");
    }
  }

  Future<void> _deleteDocument(String field) async {
    bool confirm = await _showConfirmDialog("Delete this document?");
    if (!confirm) return;

    try {
      // Uses the correct customer API endpoint
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/customer/${widget.customerId}/documents?field=$field'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _profile![field] = null; // Visually remove from UI instantly
        });
        _showSuccess("Document deleted successfully");
      } else {
        final respStr = await response.body;
        _showError("Failed to delete: $respStr");
      }
    } catch (e) {
      _showError("Error: $e");
    }
  }

  void _viewImage(String base64String) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(base64Decode(base64String), fit: BoxFit.contain),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            )
          ],
        ),
      ),
    );
  }

  // --- END NEW DOCUMENT LOGIC ---

  void _handleSignOut() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: const Color(0xFF1E8449),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProfile,
            tooltip: "Refresh",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? const Center(child: Text("Profile data could not be loaded."))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildDocumentsCard(), // --- NEW: DOCUMENTS UI ---
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _handleSignOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
              ),
              child: const Text("Sign Out"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final profilePicBase64 = _profile!['profilePic'];
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: profilePicBase64 != null
                  ? MemoryImage(base64Decode(profilePicBase64))
                  : null,
              child: profilePicBase64 == null
                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                  : null,
            ),
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: () => _updateDocument('profilePic'), // --- UPDATED ---
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(5.0),
                  child: Icon(Icons.edit, size: 18, color: Color(0xFF1E8449)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _profile!['fullName'] ?? 'N/A',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(Icons.badge_outlined, "CNIC", _profile!['cnic']),
            _buildInfoRow(Icons.phone_outlined, "Phone", _profile!['phone']),
            _buildInfoRow(Icons.location_city_outlined, "City", _profile!['city']),
          ],
        ),
      ),
    );
  }

  // --- NEW: WIDGET TO DISPLAY DOCUMENTS ---
  Widget _buildDocumentsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Documents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _buildDocumentRow('cnicFront', 'CNIC Front'),
            _buildDocumentRow('cnicBack', 'CNIC Back'),
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
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
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
  // --- END NEW WIDGETS ---

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value ?? 'N/A', style: TextStyle(color: Colors.grey[800])),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _showLoadingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  // --- NEW: CONFIRMATION DIALOG HELPER ---
  Future<bool> _showConfirmDialog(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Confirm", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false; // Return false if dialog is dismissed
  }
}
