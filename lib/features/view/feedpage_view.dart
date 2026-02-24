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
  final String time;
  final String content;
  int likes;
  bool isLiked;
  int replies;

  PostData({
    required this.id,
    required this.userName,
    required this.userHandle,
    required this.time,
    required this.content,
    required this.likes,
    this.isLiked = false,
    this.replies = 0,
  });
}

class FeedPage extends StatefulWidget {
  final String token;
  final String userLogin;
  const FeedPage({super.key, required this.token, required this.userLogin});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  List<PostData> _posts = [];
  List<PostData> _followingPosts = [];
  bool _isLoading = true;
  bool _isLoadingFollowing = false;
  bool _followingLoaded = false;
  String _userName = '';
  String _userLogin = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _userLogin = widget.userLogin;
    _loadUserData();
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_followingLoaded) {
      _loadFollowingPosts();
    }
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

  PostData _mapItemToPostData(Map<String, dynamic> item) {
    final String userLogin = item['user_login'] ?? 'anonimo';
    final user = item['user'];
    final String userName = user?['name'] ?? userLogin;
    return PostData(
      id: item['id'] ?? 0,
      userName: userName,
      userHandle: userLogin,
      time: "agora",
      content: item['message'] ?? '',
      likes: item['likes_count'] ?? 0,
      isLiked: item['liked_by_me'] ?? false,
    );
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getPosts(widget.token);
      if (mounted) {
        final posts = data
            .where((item) => item['post_id'] == null)
            .map<PostData>((item) => _mapItemToPostData(item))
            .toList();

        await _fetchLikesForPosts(posts);

        if (mounted) {
          setState(() {
            _posts = posts;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro ao carregar posts: $e")));
      }
    }
  }

  Future<void> _fetchLikesForPosts(List<PostData> posts) async {
    try {
      final likesFutures = posts
          .map((post) => ApiService.getPostLikes(widget.token, post.id))
          .toList();
      final repliesFutures = posts
          .map((post) => ApiService.getReplies(widget.token, post.id))
          .toList();
      final likesResults = await Future.wait(likesFutures);
      final repliesResults = await Future.wait(repliesFutures);

      for (int i = 0; i < posts.length; i++) {
        final likes = likesResults[i];
        posts[i].likes = likes.length;
        posts[i].isLiked = likes.any(
          (like) => like['user_login'] == widget.userLogin,
        );
        posts[i].replies = repliesResults[i].length;
      }
    } catch (_) {}
  }

  Future<void> _loadFollowingPosts() async {
    if (!mounted) return;
    setState(() => _isLoadingFollowing = true);
    try {
      final data = await ApiService.getPosts(widget.token, feedOnly: true);
      if (mounted) {
        final posts = data
            .where((item) => item['post_id'] == null)
            .map<PostData>((item) => _mapItemToPostData(item))
            .toList();

        await _fetchLikesForPosts(posts);

        if (mounted) {
          setState(() {
            _followingPosts = posts;
            _isLoadingFollowing = false;
            _followingLoaded = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFollowing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar timeline: $e")),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.deleteSession(widget.token);
    } catch (_) {}
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
              child: Text(
                _getInitial(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
        title: Image.asset('assets/logo.png', height: 40),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Para você"),
            Tab(text: "Seguindo"),
          ],
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
          RefreshIndicator(
            onRefresh: _loadFollowingPosts,
            child: _isLoadingFollowing
                ? const Center(child: CircularProgressIndicator())
                : _followingPosts.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: Text(
                          "Siga pessoas para ver posts aqui",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ],
                  )
                : _buildFollowingTimeline(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Início",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Pesquisar"),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchView(
                  token: widget.token,
                  currentUserLogin: widget.userLogin,
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final refresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePostPage(token: widget.token),
            ),
          );
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

  Widget _buildFollowingTimeline() {
    return ListView.builder(
      itemCount: _followingPosts.length,
      itemBuilder: (context, index) {
        final post = _followingPosts[index];
        return Column(
          children: [
            PostWidget(
              key: ValueKey("following_${post.id}_${post.isLiked}"),
              postData: post,
              token: widget.token,
              currentUserLogin: widget.userLogin,
              onLikeChanged: (liked, likesCount) {
                setState(() {
                  _followingPosts[index].isLiked = liked;
                  _followingPosts[index].likes = likesCount;
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileView(
                    token: widget.token,
                    userLogin: _userLogin,
                    currentUserLogin: widget.userLogin,
                    isCurrentUser: true,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Sair"),
            onTap: _logout,
          ),
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
    if (oldWidget.postData.isLiked != widget.postData.isLiked ||
        oldWidget.postData.likes != widget.postData.likes) {
      setState(() {
        localIsLiked = widget.postData.isLiked;
        localLikes = widget.postData.likes;
      });
    }
  }

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileView(
          token: widget.token,
          userLogin: widget.postData.userHandle,
          currentUserLogin: widget.currentUserLogin,
          isCurrentUser: widget.postData.userHandle == widget.currentUserLogin,
        ),
      ),
    );
  }

  void _goToDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailsView(token: widget.token, post: widget.postData),
      ),
    );
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
        setState(() {
          localIsLiked = oldIsLiked;
          localLikes = oldLikes;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _goToDetails,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _goToProfile,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                child: Text(widget.postData.userName[0].toUpperCase()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _goToProfile,
                        child: Text(
                          widget.postData.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "@${widget.postData.userHandle} • ${widget.postData.time}",
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(widget.postData.content),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _actionIcon(
                        Icons.chat_bubble_outline,
                        widget.postData.replies.toString(),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReplyView(
                                userHandle: widget.postData.userHandle,
                                token: widget.token,
                                postId: widget.postData.id,
                              ),
                            ),
                          );
                        },
                      ),
                      _actionIcon(Icons.repeat, "0"),
                      _actionIcon(
                        localIsLiked ? Icons.favorite : Icons.favorite_border,
                        localLikes.toString(),
                        color: localIsLiked ? Colors.red : Colors.grey,
                        onTap: _toggleLike,
                      ),
                      _actionIcon(Icons.share_outlined, ""),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(
    IconData icon,
    String text, {
    Color color = Colors.grey,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
