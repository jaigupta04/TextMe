import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/chat_screen.dart'; // Import the ChatScreen

class HomePage extends StatefulWidget {
  final String currentUserContact;

  const HomePage({Key? key, required this.currentUserContact}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _friendContactController = TextEditingController();

  @override
  void dispose() {
    _friendContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Home'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: widget.currentUserContact)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No chats yet. Add a friend!'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var chat = snapshot.data!.docs[index];
              List participants = chat['participants'];
              String friendContact = participants.firstWhere(
                  (contact) => contact != widget.currentUserContact);

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .where('contactNumber', isEqualTo: friendContact)
                    .limit(1)
                    .get(),
                builder: (context, friendUserSnapshot) {
                  if (friendUserSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Loading User...'),
                    );
                  }
                  if (friendUserSnapshot.hasData && friendUserSnapshot.data!.docs.isNotEmpty) {
                    var friendData = friendUserSnapshot.data!.docs.first.data() as Map<String, dynamic>?;
                    String friendName = friendData?['name'] ?? 'Unknown User';
                    return ListTile(
                      leading: CircleAvatar(child: Text(friendName[0])),
                      title: Text(friendName),
                      subtitle: Text(friendContact),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              currentUserContact: widget.currentUserContact,
                              friendContact: friendContact,),
                          ),
                        );
                      },
                    );
                  } else {
                    return ListTile(
                      leading: CircleAvatar(child: Icon(Icons.error)),
                      title: Text('Error loading user'),
                      subtitle: Text(friendContact),
                    );
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Add Friend'),
                content: TextField(
                  controller: _friendContactController,
                  decoration: InputDecoration(labelText: 'Enter friend\'s contact number'),
                  keyboardType: TextInputType.phone,
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('Add'),
                    onPressed: () {
                      print('Attempting to add friend with contact: ${_friendContactController.text}');
                      _findAndAddFriend(context, _friendContactController.text);
                    },
                  ),
                ],
              );
            },
          );
        },
        tooltip: 'Add Friend',
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _findAndAddFriend(BuildContext context, String contactNumber) async {
    String currentUserContact = widget.currentUserContact;

    if (contactNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a contact number.')),
      );
      return;
    }

    if (contactNumber == currentUserContact) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You cannot add yourself.')),
      );
      return;
    }

    try {
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('contactNumber', isEqualTo: contactNumber)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        QuerySnapshot existingChats = await FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserContact)
            .get();

        bool chatExists = existingChats.docs.any((doc) {
          List participants = doc['participants'];
          return participants.contains(contactNumber);
        });

        if (!chatExists) {
          await FirebaseFirestore.instance.collection('chats').add({
            'participants': [currentUserContact, contactNumber],
            'createdAt': Timestamp.now(),
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Friend added and chat created!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chat with this user already exists.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No user found with this contact number.')),
        );
      }
    } catch (e) {
      print('Error adding friend: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding friend: ${e.toString()}')),
      );
    } finally {
      Navigator.of(context).pop();
      _friendContactController.clear();
    }
  }
}
