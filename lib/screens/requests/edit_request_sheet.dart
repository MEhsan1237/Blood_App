import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/blood_request_model.dart';
import '../../utils/constants.dart';

class EditRequestSheet extends StatefulWidget {
  final BloodRequest request;
  const EditRequestSheet({super.key, required this.request});

  @override
  State<EditRequestSheet> createState() => _EditRequestSheetState();
}

class _EditRequestSheetState extends State<EditRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late String _selectedBloodGroup;
  late TextEditingController _cityController;
  late TextEditingController _hospitalController;
  late TextEditingController _unitsController;
  late TextEditingController _descriptionController;
  late String _selectedUrgency;
  bool _isLoading = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _urgencies = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _selectedBloodGroup = widget.request.bloodGroup;
    _cityController = TextEditingController(text: widget.request.city);
    _hospitalController = TextEditingController(text: widget.request.hospital);
    _unitsController = TextEditingController(text: widget.request.units.toString());
    _descriptionController = TextEditingController(text: widget.request.description);
    _selectedUrgency = widget.request.urgency;
  }

  @override
  void dispose() {
    _cityController.dispose();
    _hospitalController.dispose();
    _unitsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('requests').doc(widget.request.id).update({
        'bloodGroup': _selectedBloodGroup,
        'city': _cityController.text.trim(),
        'hospital': _hospitalController.text.trim(),
        'units': int.parse(_unitsController.text),
        'description': _descriptionController.text.trim(),
        'urgency': _selectedUrgency,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request updated successfully'), backgroundColor: AppColors.success),
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Blood Request',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown('Blood Group', _selectedBloodGroup, _bloodGroups, (val) => setState(() => _selectedBloodGroup = val!)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildTextField(_unitsController, 'Units Needed', Icons.inventory_2_outlined, keyboardType: TextInputType.number),
                  ),
                ],
              ),
              
              _buildTextField(_cityController, 'City', Icons.location_on_outlined),
              _buildTextField(_hospitalController, 'Hospital Name', Icons.local_hospital_outlined),
              _buildTextField(_descriptionController, 'Description / Reason', Icons.description_outlined),
              
              _buildDropdown('Urgency Level', _selectedUrgency, _urgencies, (val) => setState(() => _selectedUrgency = val!)),
              
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateRequest,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
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
      ),
    );
  }
}
