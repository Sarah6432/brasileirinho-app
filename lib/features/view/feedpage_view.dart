import 'package:brasileirinho/features/service/auth_manager.dart';
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
  const FeedPage({super.key});

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

  // Paginação - aba "Para você"
  int _currentPage = 0;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Paginação - aba "Seguindo"
  int _followingPage = 0;
  bool _hasMoreFollowing = true;
  bool _isLoadingMoreFollowing = false;
  final ScrollController _followingScrollController = ScrollController();

  String get _currentUserLogin => AuthManager.instance.currentSession!.login;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _userLogin = _currentUserLogin;
    _scrollController.addListener(_onScroll);
    _followingScrollController.addListener(_onFollowingScroll);
    _loadUserData();
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _followingScrollController.removeListener(_onFollowingScroll);
    _followingScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMorePosts) {
      _loadMorePosts();
    }
  }

  void _onFollowingScroll() {
    if (_followingScrollController.position.pixels >=
            _followingScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMoreFollowing &&
        _hasMoreFollowing) {
      _loadMoreFollowingPosts();
    }
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_followingLoaded) {
      _loadFollowingPosts();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await ApiService.getUser(_currentUserLogin);
      if (mounted) {
        setState(() {
          _userName = userData['name'] ?? '';
          _userLogin = userData['login'] ?? _currentUserLogin;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userName = _currentUserLogin);
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
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMorePosts = true;
      _posts = [];
    });
    try {
      int page = 0;
      final List<PostData> allPosts = [];
      const int minPosts = 10;

      // Carrega páginas até ter pelo menos minPosts posts visíveis
      while (allPosts.length < minPosts) {
        final data = await ApiService.getPosts(page: page);
        if (data.isEmpty) {
          // API não tem mais posts
          _hasMorePosts = false;
          break;
        }

        final posts = data
            .where((item) => item['post_id'] == null)
            .map<PostData>((item) => _mapItemToPostData(item))
            .toList();

        // Filtra duplicados
        final existingIds = allPosts.map((p) => p.id).toSet();
        final uniquePosts = posts
            .where((p) => !existingIds.contains(p.id))
            .toList();

        allPosts.addAll(uniquePosts);
        page++;

        if (!mounted) return;
      }

      await _fetchLikesForPosts(allPosts);

      if (mounted) {
        setState(() {
          _posts = allPosts;
          _isLoading = false;
          _currentPage = page;
        });
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

  Future<void> _loadMorePosts() async {
    if (!mounted || _isLoadingMore || !_hasMorePosts) return;
    setState(() => _isLoadingMore = true);
    try {
      final List<PostData> newUniquePosts = [];
      int page = _currentPage;

      // Tenta carregar até ter novos posts (pode ser que uma página só tenha replies)
      while (newUniquePosts.isEmpty) {
        final data = await ApiService.getPosts(page: page);
        if (data.isEmpty) {
          _hasMorePosts = false;
          break;
        }

        final newPosts = data
            .where((item) => item['post_id'] == null)
            .map<PostData>((item) => _mapItemToPostData(item))
            .toList();

        final existingIds = _posts.map((p) => p.id).toSet();
        newUniquePosts.addAll(
          newPosts.where((p) => !existingIds.contains(p.id)),
        );
        page++;

        if (!mounted) return;
      }

      await _fetchLikesForPosts(newUniquePosts);

      if (mounted) {
        setState(() {
          _posts.addAll(newUniquePosts);
          _currentPage = page;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _fetchLikesForPosts(List<PostData> posts) async {
    try {
      final likesFutures = posts
          .map((post) => ApiService.getPostLikes(post.id))
          .toList();
      final repliesFutures = posts
          .map((post) => ApiService.getReplies(post.id))
          .toList();
      final likesResults = await Future.wait(likesFutures);
      final repliesResults = await Future.wait(repliesFutures);

      for (int i = 0; i < posts.length; i++) {
        final likes = likesResults[i];
        posts[i].likes = likes.length;
        posts[i].isLiked = likes.any(
          (like) => like['user_login'] == _currentUserLogin,
        );
        posts[i].replies = repliesResults[i].length;
      }
    } catch (_) {}
  }

  Future<void> _loadFollowingPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFollowing = true;
      _followingPage = 0;
      _hasMoreFollowing = true;
      _followingPosts = [];
    });
    try {
      int page = 0;
      final List<PostData> allPosts = [];
      const int minPosts = 10;

      while (allPosts.length < minPosts) {
        final data = await ApiService.getPosts(feedOnly: true, page: page);
        if (data.isEmpty) {
          _hasMoreFollowing = false;
          break;
        }

        final posts = data
            .where((item) => item['post_id'] == null)
            .map<PostData>((item) => _mapItemToPostData(item))
            .toList();

        final existingIds = allPosts.map((p) => p.id).toSet();
        final uniquePosts = posts
            .where((p) => !existingIds.contains(p.id))
            .toList();

        allPosts.addAll(uniquePosts);
        page++;

        if (!mounted) return;
      }

      await _fetchLikesForPosts(allPosts);

      if (mounted) {
        setState(() {
          _followingPosts = allPosts;
          _isLoadingFollowing = false;
          _followingLoaded = true;
          _followingPage = page;
        });
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

  Future<void> _loadMoreFollowingPosts() async {
    if (!mounted || _isLoadingMoreFollowing || !_hasMoreFollowing) return;
    setState(() => _isLoadingMoreFollowing = true);
    try {
      final List<PostData> newUniquePosts = [];
      int page = _followingPage;

      while (newUniquePosts.isEmpty) {
        final data = await ApiService.getPosts(feedOnly: true, page: page);
        if (data.isEmpty) {
          _hasMoreFollowing = false;
          break;
        }

        final newPosts = data
            .where((item) => item['post_id'] == null)
            .map<PostData>((item) => _mapItemToPostData(item))
            .toList();

        final existingIds = _followingPosts.map((p) => p.id).toSet();
        newUniquePosts.addAll(
          newPosts.where((p) => !existingIds.contains(p.id)),
        );
        page++;

        if (!mounted) return;
      }

      await _fetchLikesForPosts(newUniquePosts);

      if (mounted) {
        setState(() {
          _followingPosts.addAll(newUniquePosts);
          _followingPage = page;
          _isLoadingMoreFollowing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMoreFollowing = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.deleteSession();
    } catch (_) {}
    await AuthManager.instance.logout();
    if (!mounted) return;
    if (AuthManager.instance.currentSession == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
        (route) => false,
      );
    } else {
      Navigator.pop(context); // fecha o Drawer
      // ListenableBuilder cuida de recarregar a tela
      _userLogin = _currentUserLogin;
      _followingLoaded = false;
      _loadUserData();
      _loadPosts();
    }
  }

  String _getInitial() {
    if (_userName.isNotEmpty) return _userName[0].toUpperCase();
    return _userLogin.isNotEmpty ? _userLogin[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthManager.instance,
      builder: (context, _) {
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
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
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
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: "Pesquisar",
              ),
            ],
            onTap: (index) {
              if (index == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchView()),
                );
              }
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final refresh = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostPage()),
              );
              if (refresh == true) _loadPosts();
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final post = _posts[index];
        return Column(
          children: [
            PostWidget(
              key: ValueKey("post_${post.id}_${post.isLiked}"),
              postData: post,
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
      controller: _followingScrollController,
      itemCount: _followingPosts.length + (_isLoadingMoreFollowing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _followingPosts.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final post = _followingPosts[index];
        return Column(
          children: [
            PostWidget(
              key: ValueKey("following_${post.id}_${post.isLiked}"),
              postData: post,
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
    final accounts = AuthManager.instance.savedAccounts;
    final activeLogin = AuthManager.instance.currentSession?.login;

    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8DC63F), Color(0xFF0072BC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Contas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Lista de contas salvas
          ...accounts.map((session) {
            final isActive = session.login == activeLogin;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isActive
                    ? const Color(0xFF0072BC)
                    : Colors.grey.shade400,
                child: Text(
                  session.login[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                '@${session.login}',
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isActive
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: isActive
                  ? null
                  : () async {
                      await AuthManager.instance.switchAccount(session.login);
                      if (!mounted) return;
                      Navigator.pop(context); // fecha o drawer
                      _userLogin = _currentUserLogin;
                      _followingLoaded = false;
                      _loadUserData();
                      _loadPosts();
                    },
            );
          }),
          const Divider(),
          // Perfil
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Perfil"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileView(userLogin: _userLogin),
                ),
              );
            },
          ),
          // Adicionar conta existente
          ListTile(
            leading: const Icon(
              Icons.person_add_outlined,
              color: Color(0xFF0072BC),
            ),
            title: const Text(
              "Adicionar conta existente",
              style: TextStyle(color: Color(0xFF0072BC)),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginView()),
              );
            },
          ),
          const Divider(),
          // Logout
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
  final Function(bool, int)? onLikeChanged;

  const PostWidget({super.key, required this.postData, this.onLikeChanged});

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
        builder: (context) =>
            ProfileView(userLogin: widget.postData.userHandle),
      ),
    );
  }

  void _goToDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsView(post: widget.postData),
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
        await ApiService.likePost(widget.postData.id);
      } else {
        await ApiService.unlikePost(widget.postData.id);
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
