import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';

class EditProfileSheet extends StatefulWidget {
  final UserModel user;
  const EditProfileSheet({super.key, required this.user});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _weightController;
  late TextEditingController _otherDiseasesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing user data
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _cityController = TextEditingController(text: widget.user.city);
    _weightController = TextEditingController(text: widget.user.weight.toString());
    _otherDiseasesController = TextEditingController(text: widget.user.otherDiseases);
  }

  /// Updates user profile in Firestore
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Update User document
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
      batch.update(userRef, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'weight': double.parse(_weightController.text),
        'otherDiseases': _otherDiseasesController.text.trim(),
      });

      // Update all requests by this user to reflect name change
      final requests = await FirebaseFirestore.instance
          .collection('requests')
          .where('requesterId', isEqualTo: widget.user.uid)
          .get();
      
      for (var doc in requests.docs) {
        batch.update(doc.reference, {'requesterName': _nameController.text.trim()});
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildTextField(_nameController, 'Full Name', Icons.person_outline),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
              _buildTextField(_cityController, 'City', Icons.location_on_outlined),
              _buildTextField(_weightController, 'Weight (kg)', Icons.monitor_weight_outlined, keyboardType: TextInputType.number),
              _buildTextField(_otherDiseasesController, 'Other Diseases', Icons.medical_services_outlined),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }
}
