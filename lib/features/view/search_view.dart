import 'package:flutter/material.dart';
import 'package:brasileirinho/features/service/api_service.dart';
import 'package:brasileirinho/features/view/profile_view.dart';
import 'package:brasileirinho/features/view/post_details_view.dart';
// import 'package:brasileirinho/features/view/feed_view.dart'; // Import necessário para PostData

// Definição mínima de PostData para evitar erro de importação
class PostData {
  final int id;
  final String userName;
  final String userHandle;
  final String content;
  final String time;
  final int likes;
  final bool isLiked;

  PostData({
    required this.id,
    required this.userName,
    required this.userHandle,
    required this.content,
    required this.time,
    required this.likes,
    required this.isLiked,
  });
}

class SearchView extends StatefulWidget {
  final String token;
  final String currentUserLogin;

  const SearchView({super.key, required this.token, required this.currentUserLogin});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  List<dynamic> _userResults = [];
  List<dynamic> _postResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Realiza as buscas na API conforme a documentação
      final results = await Future.wait([
        ApiService.searchUsers(widget.token, query),
        ApiService.searchPosts(widget.token, query),
      ]);

      setState(() {
        _userResults = results[0];
        _postResults = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro na busca: $e")),
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
        iconTheme: const IconThemeData(color: Colors.black),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Buscar no Papacapim...",
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0072BC),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0072BC),
          tabs: const [
            Tab(text: "Usuários"),
            Tab(text: "Posts"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildUserResults(),
              _buildPostResults(),
            ],
          ),
    );
  }

  Widget _buildUserResults() {
    if (_userResults.isEmpty) return const Center(child: Text("Nenhum usuário encontrado."));

    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        final String login = user['login'] ?? '';
        
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF0072BC),
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text(user['name'] ?? 'Usuário'),
          subtitle: Text("@$login"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileView(
                  token: widget.token,
                  userLogin: login,
                  isCurrentUser: login == widget.currentUserLogin,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostResults() {
    if (_postResults.isEmpty) return const Center(child: Text("Nenhuma publicação encontrada."));

    return ListView.builder(
      itemCount: _postResults.length,
      itemBuilder: (context, index) {
        final item = _postResults[index];
        
        // Mapeia o JSON para o objeto PostData usado na FeedPage
        final post = PostData(
          id: item['id'] ?? 0,
          userName: item['user_login'] ?? 'Usuário',
          userHandle: item['user_login'] ?? 'anonimo',
          content: item['message'] ?? '',
          time: "postado",
          likes: item['likes_count'] ?? 0,
          isLiked: item['liked_by_me'] ?? false,
        );

        return ListTile(
          leading: const Icon(Icons.article_outlined, color: Colors.grey),
          title: Text("@${post.userHandle}"),
          subtitle: Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailsView(token: widget.token, post: post),
              ),
            );
          },
        );
      },
    );
  }
}