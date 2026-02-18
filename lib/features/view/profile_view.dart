import 'package:brasileirinho/features/service/api_service.dart';
import 'package:brasileirinho/features/view/edit_profile_view.dart';
import 'package:brasileirinho/features/view/post_details_view.dart';
import 'package:brasileirinho/features/view/feedpage_view.dart' show PostData;
import 'package:flutter/material.dart';

class ProfileView extends StatefulWidget {
  final String token;
  final String userLogin;
  final String currentUserLogin;
  final bool isCurrentUser;

  const ProfileView({
    super.key,
    required this.token,
    required this.userLogin,
    required this.currentUserLogin,
    this.isCurrentUser = false,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  Map<String, dynamic>? _userData;
  List<dynamic> _posts = [];
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  // ignore: unused_field
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getUser(widget.token, widget.userLogin),
        ApiService.getUserPosts(widget.token, widget.userLogin),
        ApiService.getFollowers(widget.token, widget.userLogin),
      ]);

      // Busca "seguindo" separadamente para não quebrar o perfil se falhar
      List<dynamic> followingList = [];
      try {
        followingList = await ApiService.getFollowing(
          widget.token,
          widget.userLogin,
        );
      } catch (_) {
        // API pode não suportar /following — mostra 0 em vez de quebrar tudo
      }

      if (mounted) {
        final userData = results[0] as Map<String, dynamic>;
        final allPosts = results[1] as List<dynamic>;
        final userPosts = allPosts.where((p) => p['post_id'] == null).toList();
        final followersList = results[2] as List<dynamic>;

        // Busca likes e replies de cada post
        try {
          final likesFutures = userPosts
              .map((p) => ApiService.getPostLikes(widget.token, p['id']))
              .toList();
          final repliesFutures = userPosts
              .map((p) => ApiService.getReplies(widget.token, p['id']))
              .toList();
          final likesResults = await Future.wait(likesFutures);
          final repliesResults = await Future.wait(repliesFutures);
          for (int i = 0; i < userPosts.length; i++) {
            final likes = likesResults[i];
            userPosts[i]['likes_count'] = likes.length;
            userPosts[i]['liked_by_me'] = likes.any(
              (like) => like['user_login'] == widget.userLogin,
            );
            userPosts[i]['replies_count'] = repliesResults[i].length;
          }
        } catch (_) {}

        final following = followersList.any(
          (f) => f['follower_login'] == widget.currentUserLogin,
        );

        setState(() {
          _userData = userData;
          _posts = userPosts;
          _followers = followersList;
          _following = followingList;
          _isFollowing = following;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final oldStatus = _isFollowing;
    setState(() => _isFollowing = !_isFollowing);

    try {
      if (oldStatus) {
        await ApiService.unfollowUser(widget.token, widget.userLogin);
      } else {
        await ApiService.followUser(widget.token, widget.userLogin);
      }
      _loadAll();
    } catch (e) {
      setState(() => _isFollowing = oldStatus);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro ao processar: $e")));
      }
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      await ApiService.deletePost(widget.token, postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post excluído com sucesso")),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro ao excluir: $e")));
      }
    }
  }

  void _showDeleteDialog(int postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir post"),
        content: const Text("Deseja apagar esta postagem permanentemente?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(postId);
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getInitial() {
    final name = _userData?['name'] ?? widget.userLogin;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        '',
        'jan',
        'fev',
        'mar',
        'abr',
        'mai',
        'jun',
        'jul',
        'ago',
        'set',
        'out',
        'nov',
        'dez',
      ];
      return 'Entrou em ${months[date.month]} de ${date.year}';
    } catch (_) {
      return '';
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _userData?['name'] ?? widget.userLogin,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_posts.length} posts',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: _buildProfileContent(),
            ),
    );
  }

  Widget _buildProfileContent() {
    final name = _userData?['name'] ?? '';
    final login = _userData?['login'] ?? widget.userLogin;
    final createdAt = _userData?['created_at'];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8DC63F), Color(0xFF0072BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -35),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFF0072BC),
                          child: Text(
                            _getInitial(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Transform.translate(
                      offset: const Offset(0, -10),
                      child: widget.isCurrentUser
                          ? OutlinedButton(
                              onPressed: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditProfileView(
                                      token: widget.token,
                                      currentName: name,
                                      currentLogin: login,
                                    ),
                                  ),
                                );
                                if (updated == true) _loadAll();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Editar perfil',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing
                                    ? Colors.white
                                    : Colors.black,
                                foregroundColor: _isFollowing
                                    ? Colors.black
                                    : Colors.white,
                                side: _isFollowing
                                    ? const BorderSide(color: Colors.grey)
                                    : BorderSide.none,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                _isFollowing ? 'Seguindo' : 'Seguir',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@$login',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatDate(createdAt),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '${_following.length} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Seguindo  ',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            '${_followers.length} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Seguidores',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
        if (_posts.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                'Nenhum post ainda.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final post = _posts[index];
              return ProfilePostItem(
                key: ValueKey("profile_post_${post['id']}"),
                post: post,
                token: widget.token,
                isCurrentUser: widget.isCurrentUser,
                onDelete: () => _showDeleteDialog(post['id']),
              );
            }, childCount: _posts.length),
          ),
      ],
    );
  }
}

class ProfilePostItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final String token;
  final bool isCurrentUser;
  final VoidCallback onDelete;

  const ProfilePostItem({
    super.key,
    required this.post,
    required this.token,
    required this.isCurrentUser,
    required this.onDelete,
  });

  @override
  State<ProfilePostItem> createState() => _ProfilePostItemState();
}

class _ProfilePostItemState extends State<ProfilePostItem> {
  late bool isLiked;
  late int likesCount;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post['liked_by_me'] ?? false;
    likesCount = widget.post['likes_count'] ?? 0;
  }

  Future<void> _handleLike() async {
    final oldLiked = isLiked;
    final oldCounts = likesCount;

    setState(() {
      isLiked = !isLiked;
      isLiked ? likesCount++ : likesCount--;
    });

    try {
      if (isLiked) {
        await ApiService.likePost(widget.token, widget.post['id']);
      } else {
        await ApiService.unlikePost(widget.token, widget.post['id']);
      }
    } catch (e) {
      if (mounted && !e.toString().contains("422")) {
        setState(() {
          isLiked = oldLiked;
          likesCount = oldCounts;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userHandle =
        widget.post['user_login'] ?? widget.post['user']?['login'] ?? 'anonimo';
    final String userName = widget.post['user']?['name'] ?? userHandle;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final postData = PostData(
          id: widget.post['id'] ?? 0,
          userName: userName,
          userHandle: userHandle,
          content: widget.post['message'] ?? '',
          time: '',
          likes: likesCount,
          isLiked: isLiked,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PostDetailsView(token: widget.token, post: postData),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF0072BC),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "$userName @$userHandle",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (widget.isCurrentUser)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.grey,
                            size: 18,
                          ),
                          onSelected: (value) {
                            if (value == 'delete') widget.onDelete();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Excluir",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Text(widget.post['message'] ?? ''),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (widget.post['replies_count'] ?? 0).toString(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.repeat, size: 18, color: Colors.grey),
                      GestureDetector(
                        onTap: _handleLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: isLiked ? Colors.red : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              likesCount.toString(),
                              style: TextStyle(
                                color: isLiked ? Colors.red : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.share_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
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
}
