import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  // Create a deterministic chat id for two users by sorting their uids
  static String chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    final chatId = ids.join('_');
    print('[ChatService.chatIdFor] User A: $a, User B: $b => Chat ID: $chatId');
    return chatId;
  }

  // Fetch user's display name by UID
  static Future<String> getUserDisplayName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        return doc.data()?['displayName'] ?? uid;
      }
      return uid;
    } catch (e) {
      print('[ChatService.getUserDisplayName] Error fetching display name for $uid: $e');
      // Return UID if there's any error (permission denied, etc.)
      return uid;
    }
  }

  // Stream messages for a given chat
  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId) {
    print('[ChatService.messagesStream] Listening to messages for chat: $chatId');
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          print('[ChatService.messagesStream] Received ${snapshot.docs.length} messages for chat: $chatId');
          return snapshot;
        });
  }

  // Send a message and update chat metadata
  static Future<void> sendMessage({
    required String chatId,
    required List<String> participants,
    required String senderId,
    required String senderEmail,
    required String text,
  }) async {
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // Debug: log auth/send info so we can verify UID and chat path
    try {
      print('=== ChatService.sendMessage ===');
      print('Sender ID: $senderId');
      print('Sender Email: $senderEmail');
      print('Chat ID: $chatId');
      print('Participants: $participants');
      print('Message Text: $text');
      print('================================');

      // Ensure chat document exists (so security rules can check participants)
      final ts = FieldValue.serverTimestamp();
      await chatRef.set({
        'participants': participants,
        'lastMessage': text,
        'lastUpdated': ts,
      }, SetOptions(merge: true));

      final docRef = messagesRef.doc();
      await docRef.set({
        'id': docRef.id,
        'text': text,
        'senderId': senderId,
        'email': senderEmail,
        'timestamp': ts,
      });
    } catch (e, st) {
      // Log the error for debugging permission issues
      print('=== ChatService.sendMessage ERROR ===');
      print('Error: $e');
      print('Stack Trace: $st');
      print('=====================================');
      rethrow;
    }
  }

  // Initialize or update chat with peer information
  static Future<void> initializeChat({
    required String chatId,
    required List<String> participants,
    required String peerId,
    required String peerName,
  }) async {
    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      await chatRef.set({
        'participants': participants,
        'peerName': peerName,
        'peerId': peerId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('[ChatService.initializeChat] Chat initialized: $chatId with peer: $peerName');
    } catch (e) {
      print('[ChatService.initializeChat] Error: $e');
      rethrow;
    }
  }
}
