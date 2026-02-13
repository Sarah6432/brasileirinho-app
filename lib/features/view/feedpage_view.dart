import 'package:brasileirinho/features/service/api_service.dart';
import 'package:brasileirinho/features/view/createpostpage_view.dart';
import 'package:flutter/material.dart'; 

class PostData {
  final String userName;
  final String userHandle;
  final String time;
  final String content;
  final String? imageUrl;
  int likes;

  PostData({
    required this.userName,
    required this.userHandle,
    required this.time,
    required this.content,
    this.imageUrl,
    required this.likes,
  });
}

class FeedPage extends StatefulWidget {
  final String token;
  const FeedPage({super.key, required this.token});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  List<PostData> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getPosts(widget.token);
      setState(() {
        _posts = data.map((item) {
          return PostData(
            userName: item['user']['name'] ?? 'Usuário',
            userHandle: "@${item['user']['login'] ?? 'anonimo'}",
            time: "agora", 
            content: item['message'] ?? '',
            likes: 0,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar posts: $e")),
        );
      }
    }
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.blueGrey,
                        child: Text('S', style: TextStyle(color: Colors.white, fontSize: 20)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.black54),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Sarah Silva Lima",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Text(
                    "@SarahSLima",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 15),
                  const Row(
                    children: [
                      Text("0 ", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Seguindo  ", style: TextStyle(color: Colors.grey)),
                      Text("0 ", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Seguidores", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.person_outline, "Perfil"),
                _buildDrawerItem(Icons.people_outline, "Comunidades"),
                _buildDrawerItem(Icons.bookmark_border, "Itens salvos"),
                 const Divider(),
                   ExpansionTile(
                    title: const Text("Configurações & suporte", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    children: [
                     ListTile(
                     leading: const Icon(Icons.logout, color: Colors.red),
                     title: const Text("Sair", style: TextStyle(color: Colors.red)),
                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ],
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black, size: 26),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      onTap: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildProfileDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: const Padding(
            padding: EdgeInsets.all(10.0),
            child: CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Text('S', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ),
        title: Image.asset('assets/logo.png', height: 40, fit: BoxFit.contain),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF5FB60E),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [Tab(text: "Para você"), Tab(text: "Seguindo")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _loadPosts,
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildTimeline(),
          ),
          const Center(child: Text("Sua timeline de seguidores")), 
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final refresh = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreatePostPage(token: widget.token)),
          );
          if (refresh == true) _loadPosts(); 
        },
        backgroundColor: const Color(0xFF5FB60E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTimeline() {
    if (_posts.isEmpty) {
      return ListView(children: const [SizedBox(height: 100), Center(child: Text("Nenhum post encontrado."))]);
    }
    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return Column(
          children: [
            PostWidget(
              userName: post.userName,
              userHandle: post.userHandle,
              time: post.time,
              content: post.content,
              imageUrl: post.imageUrl,
              likes: post.likes,
              key: ValueKey(index.toString() + post.content),
            ),
            const Divider(height: 1, thickness: 0.2),
          ],
        );
      },
    );
  }
}

class PostWidget extends StatefulWidget {
  final String userName;
  final String userHandle;
  final String time;
  final String content;
  final String? imageUrl;
  final int likes;

  const PostWidget({
    super.key,
    required this.userName,
    required this.userHandle,
    required this.time,
    required this.content,
    required this.likes,
    this.imageUrl,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLiked = false;
  late int currentLikes;

  @override
  void initState() {
    super.initState();
    currentLikes = widget.likes;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 20, backgroundColor: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        "${widget.userHandle} • ${widget.time}",
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.more_horiz, color: Colors.grey, size: 18),
                  ],
                ),
                Text(widget.content, style: const TextStyle(fontSize: 15)),
                if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      widget.imageUrl!,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _actionIcon(Icons.chat_bubble_outline, "0"),
                    _actionIcon(Icons.repeat, "0"),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isLiked = !isLiked;
                          isLiked ? currentLikes++ : currentLikes--;
                        });
                      },
                      child: _actionIcon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        currentLikes.toString(),
                        color: isLiked ? Colors.red : Colors.grey,
                      ),
                    ),
                    _actionIcon(Icons.bar_chart, "0"),
                    _actionIcon(Icons.share_outlined, ""),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String text, {Color color = Colors.grey}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}