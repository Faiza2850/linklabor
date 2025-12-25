import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WorkerJobsScreen extends StatefulWidget {
  final int workerId;
  const WorkerJobsScreen({super.key, required this.workerId});

  @override
  State<WorkerJobsScreen> createState() => _WorkerJobsScreenState();
}

class _WorkerJobsScreenState extends State<WorkerJobsScreen> {
  List<dynamic> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    try {
      final response =
      await http.get(Uri.parse('http://10.0.2.2:5000/api/jobs/open'));

      if (response.statusCode == 200) {
        setState(() {
          _jobs = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptJob(int jobId) async {
    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:5000/api/jobs/$jobId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'workerId': widget.workerId}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Job Accepted!"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchJobs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection Error")),
      );
    }
  }

  // ✅ Contact dialog helper
  void _showContactDialog(String? name, String? phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Contact ${name ?? 'Customer'}"),
        content: Text("Phone Number: ${phone ?? 'Not Available'}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Jobs"),
        backgroundColor: const Color(0xFF1E8449),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
          ? const Center(child: Text("No jobs available right now."))
          : RefreshIndicator(
        onRefresh: _fetchJobs,
        child: ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: _jobs.length,
          itemBuilder: (context, index) {
            final job = _jobs[index];

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Job Header ---
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            job['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          "Rs. ${job['budget']}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1E8449),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // --- Customer Info ---
                    Row(
                      children: [
                        const Icon(Icons.person,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          "Posted by: ${job['customerName'] ?? 'Unknown'}",
                          style: const TextStyle(
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            job['location'],
                            style: const TextStyle(
                                color: Colors.grey),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      job['description'],
                      style:
                      TextStyle(color: Colors.grey.shade800),
                    ),

                    const Divider(height: 30),

                    // --- Action Buttons ---
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.phone,
                              color: Color(0xFF1E8449)),
                          onPressed: () {
                            _showContactDialog(
                              job['customerName'],
                              job['customerPhone'],
                            );
                          },
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () =>
                              _acceptJob(job['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF1E8449),
                          ),
                          child: const Text(
                            "Accept Job",
                            style:
                            TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
