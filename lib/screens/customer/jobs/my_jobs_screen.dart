import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:linklabor/screens/customer/jobs/post_job_screen.dart'; // Make sure this path is correct

class CustomerMyJobsScreen extends StatefulWidget {
  final int customerId;
  const CustomerMyJobsScreen({super.key, required this.customerId});

  @override
  State<CustomerMyJobsScreen> createState() => _CustomerMyJobsScreenState();
}

class _CustomerMyJobsScreenState extends State<CustomerMyJobsScreen> {
  List<dynamic> _myJobs = [];
  bool _isLoading = true;

  // ⚠️ USE 10.0.2.2 for Emulator, YOUR_PC_IP for Real Device
  final String _baseUrl = "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _fetchMyJobs();
  }

  // --- API Fetch Function ---
  Future<void> _fetchMyJobs() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/jobs/customer/${widget.customerId}'));

      if (response.statusCode == 200) {
        setState(() {
          _myJobs = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        // print("Error: ${response.body}");
      }
    } catch (e) {
      // print("Network Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- Navigation to Post Job ---
  void _navigateToPostJob() async {
    // Wait for result. If 'true', it means a job was posted successfully.
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostJobScreen(customerId: widget.customerId),
      ),
    );

    if (result == true) {
      _fetchMyJobs(); // Refresh list immediately
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // --- Floating "Post a Job" Button ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToPostJob,
        backgroundColor: const Color(0xFF0EA5E9), // Light Blue like screenshot
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Post a Job", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // --- Custom Header (Matches Screenshot) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CircleAvatar(
                    backgroundImage: AssetImage('assets/images/avatar_placeholder.png'), // Add your asset or use NetworkImage
                    radius: 20,
                  ),
                  const Text(
                    "Home",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {},
                  )
                ],
              ),
            ),

            // --- Search Bar ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search for workers",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- "Your Jobs" Title ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Your Jobs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // --- Job List ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _myJobs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _myJobs.length,
                itemBuilder: (context, index) {
                  final job = _myJobs[index];
                  return _buildJobCard(job);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Widget: Job Card ---
  Widget _buildJobCard(dynamic job) {
    bool isActive = job['status'] == 'open'; // Check database status

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.handyman_outlined, color: Colors.blue),
          ),
          const SizedBox(width: 15),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['title'] ?? "Unknown Job",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? "Active" : "Completed",
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Arrow
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text("No jobs posted yet", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}