import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:chatting_app/Helper/privacy.dart';
import 'package:chatting_app/Helper/themes.dart';
import 'package:chatting_app/Model/chatModel.dart';
import 'package:chatting_app/Model/messageModel.dart';
import 'package:chatting_app/Model/userModel.dart';
import 'package:chatting_app/Screens/home/profileScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key, required this.chatRoom, required this.currentUser, required this.searchedUser}) : super(key: key);
  final ChatModel chatRoom;
  final UserModel currentUser;
  final UserModel? searchedUser;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final uuid = const Uuid();
  MessageModel? msgDetails;
  TextEditingController msgController = TextEditingController();
  File? chatFile;
  File? thumbFile;
  bool doReply = false;
  String replyMsg = '';
  enc.Encrypted? encryptedMsg;
  List<String> chattedDate = [];
  bool scrollingUp = false;
  bool prevScroll = false;

  @override
  void initState() {
    updateUserOnlineStatus(true);
    super.initState();
  }

  updateUserOnlineStatus(bool status) async {
    await FirebaseFirestore.instance
        .collection("chatRooms")
        .doc(widget.chatRoom.chatRoomId)
        .update({"online.${widget.currentUser.id.toString()}": status, "unreadMsg.${widget.currentUser.id.toString()}": 0});
  }

  updateMessageOnlineStatus(String docId, bool status) async {
    await FirebaseFirestore.instance
        .collection("chatRooms")
        .doc(widget.chatRoom.chatRoomId)
        .collection("messages")
        .doc(docId)
        .update({"seen": status}).then((value) {});
  }

  openImagePicker() async {
    String msgType = '';
    var file = await FilePicker.platform.pickFiles();
    if (file != null) {
      String path = file.files.single.path!;
      chatFile = File(path);
      String extension = path.trim().split(".").last;
      print("extension  " + extension);

      if (extension == "jpg" || extension == "png") {
        msgType = "img";
      } else if (extension == "mp4") {
        msgType = "video";
        final thumbData = await VideoThumbnail.thumbnailFile(video: path, imageFormat: ImageFormat.PNG, quality: 80);
        thumbFile = File(thumbData.toString());
      } else if (extension == "pdf") {
        msgType = "pdf";
      } else {
        msgType = "random";
      }

      var data = MessageModel(
          msgType: msgType,
          msg: "dummy data",
          msgId: uuid.v1(),
          senderId: widget.currentUser.id,
          createdOn: Timestamp.now(),
          seen: false,
          thumbnail: "dummy data");

      await FirebaseFirestore.instance
          .collection("chatRooms")
          .doc(widget.chatRoom.chatRoomId.toString())
          .collection("messages")
          .doc(data.msgId)
          .set(data.toMap())
          .then((value) {
        uploadFile(data: data);
      });
    }
  }

  uploadFile({required MessageModel data}) async {
    TaskSnapshot uploadedThumbnail;
    Map<String, dynamic> chatBoxData = {};

    var uploadedFile =
        await FirebaseStorage.instance.ref(widget.chatRoom.chatRoomId.toString()).child(data.msgId.toString()).putFile(chatFile!);
    String urlFile = await uploadedFile.ref.getDownloadURL();
    Map<String, dynamic> sendData = {"msg": urlFile};
    print("file done");

    if (data.msgType == "img") {
      chatBoxData = {"lastMsgTime": data.createdOn, "lastMsg": "Photo"};
    } else if (data.msgType == "video") {
      print("thumb uploading");
      uploadedThumbnail = await FirebaseStorage.instance
          .ref(widget.chatRoom.chatRoomId.toString())
          .child("Thumbnails")
          .child(data.msgId.toString())
          .putFile(thumbFile!);
      print("thumb uploaded");
      String urlThumb = await uploadedThumbnail.ref.getDownloadURL();
      print("url generated");
      sendData["thumbnail"] = urlThumb;
      chatBoxData = {"lastMsgTime": data.createdOn, "lastMsg": "Video"};
    } else {
      chatBoxData = {"lastMsgTime": data.createdOn, "lastMsg": "Unknown Data"};
    }

    if (urlFile.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("chatRooms")
          .doc(widget.chatRoom.chatRoomId.toString())
          .collection("messages")
          .doc(data.msgId)
          .update(sendData)
          .then((value) async {
        await FirebaseFirestore.instance.collection("chatRooms").doc(widget.chatRoom.chatRoomId).update(chatBoxData);
      });
    }
  }

  final snackBar = const SnackBar(content: Text("Error launching URL"));

  @override
  void dispose() {
    updateUserOnlineStatus(false);
    super.dispose();
  }

  // Time label code starts
  // function to convert time stamp to date
  static DateTime returnDateAndTimeFormat(Timestamp time) {
    var dt = DateTime.fromMillisecondsSinceEpoch(time.millisecondsSinceEpoch * 1000);
    return DateTime(dt.year, dt.month, dt.day);
  }

  // function to return date if date changes based on your local date and time
  static String groupMessageDateAndTime(Timestamp time) {
    var dt = DateTime.fromMicrosecondsSinceEpoch(time.millisecondsSinceEpoch * 1000);

    final todayDate = DateTime.now();

    final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
    final yesterday = DateTime(todayDate.year, todayDate.month, todayDate.day - 1);
    String difference = '';
    final aDate = DateTime(dt.year, dt.month, dt.day);

    if (aDate == today) {
      difference = "Today";
    } else if (aDate == yesterday) {
      difference = "Yesterday";
    } else {
      difference = "${dt.day} - ${dt.month} - ${dt.year}";
    }

    return difference;
  }

  // Time label code

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 70,
          leadingWidth: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.arrow_back_sharp,
                    color: Colors.black,
                  )),
              CircleAvatar(
                radius: 25,
                backgroundColor: CustomColor.friendColor,
                backgroundImage: widget.searchedUser!.profile != "" && widget.searchedUser!.profile != null
                    ? NetworkImage(widget.searchedUser!.profile.toString())
                    : null,
                child: IconButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(searchedUser: widget.searchedUser!),
                          ));
                    },
                    icon: widget.searchedUser!.profile != "" && widget.searchedUser!.profile != null
                        ? Container()
                        : const Icon(
                            Icons.person,
                            color: Colors.white,
                          )),
              ),
              const SizedBox(
                width: 15,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.searchedUser!.name.toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      widget.searchedUser!.email.toString(),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w400),
                      overflow: TextOverflow.fade,
                    )
                  ],
                ),
              )
            ],
          ),
          actions: [
            IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.call,
                  color: Colors.black,
                )),
            IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(
                          "Do you want to Delete All Chats and Photos ? ",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        content: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  "Cancel",
                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 18),
                                )),
                            const SizedBox(
                              width: 10,
                            ),
                            TextButton(
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection("chatRooms")
                                      .doc(widget.chatRoom.chatRoomId.toString())
                                      .collection("messages")
                                      .get()
                                      .then((value) {
                                    for (var docs in value.docs) {
                                      docs.reference.delete();
                                    }
                                  }).then((value) async {
                                    await FirebaseStorage.instance
                                        .ref(widget.chatRoom.chatRoomId.toString())
                                        .listAll()
                                        .then((value) {
                                      for (var element in value.items) {
                                        element.delete();
                                      }
                                    }).then((value) async {
                                      Navigator.pop(context);
                                      await FirebaseFirestore.instance
                                          .collection("chatRooms")
                                          .doc(widget.chatRoom.chatRoomId.toString())
                                          .update({
                                        "lastMsg": "",
                                        "unreadMsg.${widget.searchedUser!.id.toString()}": 0,
                                        "unreadMsg.${widget.currentUser.id.toString()}": 0
                                      });
                                    });
                                  });
                                },
                                child: Text("Delete",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .copyWith(color: CustomColor.unreadMsg, fontSize: 18)))
                          ],
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(
                  Icons.delete,
                  color: Colors.black,
                ))
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                /// ************* CHECKING FRIEND ONLINE STATUS  ******************
                child: StreamBuilder(
                  stream:
                      FirebaseFirestore.instance.collection("chatRooms").doc(widget.chatRoom.chatRoomId.toString()).snapshots(),
                  builder: (context, chatRoomSnapshot) {
                    return StreamBuilder(
                      /// ************* FETCHING CHAT DATA  ******************
                      stream: FirebaseFirestore.instance
                          .collection("chatRooms")
                          .doc(widget.chatRoom.chatRoomId.toString())
                          .collection("messages")
                          .orderBy("createdOn", descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          List<MessageModel> messageList = snapshot.data!.docs.map((e) {
                            return MessageModel.fromJson(e.data());
                          }).toList();


                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            reverse: true,
                            itemCount: messageList.length,
                            itemBuilder: (context, index) {
                              if (chatRoomSnapshot.hasData) {
                                if (messageList[index].senderId.toString() != widget.currentUser.id.toString()) {
                                  bool isOnline = chatRoomSnapshot.data!["online"][widget.currentUser.id];
                                  if (isOnline == true && messageList[index].seen == false) {
                                    updateMessageOnlineStatus(messageList[index].msgId.toString(), true);
                                  }
                                }
                              }

                              ///*************************   SHOW TEXT IN CHAT   *******************************
                              if (messageList[index].msgType == "text") {
                                String theMsg = "";
                                String theRepliedMsg = "";
                                if (messageList[index].isEncrypted != null) {
                                  theMsg = MessagePrivacy.decryption(messageList[index].msg.toString());
                                  theRepliedMsg = messageList[index].repliedTo.toString() != ""
                                      ? MessagePrivacy.decryption(messageList[index].repliedTo.toString())
                                      : messageList[index].repliedTo.toString();
                                } else {
                                  theMsg = messageList[index].msg.toString();
                                  theRepliedMsg = messageList[index].repliedTo.toString();
                                }
                                return Column(
                                  children: [
                                    Dismissible(
                                      key: UniqueKey(),
                                      direction: messageList[index].senderId == widget.currentUser.id
                                          ? DismissDirection.endToStart
                                          : DismissDirection.startToEnd,
                                      dismissThresholds: messageList[index].senderId == widget.currentUser.id
                                          ? const {DismissDirection.endToStart: 0.5}
                                          : const {DismissDirection.startToEnd: 0.5},
                                      onUpdate: (details) {
                                        if (details.reached) {
                                          setState(() {
                                            doReply = true;
                                            replyMsg = theMsg;
                                          });
                                        }
                                      },
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width - 30,
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: messageList[index].senderId == widget.currentUser.id
                                                ? MainAxisAlignment.end
                                                : MainAxisAlignment.start,
                                            children: [
                                              Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                                                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
                                                  decoration: BoxDecoration(
                                                      color: messageList[index].senderId == widget.currentUser.id
                                                          ? CustomColor.userColor
                                                          : CustomColor.friendColor,
                                                      borderRadius: messageList[index].senderId == widget.currentUser.id
                                                          ? const BorderRadius.only(
                                                              bottomRight: Radius.circular(15),
                                                              topRight: Radius.zero,
                                                              topLeft: Radius.circular(15),
                                                              bottomLeft: Radius.circular(15))
                                                          : const BorderRadius.only(
                                                              bottomRight: Radius.circular(15),
                                                              topRight: Radius.circular(15),
                                                              topLeft: Radius.zero,
                                                              bottomLeft: Radius.circular(15))),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        messageList[index].senderId.toString() == widget.currentUser.id.toString()
                                                            ? CrossAxisAlignment.end
                                                            : CrossAxisAlignment.start,
                                                    children: [
                                                      theRepliedMsg != ''
                                                          ? Container(
                                                              /// SHOW REPLIED MESSAGE TEXT
                                                              constraints: const BoxConstraints(
                                                                  maxWidth: 295, maxHeight: 100, minWidth: 85),
                                                              padding:
                                                                  const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 6),
                                                              margin: const EdgeInsets.only(bottom: 5),
                                                              decoration: BoxDecoration(
                                                                borderRadius: BorderRadius.circular(10),
                                                                color: const Color(0xFFeaf7e4),
                                                                border: Border.all(width: 0.1),
                                                              ),
                                                              child: Text(
                                                                theRepliedMsg,
                                                                overflow: TextOverflow.fade,
                                                              ),
                                                            )
                                                          : Container(),
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          LimitedBox(
                                                            maxWidth: MediaQuery.of(context).size.width / 1.5,
                                                            child: Linkify(
                                                              onOpen: (link) async {
                                                                if (await canLaunchUrl(Uri.parse(link.url))) {
                                                                  await launchUrl(
                                                                    Uri.parse(link.url),
                                                                    mode: LaunchMode.externalApplication,
                                                                  );
                                                                } else {
                                                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                                                }
                                                              },
                                                              text: theMsg,
                                                              style: Theme.of(context).textTheme.bodyMedium,
                                                              softWrap: true,
                                                              maxLines: null,
                                                              linkifiers: const [EmailLinkifier(), UrlLinkifier()],
                                                              linkStyle: const TextStyle(color: Colors.blueAccent),
                                                              textAlign: TextAlign.start,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            "${messageList[index].createdOn!.toDate().hour}:${(messageList[index].createdOn!.toDate().minute).toString().padLeft(2, "0")}",
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall!
                                                                .copyWith(fontStyle: FontStyle.italic),
                                                          ),
                                                          messageList[index].senderId == widget.currentUser.id
                                                              ? (Icon(Icons.check,
                                                                  color:
                                                                      messageList[index].seen == true ? Colors.blue : Colors.grey,
                                                                  size: 17))
                                                              : const SizedBox(
                                                                  width: 2,
                                                                )
                                                        ],
                                                      ),
                                                    ],
                                                  ))
                                            ]),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              /// ****************** SHOW IMAGES IN CHAT *********************
                              else if (messageList[index].msgType == "img") {
                                return Dismissible(
                                  key: UniqueKey(),
                                  dismissThresholds: messageList[index].senderId == widget.currentUser.id
                                      ? const {DismissDirection.endToStart: 0.5}
                                      : const {DismissDirection.startToEnd: 0.5},
                                  onUpdate: (details) {
                                    if (details.reached) {
                                      setState(() {
                                        doReply = true;
                                        replyMsg = messageList[index].msg.toString();
                                      });
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: messageList[index].senderId == widget.currentUser.id
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.symmetric(vertical: 3),
                                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                                        decoration: BoxDecoration(
                                            color: messageList[index].senderId == widget.currentUser.id
                                                ? const Color(0xFFb3f2c7)
                                                : const Color(0xFFa8e5f0),
                                            borderRadius: messageList[index].senderId == widget.currentUser.id
                                                ? const BorderRadius.only(
                                                    bottomRight: Radius.circular(15),
                                                    topRight: Radius.zero,
                                                    topLeft: Radius.circular(15),
                                                    bottomLeft: Radius.circular(15))
                                                : const BorderRadius.only(
                                                    bottomRight: Radius.circular(15),
                                                    topRight: Radius.circular(15),
                                                    topLeft: Radius.zero,
                                                    bottomLeft: Radius.circular(15))),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            LimitedBox(
                                              maxWidth: MediaQuery.of(context).size.width / 1.5,
                                              maxHeight: MediaQuery.of(context).size.height / 2.5,
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ShowImage(imgUrl: messageList[index].msg.toString()),
                                                      ));
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: CachedNetworkImage(
                                                      imageUrl: messageList[index].msg.toString(),
                                                      fit: BoxFit.fill,
                                                      placeholder: (context, url) => Container(
                                                            color: Colors.grey,
                                                            child: const Center(child: CircularProgressIndicator()),
                                                          ),
                                                      errorWidget: (context, url, error) {
                                                        if (url == "dummy data") {
                                                          return Container(
                                                            color: Colors.grey,
                                                            child: const Center(child: CircularProgressIndicator()),
                                                          );
                                                        } else {
                                                          return Text(
                                                            " ** An error Occurred while Loading Img **",
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall!
                                                                .copyWith(fontStyle: FontStyle.italic),
                                                          );
                                                        }
                                                      }),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 2,
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  "${messageList[index].createdOn!.toDate().hour}:${(messageList[index].createdOn!.toDate().minute).toString().padLeft(2, "0")}",
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall!
                                                      .copyWith(fontStyle: FontStyle.italic),
                                                ),
                                                messageList[index].senderId == widget.currentUser.id
                                                    ? (Icon(Icons.check,
                                                        color: messageList[index].seen == true ? Colors.blue : Colors.grey,
                                                        size: 17))
                                                    : const SizedBox(
                                                        width: 4,
                                                      )
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                /// ****************** SHOW VIDEOS IN CHAT *********************
                              } else if (messageList[index].msgType == "video") {
                                return Dismissible(
                                  key: UniqueKey(),
                                  dismissThresholds: messageList[index].senderId == widget.currentUser.id
                                      ? const {DismissDirection.endToStart: 0.5}
                                      : const {DismissDirection.startToEnd: 0.5},
                                  onUpdate: (details) {
                                    if (details.reached) {
                                      setState(() {
                                        doReply = true;
                                        replyMsg = messageList[index].msg.toString();
                                      });
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: messageList[index].senderId == widget.currentUser.id
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.symmetric(vertical: 3),
                                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                                        decoration: BoxDecoration(
                                            color: messageList[index].senderId == widget.currentUser.id
                                                ? const Color(0xFFb3f2c7)
                                                : const Color(0xFFa8e5f0),
                                            borderRadius: messageList[index].senderId == widget.currentUser.id
                                                ? const BorderRadius.only(
                                                    bottomRight: Radius.circular(15),
                                                    topRight: Radius.zero,
                                                    topLeft: Radius.circular(15),
                                                    bottomLeft: Radius.circular(15))
                                                : const BorderRadius.only(
                                                    bottomRight: Radius.circular(15),
                                                    topRight: Radius.circular(15),
                                                    topLeft: Radius.zero,
                                                    bottomLeft: Radius.circular(15))),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            LimitedBox(
                                              maxWidth: MediaQuery.of(context).size.width / 1.5,
                                              maxHeight: MediaQuery.of(context).size.height / 2.5,
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            PlayVideo(videoUrl: messageList[index].msg.toString()),
                                                      ));
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: CachedNetworkImage(
                                                      imageUrl: messageList[index].thumbnail.toString(),
                                                      fit: BoxFit.fill,
                                                      placeholder: (context, url) => Container(
                                                            color: Colors.grey,
                                                            child: const Center(child: CircularProgressIndicator()),
                                                          ),
                                                      errorWidget: (context, url, error) {
                                                        if (url == "dummy data") {
                                                          return Container(
                                                            color: Colors.grey,
                                                            child: const Center(child: CircularProgressIndicator()),
                                                          );
                                                        } else {
                                                          return Text(
                                                            " ** An error Occurred while Loading Video **",
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall!
                                                                .copyWith(fontStyle: FontStyle.italic),
                                                          );
                                                        }
                                                      }),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 2,
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  "${messageList[index].createdOn!.toDate().hour}:${(messageList[index].createdOn!.toDate().minute).toString().padLeft(2, "0")}",
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall!
                                                      .copyWith(fontStyle: FontStyle.italic),
                                                ),
                                                messageList[index].senderId == widget.currentUser.id
                                                    ? (Icon(Icons.check,
                                                        color: messageList[index].seen == true ? Colors.blue : Colors.grey,
                                                        size: 17))
                                                    : const SizedBox(
                                                        width: 4,
                                                      )
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                /// ****************** SHOW PDF IN CHAT *********************
                              } else if (messageList[index].msgType == "pdf") {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: messageList[index].senderId == widget.currentUser.id
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: const [
                                    Text("pdf Data"),
                                  ],
                                );
                              } else {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: messageList[index].senderId == widget.currentUser.id
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: const [
                                    Text("Random Data"),
                                  ],
                                );
                              }
                            },
                          );
                        } else if (snapshot.hasError) {
                          return const Text("Please Check Your Internet Connection");
                        } else {
                          return const Text("Say Hii to Your Friend");
                        }
                      },
                    );
                  },
                ),
              ),

              ///****************   BOTTOM TEXT FIELD, SEND FILES   ************************
              Container(
                // height: 60,
                margin: const EdgeInsets.only(top: 3, bottom: 2, left: 10, right: 10),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(top: 4, bottom: 4, right: 5),
                        decoration: BoxDecoration(
                            color: doReply ? Colors.blueGrey[300] : null,
                            borderRadius: const BorderRadius.all(Radius.circular(15))),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            doReply
                                ? Align(
                                    alignment: Alignment.topRight,
                                    child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            replyMsg = "";
                                            doReply = false;
                                          });
                                        },
                                        child: const Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.white,
                                          size: 15,
                                        )))
                                : Container(),
                            doReply
                                ? Container(
                                    constraints: const BoxConstraints(maxHeight: 70, minHeight: 30),
                                    // height: 70,
                                    width: 280,
                                    padding: const EdgeInsets.only(left: 10, right: 0, top: 5, bottom: 3),
                                    margin: const EdgeInsets.only(bottom: 5),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: const Color(0xFFeaf7e4),
                                      border: Border.all(width: 0.1),
                                    ),
                                    child: Text(replyMsg, style: const TextStyle(), overflow: TextOverflow.fade),
                                  )
                                : Container(),
                            Row(
                              children: [
                                ElevatedButton(
                                    onPressed: () {
                                      openImagePicker();
                                    },
                                    style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.all(2),
                                        backgroundColor: Colors.transparent,
                                        elevation: 0,
                                        minimumSize: const Size(40, 50)),
                                    child: SizedBox(
                                        child: Image.asset(
                                      "assets/images/Clip.png",
                                      width: 22,
                                    ))),
                                Expanded(
                                  child: Container(
                                    // width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                    child: LimitedBox(
                                      maxHeight: 70,
                                      child: SizedBox(
                                        // width: 236,
                                        child: TextField(
                                          style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: Colors.black),
                                          controller: msgController,
                                          textCapitalization: TextCapitalization.sentences,
                                          maxLines: null,
                                          keyboardType: TextInputType.multiline,
                                          decoration: InputDecoration(
                                              focusedBorder: const OutlineInputBorder(
                                                  borderRadius: BorderRadius.all(Radius.circular(15)),
                                                  borderSide: BorderSide(color: Colors.transparent)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                              filled: true,
                                              fillColor: Colors.black12,
                                              hintText: "Enter Text...",
                                              hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.blueGrey),
                                              enabledBorder: const OutlineInputBorder(
                                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                                  borderSide: BorderSide(color: Colors.transparent))),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 3, bottom: 6),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF20A090),
                        radius: 25,
                        child: IconButton(
                            onPressed: () {
                              sendMessage();
                            },
                            icon: const Icon(
                              Icons.send_sharp,
                              color: Colors.white,
                            )),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ));
  }

  Future<int> messageIncrement() async {
    var chatData = await FirebaseFirestore.instance.collection("chatRooms").doc(widget.chatRoom.chatRoomId).get();
    var count = chatData.data()!["unreadMsg"][widget.searchedUser!.id.toString()];
    // print("count" + count.toString());
    var data = count;
    if (chatData.data()!["online"][widget.searchedUser!.id.toString()] == false) {
      data = count + 1;
    }

    return data;
  }

  sendMessage() {
    if (msgController.text.isNotEmpty) {
      String msg = msgController.text.trim();
      String msgEncrypted = MessagePrivacy.encryption(msgController.text.trim());
      msgController.clear();
      msgDetails = MessageModel(
          msg: msgEncrypted,
          msgId: uuid.v1(),
          senderId: widget.currentUser.id,
          createdOn: Timestamp.now(),
          seen: false,
          msgType: "text",
          isEncrypted: true,
          repliedTo: replyMsg != "" ? MessagePrivacy.encryption(replyMsg) : replyMsg);

      setState(() {
        replyMsg = '';
        doReply = false;
      });

      if (msgDetails != null) {
        FirebaseFirestore.instance
            .collection("chatRooms")
            .doc(widget.chatRoom.chatRoomId.toString())
            .collection("messages")
            .doc(msgDetails!.msgId.toString())
            .set(msgDetails!.toMap())
            .then((value) async {

            if(widget.searchedUser != null){
              widget.searchedUser!.fcmToken != "" ? sendNotificationToOtherUsers(widget.searchedUser!.fcmToken!, msg, widget.searchedUser!.name!) : null;
            }

          var updateData = {
            "lastMsg": msgEncrypted,
            "lastMsgTime": msgDetails!.createdOn,
            "unreadMsg.${widget.searchedUser!.id.toString()}": await messageIncrement()
          };

          await FirebaseFirestore.instance.collection("chatRooms").doc(widget.chatRoom.chatRoomId.toString()).update(updateData);
        });
      }
    }
  }

  Future<void> sendNotificationToOtherUsers(String targetUserToken, String message, String userName) async {
    try {
      String serverKey =
          "AAAAod7L1hE:APA91bFFIqK7xIjtaRkOIWp2oqQCOCzPf7R7uphe5QCYn9PifKBDV9SQsw2IMi3AZZezGsxM0hxLRxF3SMhM07XF7iMQRdMYOuaAI-oMT6bCq8ZX4ZlEzxiFCRIMVSe1Lg7b878IE7Mm"; // You can find this key in the Firebase Console under "Project settings" -> "Cloud Messaging"
      String url = 'https://fcm.googleapis.com/fcm/send';

      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      };

      Map<String, dynamic> data = {
        'to': targetUserToken,
        'data': {
          'title': userName,
          'body': message,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK', // Optional, customize the action when the user taps the notification
        },
      };

      String body = jsonEncode(data);

      final response = await http.post(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200) {
        print('Notification sent successfully.');
      } else {
        print('Failed to send notification. Error: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}

class ShowImage extends StatelessWidget {
  final String imgUrl;

  const ShowImage({required this.imgUrl, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
          top: true,
          bottom: true,
          child: Center(
              child: InteractiveViewer(
                  maxScale: double.infinity,
                  clipBehavior: Clip.none,
                  boundaryMargin: const EdgeInsets.all(0),
                  child: CachedNetworkImage(
                    imageUrl: imgUrl,
                    placeholder: (context, url) {
                      return const Center(
                        child: LinearProgressIndicator(),
                      );
                    },
                  )))),
    );
  }
}

class PlayVideo extends StatefulWidget {
  const PlayVideo({Key? key, required this.videoUrl}) : super(key: key);
  final String videoUrl;

  @override
  State<PlayVideo> createState() => _PlayVideoState();
}

class _PlayVideoState extends State<PlayVideo> {
  late VideoPlayerController _controller;
  String position = '';
  String duration = '';
  double currentVolume = 0.5;

  @override
  void initState() {
    print("in init");
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..addListener(() {
        setState(() {
          position = _controller.value.position.toString().trim().split('.').first;
        });
      })
      ..initialize().then((value) {
        if (mounted) {
          setState(() {
            duration = _controller.value.duration.toString().split('.').first;
          });
        }
      });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(
                    _controller,
                  ),
                )
              : const Center(child: Text("Loading...")),
          // SizedBox(height: 10,),
          if (_controller.value.isInitialized) ...[
            VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            ),
            Row(
              children: [
                IconButton(
                    onPressed: () {
                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      setState(() {});
                    },
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    )),
                Text(
                  "$position/$duration",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(
                  width: 32,
                ),
                customVolumeIcon(),
                SizedBox(
                  width: 160,
                  child: Slider(
                    value: currentVolume,
                    onChanged: (value) {
                      setState(() {
                        currentVolume = value;
                        _controller.setVolume(value);
                      });
                    },
                    max: 1,
                    min: 0,
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget customVolumeIcon() {
    return const Icon(
      Icons.volume_up_sharp,
      size: 20,
    );
  }
}
