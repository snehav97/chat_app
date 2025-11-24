import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class ChatRoom extends StatefulWidget {
  final String peerId;
  final String peerName;

  const ChatRoom({super.key, required this.peerId, required this.peerName});

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final user = FirebaseAuth.instance.currentUser;

  String get _chatId => ChatService.chatIdFor(user!.uid, widget.peerId);

  @override
  void initState() {
    super.initState();
    print('=== ChatRoom.initState ===');
    print('Current User UID: ${user?.uid}');
    print('Current User Email: ${user?.email}');
    print('Peer ID: ${widget.peerId}');
    print('Peer Name: ${widget.peerName}');
    print('Generated Chat ID: $_chatId');
    print('Participants: [${user?.uid}, ${widget.peerId}]');
    print('========================');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (user == null) {
      print('ERROR: User is null, cannot send message');
      return;
    }

    print('=== ChatRoom._send ===');
    print('Sender UID: ${user!.uid}');
    print('Sender Email: ${user!.email}');
    print('Chat ID: $_chatId');
    print('Message Text: $text');
    print('Participants: [${user!.uid}, ${widget.peerId}]');
    print('=======================');

    try {
      await ChatService.sendMessage(
        chatId: _chatId,
        participants: [user!.uid, widget.peerId],
        senderId: user!.uid,
        senderEmail: user!.email ?? '',
        text: text,
      );

      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('ERROR in ChatRoom._send: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF536976), Color(0xFF292E49)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.peerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const Text('Online', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          PopupMenuButton(
            itemBuilder: (ctx) => [
              const PopupMenuItem(child: Text('View Contact')),
              const PopupMenuItem(child: Text('Media, Links, & Docs')),
              const PopupMenuItem(child: Text('Search')),
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
        child: Column(
          children: [
            // Messages
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ChatService.messagesStream(_chatId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF536976)));
                  }

                  final docs = snapshot.data!.docs;

                  final items = docs.map((doc) {
                    final data = doc.data();
                    final uid = (data['senderId'] ?? '') as String;
                    final text = data['text']?.toString() ?? '';
                    final email = data['email']?.toString() ?? '';
                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    String time = '';
                    if (ts != null) {
                      final dt = ts.toDate();
                      time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    }

                    final bool isMe = user != null && uid == user!.uid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF536976).withOpacity(0.2),
                              child: Text(
                                email.isNotEmpty ? email[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF536976)),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isMe ? const Color(0xFFE3F2FD) : Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      )
                                    ],
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 2),
                                      bottomRight: Radius.circular(isMe ? 2 : 16),
                                    ),
                                  ),
                                  child: Text(
                                    text,
                                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                          if (isMe) const SizedBox(width: 8),
                        ],
                      ),
                    );
                  }).toList();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      try {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      } catch (_) {}
                    }
                  });

                  return ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: items,
                  );
                },
              ),
            ),
            // Input area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF536976), size: 28),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Message',
                          fillColor: Colors.grey[100],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.emoji_emotions, color: Color(0xFF536976), size: 22),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.attach_file, color: Color(0xFF536976), size: 22),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: _send,
                      backgroundColor: const Color(0xFF536976),
                      mini: true,
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
