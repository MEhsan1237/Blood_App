import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../widgets/circle_icon.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import 'home_screen.dart';
import '../requests/requests_screen.dart';
import '../donate/donate_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // List of screens for navigation
  final List<Widget> _screens = [
    const HomeScreen(),
    const RequestsScreen(),
    const DonateScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  /// Handles navigation item tapping
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final userId = authService.currentUser?.uid;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          _buildNavItem(Icons.home, 'Home', 0),
          _buildNavItem(Icons.list_alt, 'Requests', 1),
          _buildNavItem(Icons.favorite, 'Donate', 2),
          _buildMessagesNavItem(chatService, userId),
          _buildNavItem(Icons.person, 'Profile', 4),
        ],
      ),
    );
  }

  /// Builds a BottomNavigationBarItem with the required circular icon style if selected
  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: isSelected 
          ? CircleIcon(icon: icon, size: 35) 
          : Icon(icon),
      label: label,
    );
  }

  BottomNavigationBarItem _buildMessagesNavItem(ChatService chatService, String? userId) {
    bool isSelected = _selectedIndex == 3;
    
    return BottomNavigationBarItem(
      icon: userId == null 
        ? Icon(isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline)
        : StreamBuilder<int>(
            stream: chatService.getTotalUnreadCount(userId),
            builder: (context, snapshot) {
              int unreadCount = snapshot.data ?? 0;
              
              return Container(
                width: 45, // Fixed width to prevent jumping and allow space for badge
                height: 30,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    isSelected 
                        ? const CircleIcon(icon: Icons.chat_bubble, size: 32) 
                        : const Icon(Icons.chat_bubble_outline, size: 26),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      label: 'Messages',
    );
  }
}
