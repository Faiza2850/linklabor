import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:linklabor/screens/customer/jobs/post_job_screen.dart';
import 'package:linklabor/screens/customer/profile/profile_screen.dart';

class CustomerMyJobsScreen extends StatefulWidget {
  final int customerId;
  const CustomerMyJobsScreen({super.key, required this.customerId});

  @override
  State<CustomerMyJobsScreen> createState() => _CustomerMyJobsScreenState();
}

class _CustomerMyJobsScreenState extends State<CustomerMyJobsScreen> {
  List<dynamic> _myJobs = [];
  bool _isLoading = true; // This is now ONLY for the initial load
  Map<String, dynamic>? _customerProfile;

  final String _baseUrl = "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // This only runs on the initial load.
    if (!_isLoading) setState(() => _isLoading = true);

    await Future.wait([
      _fetchMyJobs(),
      _fetchCustomerProfile(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- FIX: This function no longer controls the main _isLoading state ---
  Future<void> _fetchMyJobs() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/jobs/customer/${widget.customerId}'));

      if (mounted && response.statusCode == 200) {
        setState(() {
          _myJobs = jsonDecode(response.body);
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to fetch jobs.")));
      }
    }
  }

  Future<void> _fetchCustomerProfile() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/customer/${widget.customerId}'));
      if (mounted && response.statusCode == 200) {
        setState(() {
          _customerProfile = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Silently fail or log, as this is less critical than the job list
    }
  }

  void _navigateToPostJob() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostJobScreen(customerId: widget.customerId),
      ),
    );

    if (result == true) {
      // When a job is posted, just refresh the jobs list.
      // The full-screen loader will not be triggered.
      _fetchMyJobs();
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerProfileScreen(customerId: widget.customerId),
      ),
    ).then((_) {
      // Re-fetch profile data in case the user updated their picture
      _fetchCustomerProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToPostJob,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Post a Job", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _navigateToProfile,
                    child: _buildProfileAvatar(),
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _myJobs.isEmpty
                  ? _buildEmptyState()
              // --- FIX: Wrap the list in a RefreshIndicator ---
                  : RefreshIndicator(
                onRefresh: _loadAllData, // Pull-to-refresh calls the full data load
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _myJobs.length,
                  itemBuilder: (context, index) {
                    final job = _myJobs[index];
                    return _buildJobCard(job);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    // ... This widget is correct and does not need changes
    final profilePicBase64 = _customerProfile?['profilePic'];
    ImageProvider? backgroundImage;
    if (profilePicBase64 != null) {
      backgroundImage = MemoryImage(base64Decode(profilePicBase64));
    } else {
      backgroundImage = const AssetImage('assets/images/avatar_placeholder.png');
    }
    return CircleAvatar(
      backgroundImage: backgroundImage,
      radius: 20,
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildJobCard(dynamic job) {
    // ... This widget is correct and does not need changes
    bool isActive = job['status'] == 'open';
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
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // ... This widget is correct and does not need changes
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
