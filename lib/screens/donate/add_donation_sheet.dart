import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';

/// Bottom sheet to record a new blood donation.
/// Updates the user's loyalty points and recovery status.
class AddDonationSheet extends StatefulWidget {
  final String userId;
  const AddDonationSheet({super.key, required this.userId});

  @override
  State<AddDonationSheet> createState() => _AddDonationSheetState();
}

class _AddDonationSheetState extends State<AddDonationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalController = TextEditingController();
  final _unitsController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _hospitalController.dispose();
    _unitsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Function to handle date selection for donation
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Saves the donation record and updates user stats.
  Future<void> _saveDonation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      
      // 1. Add donation to sub-collection
      await userRef.collection('donations').add({
        'hospital': _hospitalController.text.trim(),
        'date': _selectedDate.toIso8601String(),
        'units': int.tryParse(_unitsController.text) ?? 1,
        'notes': _notesController.text.trim(),
        'points': 50,
      });

      // 2. Update user's total points and last donation date
      await userRef.update({
        'loyaltyPoints': FieldValue.increment(50),
        'lastDonationDate': _selectedDate.toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation recorded! +50 Points earned.'), backgroundColor: AppColors.success),
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
                'Record New Donation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _hospitalController,
                decoration: InputDecoration(
                  labelText: 'Hospital Name',
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              
              const SizedBox(height: 15),

              TextFormField(
                controller: _unitsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Units Donated',
                  prefixIcon: const Icon(Icons.opacity),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (int.tryParse(val) == null) return 'Enter a valid number';
                  return null;
                },
              ),

              const SizedBox(height: 15),
              
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
                      Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true,
                ),
              ),
              
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDonation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Save Donation', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
