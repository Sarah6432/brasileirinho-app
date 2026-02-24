import 'package:flutter/material.dart';
import '../service/api_service.dart';

class CreatePostPage extends StatefulWidget {
  final String token;
  const CreatePostPage({super.key, required this.token});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _handlePublish() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ApiService.createPost(widget.token, _controller.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao publicar: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5FB60E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Publicar",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Text('S', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: "O que está acontecendo?",
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              color: Colors.white,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: Row(children: [_buildIcon(Icons.image_outlined)]),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 20, bottom: 35),
      child: Icon(icon, color: const Color(0xFF5FB60E), size: 35),
    );
  }
}
