import 'package:brasileirinho/features/view/reply_view.dart';
import 'package:flutter/material.dart';
import 'package:brasileirinho/features/service/api_service.dart';
import 'package:brasileirinho/features/view/createpostpage_view.dart';
import 'package:brasileirinho/features/view/login_view.dart';
import 'package:brasileirinho/features/view/profile_view.dart';
import 'package:brasileirinho/features/view/post_details_view.dart';
import 'package:brasileirinho/features/view/search_view.dart';

class PostData {
  final int id;
  final String userName;
  final String userHandle;
  final String? userPhoto;
  final String time;
  final String content;
  final String? imageUrl;
  int likes;
  bool isLiked;

  PostData({
    required this.id,
    required this.userName,
    required this.userHandle,
    this.userPhoto,
    required this.time,
    required this.content,
    this.imageUrl,
    required this.likes,
    this.isLiked = false,
  });
}

class FeedPage extends StatefulWidget {
  final String token;
  final String userLogin;
  const FeedPage({super.key, required this.token, required this.userLogin});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  List<PostData> _posts = [];
  bool _isLoading = true;
  String _userName = '';
  String _userLogin = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userLogin = widget.userLogin;
    _loadUserData();
    _loadPosts();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await ApiService.getUser(widget.token, widget.userLogin);
      if (mounted) {
        setState(() {
          _userName = userData['name'] ?? '';
          _userLogin = userData['login'] ?? widget.userLogin;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userName = widget.userLogin);
    }
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getPosts(widget.token);
      if (mounted) {
        setState(() {
          _posts = data
              .where((item) => item['parent_id'] == null)
              .map<PostData>((item) {
            final user = item['user'];
            String? photoUrl = user?['photo'];
            if (photoUrl != null && !photoUrl.startsWith('http')) {
              photoUrl = '${ApiService.baseUrl}$photoUrl';
            }
            String? postImageUrl = item['image'];
            if (postImageUrl != null && !postImageUrl.startsWith('http')) {
              postImageUrl = '${ApiService.baseUrl}$postImageUrl';
            }
            return PostData(
              id: item['id'] ?? 0,
              userName: user?['name'] ?? 'Usuário',
              userHandle: "${user?['login'] ?? 'anonimo'}",
              userPhoto: photoUrl,
              time: "agora",
              content: item['message'] ?? '',
              imageUrl: postImageUrl,
              likes: item['likes_count'] ?? 0,
              isLiked: item['liked_by_me'] ?? false,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao carregar posts: $e")));
      }
    }
  }

  Future<void> _logout() async {
    try { await ApiService.deleteSession(widget.token); } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  String _getInitial() {
    if (_userName.isNotEmpty) return _userName[0].toUpperCase();
    return _userLogin.isNotEmpty ? _userLogin[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildProfileDrawer(),
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(_getInitial(), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ),
        title: Image.asset('assets/logo.png', height: 40),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Para você"), Tab(text: "Seguindo")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _loadPosts,
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildTimeline(),
          ),
          const Center(child: Text("Sua timeline de seguidores")),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Início"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Pesquisar"),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => SearchView(token: widget.token, currentUserLogin: widget.userLogin)));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final refresh = await Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostPage(token: widget.token)));
          if (refresh == true) _loadPosts();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return Column(
          children: [
            PostWidget(
              key: ValueKey("post_${post.id}_${post.isLiked}"), 
              postData: post, 
              token: widget.token,
              currentUserLogin: widget.userLogin,
              onLikeChanged: (liked, likesCount) {
                setState(() {
                  _posts[index].isLiked = liked;
                  _posts[index].likes = likesCount;
                });
              },
            ),
            const Divider(height: 1, thickness: 0.2),
          ],
        );
      },
    );
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Perfil"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileView(token: widget.token, userLogin: _userLogin, isCurrentUser: true)));
            },
          ),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Sair"), onTap: _logout),
        ],
      ),
    );
  }
}

class PostWidget extends StatefulWidget {
  final PostData postData;
  final String token;
  final String currentUserLogin;
  final Function(bool, int)? onLikeChanged;

  const PostWidget({
    super.key,
    required this.postData,
    required this.token,
    required this.currentUserLogin,
    this.onLikeChanged,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late bool localIsLiked;
  late int localLikes;

  @override
  void initState() {
    super.initState();
    localIsLiked = widget.postData.isLiked;
    localLikes = widget.postData.likes;
  }

  @override
  void didUpdateWidget(covariant PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postData.isLiked != widget.postData.isLiked || oldWidget.postData.likes != widget.postData.likes) {
      setState(() {
        localIsLiked = widget.postData.isLiked;
        localLikes = widget.postData.likes;
      });
    }
  }

  void _goToProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileView(token: widget.token, userLogin: widget.postData.userHandle, isCurrentUser: widget.postData.userHandle == widget.currentUserLogin)));
  }

  void _goToDetails() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsView(token: widget.token, post: widget.postData)));
  }

  Future<void> _toggleLike() async {
    final bool oldIsLiked = localIsLiked;
    final int oldLikes = localLikes;
    setState(() {
      localIsLiked = !localIsLiked;
      localIsLiked ? localLikes++ : localLikes--;
    });
    try {
      if (localIsLiked) {
        await ApiService.likePost(widget.token, widget.postData.id);
      } else {
        await ApiService.unlikePost(widget.token, widget.postData.id);
      }
      widget.onLikeChanged?.call(localIsLiked, localLikes);
    } catch (e) {
      if (mounted && !e.toString().contains("422")) {
        setState(() { localIsLiked = oldIsLiked; localLikes = oldLikes; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _goToProfile,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: widget.postData.userPhoto != null ? NetworkImage(widget.postData.userPhoto!) : null,
              child: widget.postData.userPhoto == null ? Text(widget.postData.userName[0].toUpperCase()) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(onTap: _goToProfile, child: Text(widget.postData.userName, style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(width: 4),
                    Expanded(child: Text("@${widget.postData.userHandle} • ${widget.postData.time}", style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                GestureDetector(
                  onTap: _goToDetails,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(widget.postData.content),
                      if (widget.postData.imageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(widget.postData.imageUrl!)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _actionIcon(Icons.chat_bubble_outline, "0", onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ReplyView(userHandle: widget.postData.userHandle, token: widget.token, postId: widget.postData.id)));
                    }),
                    _actionIcon(Icons.repeat, "0"),
                    _actionIcon(localIsLiked ? Icons.favorite : Icons.favorite_border, localLikes.toString(), color: localIsLiked ? Colors.red : Colors.grey, onTap: _toggleLike),
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

  Widget _actionIcon(IconData icon, String text, {Color color = Colors.grey, VoidCallback? onTap}) {
    return GestureDetector(onTap: onTap, child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(color: color, fontSize: 12))]));
  }
}