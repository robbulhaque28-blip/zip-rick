import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class DriverChatSheet extends StatefulWidget {
  final io.Socket? socket;
  final String rideId;
  final List<Map<String, dynamic>> messages;
  final StreamController<Map<String, dynamic>> streamCtrl;

  const DriverChatSheet({
    super.key,
    required this.socket,
    required this.rideId,
    required this.messages,
    required this.streamCtrl,
  });

  @override
  State<DriverChatSheet> createState() => _DriverChatSheetState();
}

class _DriverChatSheetState extends State<DriverChatSheet> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.messages);
    widget.streamCtrl.stream.listen((_) {
      if (mounted) {
        setState(() => _messages = List.from(widget.messages));
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    widget.socket?.emit('chat:send', {
      'ride_id': widget.rideId,
      'message': _msgCtrl.text.trim(),
    });
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chat_rounded, size: 20, color: Color(0xFF6C63FF))),
              const SizedBox(width: 12),
              const Text('Chat with Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), visualDensity: VisualDensity.compact),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No messages yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    Text('Chat with your customer', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ]))
                : ListView.builder(
                    controller: _scrollCtrl, padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg['sender_role'] == 'driver';
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF6C63FF) : Colors.grey.shade100,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                            ),
                          ),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                          child: Text(msg['message']?.toString() ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _msgCtrl,
                decoration: InputDecoration(
                  hintText: 'Type a message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true, fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              )),
              const SizedBox(width: 8),
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(22)),
                child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: _sendMessage),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
