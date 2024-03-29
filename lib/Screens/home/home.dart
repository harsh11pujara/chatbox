import 'package:chatting_app/Model/userModel.dart';
import 'package:chatting_app/Screens/home/callsScreen.dart';
import 'package:chatting_app/Screens/home/contactsScreen.dart';
import 'package:chatting_app/Screens/home/messageScreen.dart';
import 'package:chatting_app/Screens/home/profileScreen.dart';
import 'package:chatting_app/Screens/home/searchScreen.dart';
import 'package:chatting_app/Screens/home/settingScreen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, required this.userData}) : super(key: key);
  final UserModel userData;

  @override
  State<HomeScreen> createState() => _HomeScreenState(user: this.userData);
}

class _HomeScreenState extends State<HomeScreen> {
  int navBarIndex = 0;
  late UserModel user;

  late List<Widget> screenBodyList = [
    MessageScreen(userData: user),
    const CallsScreen(),
    const ContactsScreen(),
    SettingScreen(userData: user,)
  ];

  _HomeScreenState({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: customAppBar(navBarIndex),
      body: screenBodyList[navBarIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF24786D),
        unselectedItemColor: const Color(0xFF797C7B),
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        iconSize: 28,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Messages',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.contacts_outlined), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
        currentIndex: navBarIndex,
        onTap: (value) {
          setState(() {
            navBarIndex = value;
          });
        },
      ),
    );
  }

  AppBar customAppBar(int index) {
    List screenTile = ["Home", "Calls", "Contacts", "Settings"];
    return AppBar(
      leadingWidth: 80,
      leading: Container(
        margin: const EdgeInsets.fromLTRB(15, 15, 0, 0),
        // height: 10,
        // width: 10,
        decoration:
            index != 3 ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 0.5)) : null,
        child: Align(
          alignment: index != 3 ? Alignment.center : Alignment.center,
          child: IconButton(
              onPressed: () {
                if (index == 0) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchScreen(userData: widget.userData),
                      ));
                }
              },
              icon: Icon(
                index != 3 ? Icons.search :null,
                color: Colors.white,
                size: index != 3 ? 35 : 25,
              )),
        ),
      ),
      title: Text(
        screenTile[index],
        style: Theme.of(context).textTheme.titleLarge,
      ),
      toolbarHeight: 100,
      actions: [
        appBarRightWidget(index),
        const SizedBox(
          width: 15,
        )
      ],
    );
  }

  Widget appBarRightWidget(int index) {
    if (index == 0) {
      return CircleAvatar(
        backgroundColor: Colors.greenAccent,
        backgroundImage: widget.userData.profile != "" && widget.userData.profile != null ? NetworkImage(widget.userData.profile.toString()) : null,
        radius: 30,
        child: widget.userData.profile != "" && widget.userData.profile != null ? null : const Icon(Icons.person,color: Colors.white),
      );
    } else if (index == 1) {
      return Container(
          margin: const EdgeInsets.fromLTRB(15, 15, 0, 0),
          padding: const EdgeInsets.all(10),
          height: 60,
          width: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 0.5)),
          child: const Center(
            child: Icon(
              Icons.add_call,
              color: Colors.white,
              size: 35,
            ),
          ));
    } else if (index == 2) {
      return Container(
          margin: const EdgeInsets.fromLTRB(15, 15, 0, 0),
          padding: const EdgeInsets.all(15),
          height: 60,
          width: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 0.5)),
          child: const Center(
            child: Icon(
              Icons.person_add_alt_1_sharp,
              color: Colors.white,
              size: 35,
            ),
          ));
    } else {
      return Container();
    }
  }
}
