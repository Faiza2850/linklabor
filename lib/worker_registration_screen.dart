import 'package:flutter/material.dart';
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

  // ================= DROPDOWN DATA =================
  final List<String> _cities = [
    'Lahore',
    'Karachi',
    'Islamabad',
    'Rawalpindi'
  ];

  final List<String> _skills = [
    'Electrician',
    'Plumber',
    'Carpenter',
    'Painter'
  ];

  final List<String> _durations = [
    '1-3 Hours',
    '4-6 Hours',
    'Full Day'
  ];

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
          builder: (context) =>
              VerificationScreen(workerData: workerData),
        ),
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 5,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        "Create your Profile",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E8449),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
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

                    _buildLabel("Enter your full name"),
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDecoration("e.g. Muhammad Ali"),
                      validator: (v) =>
                      v == null || v.isEmpty ? "Enter name" : null,
                    ),

                    _buildLabel("Enter CNIC"),
                    TextFormField(
                      controller: _cnicController,
                      keyboardType: TextInputType.number,
                      decoration:
                      _inputDecoration("e.g. 3720152676988"),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Enter CNIC";
                        if (v.length < 13) return "Invalid CNIC";
                        return null;
                      },
                    ),

                    _buildLabel("Enter Phone no."),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration:
                      _inputDecoration("e.g. 03332343654"),
                      validator: (v) =>
                      v == null || v.isEmpty ? "Enter phone number" : null,
                    ),

                    _buildLabel("Select City"),
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration("City"),
                      value: _selectedCity,
                      items: _cities
                          .map(
                            (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCity = v),
                      validator: (v) =>
                      v == null ? "Select a city" : null,
                    ),

                    _buildLabel("Select Skill"),
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration("Skill"),
                      value: _selectedSkill,
                      items: _skills
                          .map(
                            (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSkill = v),
                      validator: (v) =>
                      v == null ? "Select a skill" : null,
                    ),

                    _buildLabel("Daily Availability"),
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration("Duration"),
                      value: _selectedDuration,
                      items: _durations
                          .map(
                            (d) => DropdownMenuItem(
                          value: d,
                          child: Text(d),
                        ),
                      )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedDuration = v),
                      validator: (v) =>
                      v == null ? "Select duration" : null,
                    ),

                    _buildLabel("About (Optional)"),
                    TextFormField(
                      controller: _aboutController,
                      decoration: _inputDecoration(
                          "Tell us about your experience..."),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E8449),
                        padding:
                        const EdgeInsets.symmetric(vertical: 15),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding:
      const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
        const BorderSide(color: Color(0xFF1E8449), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
