// ...existing code...
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_room.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Debug: print current user uid for diagnosing permission issues
    print('ChatPage.initState currentUser.uid = ${FirebaseAuth.instance.currentUser?.uid}');
  }

  // SEND MESSAGE TO FIRESTORE
  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to send messages')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'text': text,
        'senderId': user!.uid,
        'email': user!.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      messageController.clear();
    } on FirebaseException catch (e) {
      // Firestore permission errors surface here
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to send message')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // LOGOUT FUNCTION
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // AppBar with subtle gradient
      appBar: AppBar(
        title: const Text("Chat Room"),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              // Show dialog to enter peer id and name
              final peerIdController = TextEditingController();
              final peerNameController = TextEditingController();

              final res = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Start Direct Chat'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: peerIdController, decoration: const InputDecoration(labelText: 'Peer UID')),
                      TextField(controller: peerNameController, decoration: const InputDecoration(labelText: 'Peer display name')),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        if (peerIdController.text.trim().isEmpty) return;
                        Navigator.of(ctx).pop(true);
                      },
                      child: const Text('Start'),
                    ),
                  ],
                ),
              );

              if (res == true) {
                final peerId = peerIdController.text.trim();
                final peerName = peerNameController.text.trim().isEmpty ? peerId : peerNameController.text.trim();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoom(peerId: peerId, peerName: peerName)));
              }
            },
            tooltip: 'Start DM',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            tooltip: 'Logout',
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF536976), Color(0xFF292E49)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      // Gradient background and safe area
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F6FF), Color(0xFFE8F0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // RECENT CHATS LIST
              Expanded(
                child: user == null
                    ? const Center(child: Text('Sign in to view your chats'))
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: () {
                          print('=== ChatPage Building Chats Query ===');
                          print('Current User UID: ${user!.uid}');
                          print('Current User Email: ${user!.email}');
                          print('Query: chats where participants array-contains ${user!.uid}');
                          print('========================================');
                          return FirebaseFirestore.instance
                              .collection('chats')
                              .where('participants', arrayContains: user!.uid)
                              .orderBy('lastUpdated', descending: true)
                              .snapshots();
                        }(),
                        builder: (context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                          if (snapshot.hasError) {
                            print('=== ChatPage Query Error ===');
                            print('Error: ${snapshot.error}');
                            print('============================');
                            return const Center(child: Text('Something went wrong'));
                          }

                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final docs = snapshot.data!.docs;
                          print('[ChatPage] Received ${docs.length} chats for user ${user!.uid}');

                          if (docs.isEmpty) {
                            return const Center(child: Text('No chats yet. Start a DM using the + icon.'));
                          }

                          final items = docs.map((doc) {
                            final data = doc.data();
                            final participants = List<String>.from(data['participants'] ?? []);
                            final other = participants.firstWhere((p) => p != (user?.uid ?? ''), orElse: () => 'Unknown');
                            final lastMessage = data['lastMessage']?.toString() ?? '';
                            final Timestamp? ts = data['lastUpdated'] as Timestamp?;
                            String time = '';
                            if (ts != null) {
                              final dt = ts.toDate();
                              time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            }

                            return ListTile(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoom(peerId: other, peerName: other)));
                              },
                              leading: CircleAvatar(child: Text(other.isNotEmpty ? other[0].toUpperCase() : '?')),
                              title: Text(other),
                              subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Text(time, style: theme.textTheme.bodySmall),
                            );
                          }).toList();

                          return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: items);
                        },
                      ),
              ),

              // MESSAGE INPUT BOX
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    )
                  ],
                ),
                
              )
            ],
          ),
        ),
      ),
    );
  }
}
// ...existing code...