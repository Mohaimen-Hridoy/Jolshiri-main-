import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _filter = 'All';
  bool _loading = false;
  static const categories = ['All', 'Announcement', 'Buy & Sell', 'Lost & Found', 'Event'];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final posts = await BackendRepository.fetchCommunityPosts();
      if (mounted && posts.isNotEmpty) {
        setState(() { MockData.communityPosts..clear()..addAll(posts); });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _categoryColor(String c) => switch (c) {
        'Announcement' => AppColors.parade,
        'Buy & Sell' => AppColors.brass,
        'Lost & Found' => AppColors.brick,
        'Event' => AppColors.lake,
        _ => AppColors.ink,
      };

  @override
  Widget build(BuildContext context) {
    final posts = MockData.communityPosts.where((p) => _filter == 'All' || p.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.parade,
        onPressed: () => _showComposeSheet(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = categories[i];
                final selected = c == _filter;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = c),
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: posts.isEmpty
                ? const EmptyState(icon: Icons.groups_outlined, title: 'Nothing here yet', message: 'Posts in this category will show up here.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final p = posts[i];
                      return _PostCard(
                        post: p,
                        color: _categoryColor(p.category),
                        onChanged: () => setState(() {}),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComposeSheet(BuildContext context) {
    final contentController = TextEditingController();
    String category = 'Announcement';
    Uint8List? imageBytes;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New post', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: categories.skip(1).map((c) {
                    final selected = c == category;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) => setModalState(() => category = c),
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(controller: contentController, maxLines: 4, decoration: const InputDecoration(hintText: "What's happening in Jolshiri?")),
                const SizedBox(height: 16),
                ImagePickerField(
                  label: 'Add a photo (optional)',
                  onChanged: (bytes) => setModalState(() => imageBytes = bytes),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final content = contentController.text.trim();
                      if (content.isEmpty) {
                        showActionSnackBar(context, 'Write something before posting');
                        return;
                      }

                      // POST /api/community-posts — real backend call when
                      // signed in; falls back to a local mock insert (with
                      // the picked photo, which the mock backend doesn't
                      // need to round-trip) if the backend is unreachable.
                      if (AuthSession.isLoggedIn) {
                        try {
                          final saved = await runWithLoadingOverlay(
                            context,
                            () => BackendRepository.createCommunityPost(
                              content: content,
                              category: category,
                              imageBytes: imageBytes,
                            ),
                            message: 'Publishing your post…',
                          );
                          setState(() {
                            MockData.communityPosts.insert(
                              0,
                              CommunityPost(
                                id: saved.id,
                                author: MockData.currentUser.fullName,
                                authorId: saved.authorId ?? AuthSession.userId,
                                content: saved.content,
                                category: saved.category,
                                postedAt: saved.postedAt,
                                imageUrl: saved.imageUrl,
                                imageBytes: imageBytes,
                              ),
                            );
                          });
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          showActionSnackBar(this.context, 'Post published to $category');
                          return;
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showActionSnackBar(context, e.message);
                          return;
                        } on ApiUnreachableException {
                          // fall through to the offline demo flow below
                        }
                      }

                      setState(() {
                        MockData.communityPosts.insert(
                          0,
                          CommunityPost(
                            author: MockData.currentUser.fullName,
                            authorId: AuthSession.userId,
                            content: content,
                            category: category,
                            postedAt: DateTime.now(),
                            imageBytes: imageBytes,
                          ),
                        );
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      showActionSnackBar(this.context, 'Post published to $category');
                    },
                    child: const Text('Post'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single community post card: photo, content, and an inline comment
/// thread residents can read from and add to.
class _PostCard extends StatefulWidget {
  final CommunityPost post;
  final Color color;
  final VoidCallback onChanged;

  const _PostCard({required this.post, required this.color, required this.onChanged});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  final _commentController = TextEditingController();
  bool _showComments = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  Future<void> _editPost(BuildContext context) async {
    final p = widget.post;
    final contentController = TextEditingController(text: p.content);
    String category = p.category;
    Uint8List? imageBytes;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit post', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: _CommunityScreenState.categories.skip(1).map((c) {
                    final selected = c == category;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) => setModalState(() => category = c),
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(controller: contentController, maxLines: 4, decoration: const InputDecoration(hintText: "What's happening in Jolshiri?")),
                const SizedBox(height: 16),
                ImagePickerField(
                  label: 'Replace photo (optional)',
                  onChanged: (bytes) => setModalState(() => imageBytes = bytes),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final content = contentController.text.trim();
                      if (content.isEmpty) {
                        showActionSnackBar(sheetContext, 'Write something before saving');
                        return;
                      }
                      if (p.id == null) {
                        // Local-only mock entry — update fields in place.
                        p.content = content;
                        p.category = category;
                        if (imageBytes != null) p.imageBytes = imageBytes;
                        Navigator.pop(sheetContext, true);
                        return;
                      }
                      try {
                        final updated = await runWithLoadingOverlay(
                          sheetContext,
                          () => BackendRepository.updateCommunityPost(
                            id: p.id!,
                            content: content,
                            category: category,
                            imageBytes: imageBytes,
                          ),
                          message: 'Saving changes…',
                        );
                        p.content = updated.content;
                        p.category = updated.category;
                        p.imageUrl = updated.imageUrl;
                        if (imageBytes != null) p.imageBytes = imageBytes;
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext, true);
                      } on ApiException catch (e) {
                        if (sheetContext.mounted) showActionSnackBar(sheetContext, e.message);
                      } on ApiUnreachableException {
                        if (sheetContext.mounted) {
                          showActionSnackBar(sheetContext, 'Could not reach the server — changes were not saved');
                        }
                      }
                    },
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      setState(() {});
      widget.onChanged();
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    final p = widget.post;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.brick)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (p.id != null) {
      try {
        await runWithLoadingOverlay(
          context,
          () => BackendRepository.deleteCommunityPost(p.id!),
          message: 'Deleting…',
        );
      } on ApiException catch (e) {
        if (mounted) showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        if (mounted) showActionSnackBar(context, 'Could not reach the server — post was not deleted');
        return;
      }
    }
    if (!mounted) return;
    MockData.communityPosts.remove(p);
    widget.onChanged();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final localComment = PostComment(
      author: MockData.currentUser.fullName,
      text: text,
      postedAt: DateTime.now(),
    );
    setState(() {
      widget.post.comments.add(localComment);
      _commentController.clear();
      _showComments = true;
    });
    widget.onChanged();

    // POST /api/community-posts/:id/comments — best-effort backend sync;
    // the comment is already shown locally either way (optimistic update).
    final postId = widget.post.id;
    if (postId != null && AuthSession.isLoggedIn) {
      BackendRepository.addComment(postId: postId, text: text).catchError((_) {
        // Backend unreachable or rejected — comment stays as a local-only
        // entry, same as before this app had a backend at all.
        return localComment;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final color = widget.color;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(p.author.substring(0, 1), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.author, style: Theme.of(context).textTheme.titleMedium),
                      Text(_relativeTime(p.postedAt), style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                StatusPill(label: p.category, color: color),
                if (p.authorId != null && p.authorId == AuthSession.userId)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') _editPost(context);
                      if (v == 'delete') _deletePost(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(p.content, style: Theme.of(context).textTheme.bodyLarge),
            if (p.price != null) ...[
              const SizedBox(height: 8),
              Text(p.price!, style: const TextStyle(color: AppColors.brass, fontWeight: FontWeight.w700)),
            ],
            if (p.imageBytes != null || p.imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: ListingImage(url: p.imageUrl ?? '', bytes: p.imageBytes, height: 180),
              ),
            ],
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showComments = !_showComments),
              child: Row(
                children: [
                  const Icon(Icons.mode_comment_outlined, size: 16, color: AppColors.inkFaint),
                  const SizedBox(width: 4),
                  Text(
                    p.comments.isEmpty ? 'Comment' : '${p.comments.length} comment${p.comments.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            if (_showComments) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (p.comments.isEmpty)
                Text('No comments yet — be the first to reply.', style: Theme.of(context).textTheme.bodyMedium)
              else
                ...p.comments.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.paperDim,
                            child: Text(c.author.substring(0, 1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(c.author, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    Text(_relativeTime(c.postedAt), style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(c.text, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment…',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_outlined, color: AppColors.parade),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
