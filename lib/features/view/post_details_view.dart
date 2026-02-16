import 'package:flutter/material.dart';
import 'package:brasileirinho/features/service/api_service.dart';
import 'package:brasileirinho/features/view/reply_view.dart';

class PostDetailsView extends StatefulWidget {
  final String token;
  final dynamic post; 

  const PostDetailsView({super.key, required this.token, required this.post});

  @override
  State<PostDetailsView> createState() => _PostDetailsViewState();
}

class _PostDetailsViewState extends State<PostDetailsView> {
  List<dynamic> _replies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getReplies(widget.token, widget.post.id);
      if (mounted) {
        setState(() {
          _replies = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Postagem", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadReplies,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(child: Text(widget.post.userName[0])),
                            const SizedBox(width: 12),
                            Text(widget.post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(widget.post.content, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(widget.post.time, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Divider(thickness: 0.5),
                  
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (_replies.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Nenhuma resposta ainda.", style: TextStyle(color: Colors.grey))))
                  else
                    // ignore: unnecessary_to_list_in_spreads
                    ..._replies.map((reply) => _buildReplyItem(reply)).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF5FB60E),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReplyView(
                token: widget.token, 
                postId: widget.post.id, 
                userHandle: widget.post.userHandle
              ),
            ),
          );
          if (result == true) _loadReplies();
        },
        child: const Icon(Icons.reply, color: Colors.white),
      ),
    );
  }

  Widget _buildReplyItem(Map<String, dynamic> reply) {
    return Column(
      children: [
        ListTile(
          leading: const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 20)),
          title: Text("@${reply['user_login']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(reply['message'], style: const TextStyle(color: Colors.black, fontSize: 15)),
        ),
        const Divider(indent: 70, height: 1, thickness: 0.2),
      ],
    );
  }
}