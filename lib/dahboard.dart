import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'const.dart';
import 'feed_screen.dart'; // Import the screen widgets

// Import other screen widgets...

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isHovered = false;
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    UserManagementScreen(),
    const ChatScreen(),
    const TimeClockScreen(),
    const FormScreen(),
    const JobSchedulingScreen(),
    const TasksScreen(),
    const TimeOffScreen()
    // Add other screen widgets here...
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildSideMenu(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildLogoAndSearch(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Row _buildLogoAndSearch() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            print('click');
          },
          child: MouseRegion(
            onEnter: (_) {
              setState(() {
                _isHovered = true;
              });
            },
            onExit: (_) {
              setState(() {
                _isHovered = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Image.asset(
                'assets/LOGO.png', // Replace with your logo asset
                height: _isHovered ? 35 : 30,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: EdgeInsets.only(
            bottom: 10,
          ),
          margin: EdgeInsets.only(bottom: 10, top: 20),
          width: 200,
          height: 40,
          child: TextField(
            decoration: InputDecoration(
              hintStyle: GoogleFonts.openSans(
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: Color.fromARGB(255, 63, 70, 72),
                ),
              ),
              hintText: 'Search anything',
              suffixIcon: Icon(
                Icons.search,
                color: Colors.grey.shade300,
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(width: 0.1, color: Colors.grey),
                borderRadius: BorderRadius.circular(10.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(width: 0.4, color: Colors.green),
                borderRadius: BorderRadius.circular(10.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(width: 0.1, color: Colors.green),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Row _buildActions() {
    return Row(
      children: [
        const SizedBox(width: 20),
        const Text('Help'),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_drop_down),
        const SizedBox(width: 20),
        const Icon(Icons.accessibility),
        const SizedBox(width: 10),
        _buildMessageIcon(),
        const SizedBox(width: 10),
        _buildNotificationIcon(),
        const SizedBox(width: 20),
        const CircleAvatar(
          backgroundColor: Colors.teal,
          child: Text('HN'),
        ),
        const Text('Ha'),
        const Icon(Icons.arrow_drop_down),
      ],
    );
  }

  Stack _buildMessageIcon() {
    return Stack(
      children: <Widget>[
        const Icon(Icons.message),
        Positioned(
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            constraints: const BoxConstraints(
              minWidth: 12,
              minHeight: 12,
            ),
            child: const Text(
              '5',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Stack _buildNotificationIcon() {
    return Stack(
      children: <Widget>[
        const Icon(Icons.notifications),
        Positioned(
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            constraints: const BoxConstraints(
              minWidth: 12,
              minHeight: 12,
            ),
            child: const Text(
              '1',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Container _buildSideMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: 0.5, color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 1), // changes position of shadow
          ),
        ],
      ),
      width: 250, // Adjust the width as needed
      child: ListView(
        children: <Widget>[
          _buildCustomListTile(
            "assets/dashboard.svg",
            "DashBoard",
            0,
            Colors.white,
          ),

          _buildCustomListTile(
            'assets/users-sidebar.svg',
            'Users',
            1,
            Colors.white,
          ),
          // assets/users-sidebar.svg
          const Divider(),
          _buildCustomListTile(
            'assets/Icon_chat.png',
            'Chat',
            2,
            const Color(0xff2ED9B9),
          ),
          _buildCustomListTile(
            'assets/Icon_punch_clock.png',
            'Time Clock',
            3,
            const Color(0xff3786F9),
          ),
          _buildCustomListTile(
            'assets/Icon_forms.png',
            'Forms',
            4,
            const Color(0xffBA39A9),
          ),
          _buildCustomListTile(
            'assets/Icon_Scheduler.png',
            'Job Scheduling',
            5,
            const Color(0xffFF9A6C),
          ),
          _buildCustomListTile(
            'assets/Icon_task_manage.png',
            'Quick Tasks',
            6,
            const Color(0xffFF9A6C),
          ),
          // _buildListTile(Icons.task, 'Quick Tasks', 6),
          // _buildListTile(Icons.timer_off, 'Time Off', 7),
        ],
      ),
    );
  }

  ListTile _buildListTile(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(
          fontWeight:
              _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => _onItemTapped(index),
      selected: _selectedIndex == index,
      trailing: _selectedIndex == index
          ? const Icon(Icons.arrow_right, color: Colors.blue)
          : null,
    );
  }

  ListTile _buildCustomListTile(
    String assetPath,
    String title,
    int index,
    Color color, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: color,
          border: Border.all(color: color),
        ),
        child: _loadImage(assetPath),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight:
              _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => _onItemTapped(index),
      selected: _selectedIndex == index,
      trailing: trailing ??
          (_selectedIndex == index
              ? const Icon(Icons.arrow_right, color: Colors.blue)
              : null),
    );
  }

  Widget _loadImage(String assetPath) {
    if (assetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        // color: Colors.grey,
        assetPath,
        height: 40,
        width: 40,
      );
    } else {
      return Image.asset(
        assetPath,
        color: Colors.white,
        height: 40,
        width: 40,
      );
    }
  }
}
