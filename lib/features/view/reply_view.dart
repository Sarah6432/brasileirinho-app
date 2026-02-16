import 'package:flutter/material.dart';
import 'package:brasileirinho/features/service/api_service.dart';

class ReplyView extends StatefulWidget {
  final String token;
  final int postId;
  final String userHandle;

  const ReplyView({
    super.key, 
    required this.token, 
    required this.postId, 
    required this.userHandle
  });

  @override
  State<ReplyView> createState() => _ReplyViewState();
}

class _ReplyViewState extends State<ReplyView> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  Future<void> _handleSend() async {
    if (_controller.text.trim().isEmpty) return;
    
    setState(() => _isSending = true);

    try {
      await ApiService.createReply(
        widget.token, 
        widget.postId, 
        _controller.text.trim()
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao responder: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _isSending ? null : _handleSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5FB60E),
                shape: const StadiumBorder(),
              ),
              child: _isSending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Responder", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text("Respondendo a ", style: TextStyle(color: Colors.grey.shade600)),
                Text(widget.userHandle, style: const TextStyle(color: Color(0xFF5FB60E))),
              ],
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                autofocus: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: "Postar sua resposta",
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}