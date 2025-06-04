import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserContact;
  final String friendContact;

  const ChatScreen({
    Key? key,
    required this.currentUserContact,
    required this.friendContact,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState(); // ✅ FIXED THIS LINE
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentReference? _chatDocRef;

  Map<String, String> _userNamesCache = {};

  @override
  void initState() {
    super.initState();
    _findOrCreateChatDocument();
  }

  void _findOrCreateChatDocument() async {
    List<String> participants = [widget.currentUserContact, widget.friendContact];
    participants.sort();
    String chatId = participants.join('_');

    DocumentReference chatRef = _firestore.collection('chats').doc(chatId);
    DocumentSnapshot chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [widget.currentUserContact, widget.friendContact],
        'createdAt': Timestamp.now(),
      });
    }

    setState(() {
      _chatDocRef = chatRef;
    });
  }

  Future<String> _getFriendName() async {
    var snapshot = await _firestore
        .collection('users')
        .where('contactNumber', isEqualTo: widget.friendContact)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty ? snapshot.docs.first['name'] : 'Unknown User';
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatDocRef == null) return;

    await _chatDocRef!.collection('messages').add({
      'sender': widget.currentUserContact,
      'text': _messageController.text.trim(),
      'timestamp': Timestamp.now(),
    });

    _messageController.clear();
  }

  Future<String> _getUserName(String contactNumber) async {
    if (_userNamesCache.containsKey(contactNumber)) {
      return _userNamesCache[contactNumber]!;
    }

    var snapshot = await _firestore
        .collection('users')
        .where('contactNumber', isEqualTo: contactNumber)
        .limit(1)
        .get();

    String name = 'Unknown User';
    if (snapshot.docs.isNotEmpty) {
      name = snapshot.docs.first['name'] ?? name;
    }

    _userNamesCache[contactNumber] = name;
    return name;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _getFriendName(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }
            return Text(snapshot.data ?? 'Chat');
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatDocRef == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _chatDocRef!
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No messages yet. Start the conversation!'));
                      }

                      final messages = snapshot.data!.docs;

                      return ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index].data() as Map<String, dynamic>;
                          final isCurrentUser = message['sender'] == widget.currentUserContact;

                          return FutureBuilder<String>(
                            future: _getUserName(message['sender']),
                            builder: (context, userSnapshot) {
                              final senderName = userSnapshot.data ?? 'Loading...';
                              final avatar = CircleAvatar(
                                backgroundColor: Colors.blueGrey,
                                child: Text(
                                  senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );

                              final messageBubble = Container(
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                                margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                                decoration: BoxDecoration(
                                  color: isCurrentUser ? Colors.blueAccent : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: isCurrentUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCurrentUser ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      message['text'],
                                      style: TextStyle(
                                        color: isCurrentUser ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  mainAxisAlignment: isCurrentUser
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isCurrentUser) ...[
                                      avatar,
                                      const SizedBox(width: 8.0),
                                    ],
                                    Flexible(child: messageBubble),
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 8.0),
                                      avatar,
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(labelText: 'Enter your message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
