import 'package:chatting_app/Model/chatGroupModel.dart';
import 'package:chatting_app/Model/chatModel.dart';
import 'package:chatting_app/Model/userModel.dart';
import 'package:chatting_app/Screens/home/chatScreen.dart';
import 'package:chatting_app/Screens/home/createGroupScreen.dart';
import 'package:chatting_app/Screens/home/groupChatScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key, required this.userData}) : super(key: key);
  final UserModel userData;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final uuid = const Uuid();
  TextEditingController searchController = TextEditingController();
  UserModel? searchedUser;
  ChatModel? openChat;

  //***********************  CREATE CHATROOM  ***************************
  Future<ChatModel?> openChatRoom() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("chatRooms")
        .where("participants.${widget.userData.id}", isEqualTo: true)
        .where("participants.${searchedUser!.id}", isEqualTo: true)
        .get();

    if (snapshot.docs.isNotEmpty) {
      print("open room");
      ChatModel existingChatRoom = ChatModel.fromJson(snapshot.docs[0].data() as Map<String, dynamic>);
      openChat = existingChatRoom;
    } else {
      var chatroom = ChatModel(
          chatRoomId: widget.userData.id.toString() + searchedUser!.id.toString(),
          participants: [widget.userData.id.toString(), searchedUser!.id.toString()],
          lastMsg: "",
          lastMsgTime: null,
          online: {widget.userData.id.toString(): true, searchedUser!.id.toString(): false},
          unreadMsg: {widget.userData.id.toString(): 0, searchedUser!.id.toString(): 0});

      print("create room");
      await FirebaseFirestore.instance.collection("chatRooms").doc(chatroom.chatRoomId.toString()).set(chatroom.toMap());
      openChat = chatroom;
    }

    return openChat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text('Search Screen'),
      ),
      body: Container(
        padding: const EdgeInsets.only(bottom: 5, top: 20, right: 20, left: 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateGroupScreen(userData: widget.userData),
                          ));
                    },
                    child: Text("Create Group")),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                child: TextField(
                  onChanged: (value) {
                    setState(() {});
                  },
                  controller: searchController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    label: Text('Search'),
                    hintText: "Enter Email",
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text("Search")),
              const SizedBox(
                height: 30,
              ),
              const Text(
                "People",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              ),
              const SizedBox(
                height: 10,
              ),
              SizedBox(
                height: 200,
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .where("email", isGreaterThanOrEqualTo: searchController.text)
                      .where("email", isLessThanOrEqualTo: "${searchController.text}~")
                      .where("email", isNotEqualTo: widget.userData.email.toString())
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && searchController.text.isNotEmpty) {
                      print("snapshot got data ${snapshot.data!.docs.length}");
                      if (snapshot.data != null) {
                        QuerySnapshot data = snapshot.data!;
                        if (data.docs.isNotEmpty) {
                          List<UserModel> searchedUserList = data.docs.map((e) {
                            return UserModel.fromJson(e.data() as Map<String, dynamic>);
                          }).toList();

                          return ListView.builder(
                            itemCount: searchedUserList.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: EdgeInsets.symmetric(vertical: 3),
                                color: Colors.black,
                                child: ListTile(
                                  onTap: () async {
                                    searchedUser = searchedUserList[index];
                                    await openChatRoom().then((chatModelValue) {
                                      if (chatModelValue != null) {
                                        Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatScreen(
                                                  chatRoom: chatModelValue,
                                                  currentUser: widget.userData,
                                                  searchedUser: searchedUserList[index]),
                                            ));
                                      }
                                    });
                                  },
                                  // tileColor: Colors.black,
                                  leading: const CircleAvatar(radius: 25, child: Icon(Icons.person)),
                                  title: Text(
                                    searchedUserList[index].name.toString(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle:
                                      Text(searchedUserList[index].email.toString(), style: const TextStyle(color: Colors.white)),
                                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                                ),
                              );
                            },
                          );
                        } else {
                          return const Text("No person with such email");
                        }
                      } else {
                        return const Text("No Data Found!");
                      }
                    } else if (snapshot.hasError) {
                      return const Text("An Error Occurred!");
                    } else {
                      return const Text("Search For User!");
                    }
                  },
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const Align(
                child: Text(
                  "Groups",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              SizedBox(
                height: 100,
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("chatGroups")
                      .where("participants", arrayContains: widget.userData.id.toString())
                      .where("groupName", isGreaterThan: searchController.text)
                      .where("groupName", isLessThanOrEqualTo: "${searchController.text}~")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && searchController.text.isNotEmpty) {
                      print("hello");
                      if (snapshot.data!.docs.isNotEmpty) {
                        List<ChatGroupModel> groupList = snapshot.data!.docs.map((e) {
                          return ChatGroupModel.fromJson(e.data());
                        }).toList();
                        return ListView.builder(
                          itemCount: groupList.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                              child: ListTile(
                                onTap: () {
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            GroupChat(chatGroup: groupList[index], currentUser: widget.userData),
                                      ));
                                },
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.group),
                                ),
                                title: Text(groupList[index].groupName.toString()),
                                subtitle: Text(groupList[index].participants.toString(), overflow: TextOverflow.fade),
                              ),
                            );
                          },
                        );
                      } else {
                        return const Text("No group with such name");
                      }
                    } else if (snapshot.hasError) {
                      return const Text("An Error Occurred");
                    } else {
                      return const Text("Search for Groups");
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  searchUser() {}
}
