import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/badge_model.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/badge_widgets.dart';
import '../chat/chat_screen.dart';

class FindDonorsScreen extends StatefulWidget {
  const FindDonorsScreen({super.key});

  @override
  State<FindDonorsScreen> createState() => _FindDonorsScreenState();
}

class _FindDonorsScreenState extends State<FindDonorsScreen> {
  String _selectedBloodGroup = 'All';
  final List<String> _bloodGroups = ['All', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters => 
    _nameController.text.isNotEmpty || 
    _cityController.text.isNotEmpty || 
    _selectedBloodGroup != 'All';

  void _clearFilters() {
    setState(() {
      _nameController.clear();
      _cityController.clear();
      _selectedBloodGroup = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Donors', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.1),
            width: 1,
          ),
        ),
        actions: [
          if (_hasActiveFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: authService.userDataStream,
        builder: (context, userSnapshot) {
          final currentUser = userSnapshot.data;

          return Column(
            children: [
              // Search & Filter Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search by Name
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Search by donor name...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[850],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Blood Group Filter
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[850],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedBloodGroup,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                items: _bloodGroups.map((group) => DropdownMenuItem(
                                  value: group, 
                                  child: Text(group, style: const TextStyle(fontWeight: FontWeight.w500))
                                )).toList(),
                                onChanged: (value) => setState(() {
                                  _selectedBloodGroup = value ?? 'All';
                                }),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Search by City
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _cityController,
                            decoration: InputDecoration(
                              hintText: 'Search city...',
                              prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[850],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Donors List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _selectedBloodGroup == 'All'
                      ? FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'donor').snapshots()
                      : FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'donor')
                          .where('bloodGroup', isEqualTo: _selectedBloodGroup)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildNoDonorsFound();
                    }

                    final nameQuery = _nameController.text.toLowerCase();
                    final cityQuery = _cityController.text.toLowerCase();

                    final donors = snapshot.data!.docs
                        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                        .where((donor) {
                          final matchesName = donor.name.toLowerCase().contains(nameQuery);
                          final matchesCity = donor.city.toLowerCase().contains(cityQuery);
                          final isNotMe = donor.uid != currentUser?.uid;
                          return matchesName && matchesCity && isNotMe;
                        })
                        .toList();

                    if (donors.isEmpty) {
                      return _buildNoDonorsFound();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: donors.length,
                      itemBuilder: (context, index) {
                        final donor = donors[index];
                        return _buildDonorCard(context, donor, currentUser);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoDonorsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_rounded, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No donors found matching\nyour search criteria',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorCard(BuildContext context, UserModel donor, UserModel? currentUser) {
    final currentTier = BadgeTiers.getCurrentTier(
      donor.totalDonations,
      donor.loyaltyPoints,
      donor.inAppDonations,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToChat(context, donor, currentUser),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Blood Group Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      donor.bloodGroup,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Donor Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              donor.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (currentTier != null) ...[
                            const SizedBox(width: 6),
                            UserBadgeIcon(tier: currentTier, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              donor.city,
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Message Button
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 22),
                    onPressed: () => _navigateToChat(context, donor, currentUser),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, UserModel donor, UserModel? currentUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverId: donor.uid,
          receiverName: donor.name,
          myRole: currentUser?.role,
        ),
      ),
    );
  }
}
