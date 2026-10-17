import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../home/main_navigation.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _weightController = TextEditingController();
  final _otherDiseasesController = TextEditingController();

  // Selection states
  String _selectedBloodGroup = 'O+';
  String _selectedGender = 'Male';
  DateTime? _selectedDob;
  bool _hasDiabetes = false;
  bool _hasBloodPressure = false;
  bool _agreeToDonate = false;
  bool _isLoading = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _genders = ['Male', 'Female', 'Other'];

  /// Function to handle date of birth selection
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // ~18 years
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDob) {
      setState(() => _selectedDob = picked);
    }
  }

  /// Handles registration process
  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _selectedDob == null || !_agreeToDonate) {
      if (_selectedDob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Date of Birth'), backgroundColor: AppColors.primary),
        );
      } else if (!_agreeToDonate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please agree to the terms to continue'), backgroundColor: AppColors.primary),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    final error = await authService.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phone: _phoneController.text.trim(),
      city: _cityController.text.trim(),
      bloodGroup: _selectedBloodGroup,
      dob: _selectedDob!,
      weight: double.parse(_weightController.text),
      gender: _selectedGender,
      hasDiabetes: _hasDiabetes,
      hasBloodPressure: _hasBloodPressure,
      otherDiseases: _otherDiseasesController.text.trim(),
      agreeToDonate: _agreeToDonate,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.primary),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hPadding = AppSpacing.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_nameController, 'Full Name', Icons.person_outline),
              _buildTextField(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              _buildTextField(_passwordController, 'Password', Icons.lock_outline, isPassword: true),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
              _buildTextField(_cityController, 'City', Icons.location_on_outlined),

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown('Blood Group', _selectedBloodGroup, _bloodGroups, (val) => setState(() => _selectedBloodGroup = val!)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildDropdown('Gender', _selectedGender, _genders, (val) => setState(() => _selectedGender = val!)),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              // DOB Picker
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        _selectedDob == null ? 'Date of Birth' : DateFormat('dd/MM/yyyy').format(_selectedDob!),
                        style: TextStyle(color: _selectedDob == null ? Colors.grey[700] : null),
                      ),
                    ],
                  ),
                ),
              ),

              _buildTextField(_weightController, 'Weight (kg)', Icons.monitor_weight_outlined, keyboardType: TextInputType.number),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text('Health Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),

              _buildSwitchTile('Diabetes', _hasDiabetes, (val) => setState(() => _hasDiabetes = val)),
              _buildSwitchTile('Blood Pressure', _hasBloodPressure, (val) => setState(() => _hasBloodPressure = val)),

              _buildTextField(_otherDiseasesController, 'Other Diseases (if any)', Icons.medical_services_outlined, isRequired: false),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I agree to be a donor and help people in need.'),
                value: _agreeToDonate,
                onChanged: (val) => setState(() => _agreeToDonate = val!),
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, TextInputType keyboardType = TextInputType.text, bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
      ],
    );
  }
}
