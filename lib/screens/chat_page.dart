import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_room.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    print('ChatPage.initState currentUser.uid = ${FirebaseAuth.instance.currentUser?.uid}');
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _startNewChat() async {
    final peerIdController = TextEditingController();
    final peerNameController = TextEditingController();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Start Direct Chat',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: peerIdController,
                  decoration: InputDecoration(
                    labelText: 'Peer UID',
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: peerNameController,
                  decoration: InputDecoration(
                    labelText: 'Peer Display Name',
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF536976), Color(0xFF292E49)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (peerIdController.text.trim().isEmpty) return;
                          Navigator.of(ctx).pop(true);
                        },
                        child: const Text('Start', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (res == true) {
      final peerId = peerIdController.text.trim();
      final peerName = peerNameController.text.trim().isEmpty ? peerId : peerNameController.text.trim();
      
      // Initialize the chat in Firestore with peer information
      final chatId = ChatService.chatIdFor(user!.uid, peerId);
      try {
        await ChatService.initializeChat(
          chatId: chatId,
          participants: [user!.uid, peerId],
          peerId: peerId,
          peerName: peerName,
        );
      } catch (e) {
        print('Error initializing chat: $e');
      }
      
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoom(peerId: peerId, peerName: peerName)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF536976), Color(0xFF292E49)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          PopupMenuButton(
            itemBuilder: (ctx) => [
              PopupMenuItem(
                child: const Text('Settings'),
                onTap: () {},
              ),
              PopupMenuItem(
                child: const Text('Logout'),
                onTap: logout,
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F6FF), Color(0xFFE8F0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
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
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text('Something went wrong', style: TextStyle(fontSize: 18)),
                            const SizedBox(height: 8),
                            Text('${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF536976)));
                  }

                  final docs = snapshot.data!.docs;
                  print('[ChatPage] Received ${docs.length} chats for user ${user!.uid}');

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No chats yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text('Tap + to start a new chat', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final participants = List<String>.from(data['participants'] ?? []);
                      final peerId = participants.firstWhere((p) => p != (user?.uid ?? ''), orElse: () => 'Unknown');
                      final lastMessage = data['lastMessage']?.toString() ?? '';
                      final Timestamp? ts = data['lastUpdated'] as Timestamp?;
                      String time = '';
                      if (ts != null) {
                        final dt = ts.toDate();
                        final now = DateTime.now();
                        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                          time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        } else {
                          time = '${dt.day}/${dt.month}';
                        }
                      }

                      // Try to get peer name from chat metadata first, then from user profile
                      final storedPeerName = data['peerName']?.toString();
                      final displayName = storedPeerName ?? peerId;

                      return FutureBuilder<String>(
                        future: storedPeerName != null ? Future.value(storedPeerName) : ChatService.getUserDisplayName(peerId),
                        builder: (context, snapshot) {
                          final finalDisplayName = snapshot.data ?? displayName;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF536976),
                                child: Text(
                                  finalDisplayName.isNotEmpty ? finalDisplayName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                              title: Text(finalDisplayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoom(peerId: peerId, peerName: finalDisplayName)));
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        backgroundColor: const Color(0xFF536976),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }
}