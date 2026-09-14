import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'payments_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Role-aware entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Pass [viewerRole] to get the right experience:
///   • residentOwner  → read-only timeline view of their project
///   • developer      → editable stage management view
///   • admin          → oversight dashboard with permit controls
class ConstructionLifecycleScreen extends StatefulWidget {
  final UserRole viewerRole;

  const ConstructionLifecycleScreen({
    super.key,
    this.viewerRole = UserRole.residentOwner,
  });

  @override
  State<ConstructionLifecycleScreen> createState() =>
      _ConstructionLifecycleScreenState();
}

class _ConstructionLifecycleScreenState
    extends State<ConstructionLifecycleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: _appBarActions(),
      ),
      body: ConstructionBody(viewerRole: widget.viewerRole),
    );
  }

  String get _appBarTitle => switch (widget.viewerRole) {
        UserRole.residentOwner => 'My Construction',
        UserRole.developer => 'Manage Construction',
        UserRole.admin => 'Construction Oversight',
        _ => 'Construction Lifecycle',
      };

  List<Widget>? _appBarActions() {
    return null;
  }
}

/// Body-only version of the construction lifecycle screen — reusable inside
/// other Scaffolds (e.g. the developer dashboard's Construction tab) without
/// nesting a second Scaffold/AppBar.
class ConstructionBody extends StatefulWidget {
  final UserRole viewerRole;

  const ConstructionBody({super.key, this.viewerRole = UserRole.residentOwner});

  @override
  State<ConstructionBody> createState() => _ConstructionBodyState();
}

class _ConstructionBodyState extends State<ConstructionBody> {
  int _selectedIndex = 0;
  bool _loading = false;

  List<ConstructionProject> get _projects => MockData.constructionProjects;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // GET /api/construction/projects/mine — was never called from this
  // widget, so it only ever showed whatever MockData.constructionProjects
  // held from the login-time sync (or, if that sync came back empty, the
  // hardcoded demo seed project — showing a resident someone else's fake
  // "Ashraf Family Residence" project as if it were their own). Adding an
  // explicit fetch + pull-to-refresh here matches every other tab in the
  // app and lets a resident/developer/admin refresh without logging out.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final projects = await BackendRepository.fetchConstructionProjects();
      // Bug fix: always reflect the real (possibly empty) list on a
      // successful fetch — an isNotEmpty guard here kept showing the
      // hardcoded mock "Ashraf Family Residence" project to residents who
      // have zero real projects, as if it were their own. See the matching
      // fix in sync_service.dart's _syncConstructionProjects for the same
      // issue at login time.
      if (mounted) {
        setState(() {
          MockData.constructionProjects..clear()..addAll(projects);
          if (_selectedIndex >= MockData.constructionProjects.length) {
            _selectedIndex = 0;
          }
        });
      }
    } on ApiException catch (_) {
    } on ApiUnreachableException {
      // keep mock data
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = _projects;
    // Was `projects[_selectedIndex]` with no guard — a resident/developer/
    // admin with zero construction projects (e.g. before any project has
    // been started) would hit a RangeError and crash this whole tab.
    if (projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const EmptyState(
              icon: Icons.construction_outlined,
              title: 'No construction projects yet',
              message: 'Once a developer starts tracking your build, it will show up here.',
            ),
            // Soil testing is normally applied for BEFORE a developer is
            // even assigned (you test the plot to see if it's buildable),
            // so residents must be able to request it even with zero
            // ConstructionProject rows yet — it used to only be reachable
            // from inside a specific project's Permits card, which meant a
            // resident with no tracked project had no way to apply at all.
            if (widget.viewerRole == UserRole.residentOwner) ...[
              const SizedBox(height: 24),
              const SectionHeader(eyebrow: 'Approvals', title: 'Soil Testing'),
              const SizedBox(height: 12),
              _StandaloneSoilTestSection(onChanged: () => setState(() {})),
            ],
          ],
        ),
      );
    }
    // The selector chips below are index-based; if the list shrank (e.g.
    // after a refresh) the previously-selected index could now be out of
    // range, which would also crash the lookup below.
    if (_selectedIndex >= projects.length) _selectedIndex = 0;
    final project = projects[_selectedIndex];
    final overallProgress = _overallProgress(project);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        // ── Hero banner ──────────────────────────────────────────
        _HeroBanner(
          project: project,
          overallProgress: overallProgress,
          viewerRole: widget.viewerRole,
        ),
        const SizedBox(height: 20),

        // ── Project selector chips ───────────────────────────────
        if (projects.length > 1) ...[
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = _selectedIndex == index;
                return ChoiceChip(
                  label: Text(
                    projects[index].plotReference
                        .split(',')
                        .first
                        .trim(),
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedIndex = index),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Project details card ─────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(project.plotReference,
                          style:
                              Theme.of(context).textTheme.titleMedium),
                    ),
                    _PermitBadge(status: project.permitStatus),
                  ],
                ),
                const SizedBox(height: 8),
                _DetailRow(
                    label: 'Developer', value: project.developerName),
                _DetailRow(
                    label: 'Est. completion',
                    value: project.estimatedCompletion),
                _DetailRow(
                    label: 'Current phase',
                    value: _currentStageLabel(project)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Resident-only: Permits ────────────────────────────────
        if (widget.viewerRole == UserRole.residentOwner) ...[
          const SectionHeader(eyebrow: 'Approvals', title: 'Permits'),
          const SizedBox(height: 12),
          _ResidentPermitsSection(
            project: project,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 24),
        ],

        // ── Stages ──────────────────────────────────────────────
        SectionHeader(
          eyebrow: 'Lifecycle stages',
          title: _stagesSectionTitle,
        ),
        const SizedBox(height: 12),

        ...project.stages.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildStageCard(
                    context, entry.key, entry.value, project),
              ),
            ),
        if (project.stages.isEmpty)
          const EmptyState(
            icon: Icons.pending_actions_outlined,
            title: 'No stages yet',
            message: 'The developer has not submitted a construction stage for this project yet.',
          ),

        // ── Admin-only: permit action panel ─────────────────────
        if (widget.viewerRole == UserRole.admin) ...[
          const SizedBox(height: 8),
          _AdminPermitPanel(
            project: project,
            onStatusChanged: () => setState(() {}),
          ),
        ],
      ],
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _stagesSectionTitle => switch (widget.viewerRole) {
        UserRole.developer => 'Update stage progress',
        UserRole.admin => 'Stage breakdown',
        _ => 'Progress by phase',
      };

  Widget _buildStageCard(BuildContext context, int index,
      ConstructionStage stage, ConstructionProject project) {
    return switch (widget.viewerRole) {
      UserRole.developer => _DeveloperStageCard(
          index: index,
          stage: stage,
          onUpdate: () => setState(() {}),
        ),
      UserRole.admin => _AdminStageCard(
          index: index,
          stage: stage,
          onReviewed: () => setState(() {}),
        ),
      _ => _ResidentStageCard(index: index, stage: stage),
    };
  }

  double _overallProgress(ConstructionProject project) {
    // Was `total / project.stages.length` with no guard — a project with
    // no stages yet (before the developer submits the first one) has
    // stages.length == 0, which divides by zero and shows "NaN%" on the
    // progress bar.
    if (project.stages.isEmpty) return 0;
    final total =
        project.stages.fold<double>(0, (sum, s) => sum + s.progress);
    return total / project.stages.length;
  }

  String _currentStageLabel(ConstructionProject project) {
    // Was `orElse: () => project.stages.last`, which throws (Bad state: No
    // element) when a project has no stages yet — reachable as soon as a
    // developer starts a project but hasn't submitted its first stage.
    if (project.stages.isEmpty) return 'Not started yet';
    final active = project.stages.firstWhere(
      (s) =>
          s.status == ConstructionStageStatus.inProgress ||
          s.status == ConstructionStageStatus.delayed,
      orElse: () => project.stages.last,
    );
    return active.title;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Banner
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final ConstructionProject project;
  final double overallProgress;
  final UserRole viewerRole;

  const _HeroBanner({
    required this.project,
    required this.overallProgress,
    required this.viewerRole,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (viewerRole) {
      UserRole.developer => 'Manage your project stages below',
      UserRole.admin => 'Reviewing ${MockData.constructionProjects.length} active projects',
      _ => '${(overallProgress * 100).round()}% overall complete',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.parade, AppColors.paradeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _eyebrow,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.brass),
          ),
          const SizedBox(height: 6),
          Text(
            project.projectName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.brass),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(overallProgress * 100).round()}% complete',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11.5),
              ),
              Text(
                'ETA: ${project.estimatedCompletion}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _eyebrow => switch (viewerRole) {
        UserRole.developer => 'DEVELOPER PANEL',
        UserRole.admin => 'AUTHORITY OVERSIGHT',
        _ => 'PROJECT TRACKER',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Resident Stage Card (read-only timeline style)
// ─────────────────────────────────────────────────────────────────────────────

class _ResidentStageCard extends StatelessWidget {
  final int index;
  final ConstructionStage stage;

  const _ResidentStageCard({required this.index, required this.stage});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(stage.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: stage.status == ConstructionStageStatus.completed
                      ? Icon(Icons.check, color: color, size: 16)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(stage.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                          ),
                          StatusPill(
                              label: stage.status.label,
                              color: color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(stage.description,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                      // Developer note visible to resident
                      if (stage.developerNote.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color:
                                AppColors.brass.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppRadii.sm),
                            border: Border.all(
                                color: AppColors.brass
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: AppColors.brass),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  stage.developerNote,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: stage.progress,
                minHeight: 9,
                backgroundColor: AppColors.paperDim,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${(stage.progress * 100).round()}% done',
                    style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                const Icon(Icons.schedule_outlined,
                    size: 12, color: AppColors.inkFaint),
                const SizedBox(width: 3),
                Text(stage.eta,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ConstructionStageStatus status) => switch (status) {
        ConstructionStageStatus.completed => AppColors.parade,
        ConstructionStageStatus.inProgress => AppColors.lake,
        ConstructionStageStatus.upcoming => AppColors.brass,
        ConstructionStageStatus.delayed => AppColors.brick,
        ConstructionStageStatus.pendingApproval => AppColors.brass,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Developer Stage Card (editable)
// ─────────────────────────────────────────────────────────────────────────────

class _DeveloperStageCard extends StatelessWidget {
  final int index;
  final ConstructionStage stage;
  final VoidCallback onUpdate;

  const _DeveloperStageCard({
    required this.index,
    required this.stage,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(stage.status);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(
            color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(stage.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium)),
                          StatusPill(
                              label: stage.status.label, color: color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(stage.description,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress slider
            Row(
              children: [
                const Text('Progress',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${(stage.progress * 100).round()}%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.12),
                inactiveTrackColor: AppColors.paperDim,
                trackHeight: 5,
              ),
              child: Slider(
                value: stage.progress,
                min: 0,
                max: 1,
                divisions: 20,
                onChanged: (v) {
                  stage.progress = v;
                  // Auto-update status based on progress
                  if (v >= 1.0) {
                    stage.status = ConstructionStageStatus.completed;
                    stage.eta = 'Completed';
                  } else if (v > 0 &&
                      stage.status ==
                          ConstructionStageStatus.upcoming) {
                    stage.status = ConstructionStageStatus.inProgress;
                  }
                  onUpdate();
                },
                // Push the final value to backend once the user releases
                // the thumb (avoids spamming PATCH on every tick).
                onChangeEnd: (v) async {
                  if (stage.id == null || !AuthSession.isLoggedIn) return;
                  try {
                    await BackendRepository.updateConstructionStage(
                      stage.id!,
                      progress: v,
                      eta: stage.eta,
                    );
                  } catch (_) {
                    // Offline — local state already updated; silently ignore.
                  }
                },
              ),
            ),

            // Status picker
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Status:',
                    style: TextStyle(fontSize: 12.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          ConstructionStageStatus.values.map((s) {
                        final sc = _statusColor(s);
                        final selected = stage.status == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              stage.status = s;
                              if (s == ConstructionStageStatus.completed) {
                                stage.progress = 1.0;
                                stage.eta = 'Completed';
                              }
                              onUpdate();
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: selected
                                    ? sc.withValues(alpha: 0.15)
                                    : AppColors.paperDim,
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: selected
                                    ? Border.all(
                                        color: sc, width: 1.2)
                                    : null,
                              ),
                              child: Text(
                                s.label,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? sc
                                        : AppColors.inkFaint),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ETA field
            TextField(
              controller:
                  TextEditingController(text: stage.eta),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'ETA / timeline note',
                prefixIcon:
                    Icon(Icons.schedule_outlined, size: 18),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onSubmitted: (v) {
                stage.eta = v.trim().isEmpty ? stage.eta : v.trim();
                onUpdate();
              },
            ),

            const SizedBox(height: 10),

            // Developer note
            _DeveloperNoteField(stage: stage, onUpdate: onUpdate),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ConstructionStageStatus status) => switch (status) {
        ConstructionStageStatus.completed => AppColors.parade,
        ConstructionStageStatus.inProgress => AppColors.lake,
        ConstructionStageStatus.upcoming => AppColors.brass,
        ConstructionStageStatus.delayed => AppColors.brick,
        ConstructionStageStatus.pendingApproval => AppColors.brass,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Stage Card (oversight, read-only with highlight on delays)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminStageCard extends StatelessWidget {
  final int index;
  final ConstructionStage stage;
  final VoidCallback onReviewed;

  const _AdminStageCard({required this.index, required this.stage, required this.onReviewed});

  void _approve(BuildContext context) async {
    if (stage.id != null) {
      try {
        await runWithLoadingOverlay(
          context,
          () => BackendRepository.reviewConstructionStage(stage.id!, approve: true),
          message: 'Approving stage…',
        );
      } on ApiException catch (e) {
        if (!context.mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // fall through — apply the optimistic local update anyway
      }
    }
    stage.status = stage.progress >= 1
        ? ConstructionStageStatus.completed
        : ConstructionStageStatus.inProgress;
    onReviewed();
    if (!context.mounted) return;
    showActionSnackBar(context, 'Stage "${stage.title}" approved');
  }

  void _sendBack(BuildContext context) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        title: const Text('Send stage back'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason for the developer'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brick),
            onPressed: () async {
              final note = noteController.text.trim();
              if (stage.id != null) {
                try {
                  await runWithLoadingOverlay(
                    dialogContext,
                    () => BackendRepository.reviewConstructionStage(stage.id!, approve: false, note: note),
                    message: 'Sending back…',
                  );
                } on ApiException catch (e) {
                  if (!dialogContext.mounted) return;
                  showActionSnackBar(dialogContext, e.message);
                  return;
                } on ApiUnreachableException {
                  // fall through — apply the optimistic local update anyway
                }
              }
              stage.status = ConstructionStageStatus.delayed;
              if (note.isNotEmpty) stage.developerNote = note;
              onReviewed();
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!context.mounted) return;
              showActionSnackBar(context, 'Stage "${stage.title}" sent back');
            },
            child: const Text('Send back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(stage.status);
    final isDelayed = stage.status == ConstructionStageStatus.delayed;

    return Card(
      shape: isDelayed
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: const BorderSide(color: AppColors.brick, width: 1.4),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(stage.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium)),
                          StatusPill(
                              label: stage.status.label, color: color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(stage.description,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                      if (isDelayed) ...[
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_outlined,
                                size: 14, color: AppColors.brick),
                            SizedBox(width: 4),
                            Text(
                              'Delay flagged — may need authority action',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.brick,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                      if (stage.developerNote.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Developer note: ${stage.developerNote}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkFaint),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: stage.progress,
                minHeight: 8,
                backgroundColor: AppColors.paperDim,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${(stage.progress * 100).round()}% complete',
                    style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text(stage.eta,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            if (stage.status != ConstructionStageStatus.completed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.brick, side: const BorderSide(color: AppColors.brick)),
                      onPressed: () => _sendBack(context),
                      child: const Text('Send back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(context),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(ConstructionStageStatus status) => switch (status) {
        ConstructionStageStatus.completed => AppColors.parade,
        ConstructionStageStatus.inProgress => AppColors.lake,
        ConstructionStageStatus.upcoming => AppColors.brass,
        ConstructionStageStatus.delayed => AppColors.brick,
        ConstructionStageStatus.pendingApproval => AppColors.brass,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Permit Panel
// ─────────────────────────────────────────────────────────────────────────────

class _AdminPermitPanel extends StatelessWidget {
  final ConstructionProject project;
  final VoidCallback onStatusChanged;

  const _AdminPermitPanel({
    required this.project,
    required this.onStatusChanged,
  });

  void _setStatus(BuildContext context, ConstructionPermitStatus status) async {
    if (project.id != null) {
      try {
        await BackendRepository.updatePermitStatus(project.id!, status);
      } on ApiException catch (e) {
        if (!context.mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // fall through — apply the optimistic local update anyway
      }
    }
    project.permitStatus = status;
    onStatusChanged();
    if (!context.mounted) return;
    showActionSnackBar(
      context,
      status == ConstructionPermitStatus.approved
          ? 'Permit approved for ${project.projectName}'
          : 'Permit rejected',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paperDim,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: AppColors.parade, size: 20),
              const SizedBox(width: 8),
              Text('Permit Management',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.parade)),
              const Spacer(),
              _PermitBadge(status: project.permitStatus),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'As Jolshiri Management Authority, you can approve or reject the construction permit for this project.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brick,
                      side: const BorderSide(color: AppColors.brick)),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Reject'),
                  onPressed: project.permitStatus ==
                          ConstructionPermitStatus.rejected
                      ? null
                      : () => _setStatus(context, ConstructionPermitStatus.rejected),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Approve'),
                  onPressed: project.permitStatus ==
                          ConstructionPermitStatus.approved
                      ? null
                      : () => _setStatus(context, ConstructionPermitStatus.approved),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Developer Note Field
// ─────────────────────────────────────────────────────────────────────────────

class _DeveloperNoteField extends StatefulWidget {
  final ConstructionStage stage;
  final VoidCallback onUpdate;

  const _DeveloperNoteField(
      {required this.stage, required this.onUpdate});

  @override
  State<_DeveloperNoteField> createState() => _DeveloperNoteFieldState();
}

class _DeveloperNoteFieldState extends State<_DeveloperNoteField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.stage.developerNote);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Update note for resident',
            hintText: 'e.g. Piling complete, footing in progress…',
            prefixIcon:
                Icon(Icons.edit_note_outlined, size: 18),
            alignLabelWithHint: true,
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final note = _ctrl.text.trim();
              widget.stage.developerNote = note;

              // PATCH /api/construction/stages/:id — push progress, ETA,
              // and note to the backend so Jolshiri Management can review.
              if (widget.stage.id != null && AuthSession.isLoggedIn) {
                try {
                  await runWithLoadingOverlay(
                    context,
                    () => BackendRepository.updateConstructionStage(
                      widget.stage.id!,
                      progress: widget.stage.progress,
                      eta: widget.stage.eta,
                      developerNote: note,
                    ),
                    message: 'Saving update…',
                  );
                } on ApiException catch (e) {
                  if (!context.mounted) return;
                  showActionSnackBar(context, e.message);
                  return;
                } on ApiUnreachableException {
                  // fall through — local update already applied above
                }
              }

              widget.onUpdate();
              if (!context.mounted) return;
              showActionSnackBar(context, 'Stage update saved');
            },
            child: const Text('Save update'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project Note Dialog (developer app-bar action)
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectNoteDialog extends StatefulWidget {
  final ConstructionProject project;

  const _ProjectNoteDialog({required this.project});

  @override
  State<_ProjectNoteDialog> createState() => _ProjectNoteDialogState();
}

class _ProjectNoteDialogState extends State<_ProjectNoteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Project-level note'),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Add a general note visible to admin…',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            showActionSnackBar(context, 'Note saved');
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resident: standalone "Apply for soil testing" — shown when the resident
// has no ConstructionProject yet (soil testing normally happens BEFORE a
// developer is assigned, to check if a plot is buildable at all).
// ─────────────────────────────────────────────────────────────────────────────

class _StandaloneSoilTestSection extends StatefulWidget {
  final VoidCallback onChanged;
  const _StandaloneSoilTestSection({required this.onChanged});

  @override
  State<_StandaloneSoilTestSection> createState() => _StandaloneSoilTestSectionState();
}

class _StandaloneSoilTestSectionState extends State<_StandaloneSoilTestSection> {
  @override
  Widget build(BuildContext context) {
    // GET /api/construction/soil-tests/mine already scopes this list to the
    // signed-in resident (see sync_service.dart's _syncMySoilTests), so no
    // extra filtering is needed here — just show it newest-first.
    final applications = List<SoilTestApplication>.from(MockData.soilTestApplications)
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.landscape_outlined, color: AppColors.parade, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text('Soil Testing Permit')),
                if (applications.isNotEmpty) _SoilTestBadge(status: applications.first.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Required before foundation work begins. Apply here to have the Authority schedule a soil test for your plot — even before a developer is assigned.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_task_outlined, size: 18),
                label: const Text('Apply for soil testing'),
                onPressed: () => _showApplyDialog(context),
              ),
            ),
            if (applications.isNotEmpty) ...[
              const Divider(height: 28),
              Text('Your applications', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...applications.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(a.projectName,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            _SoilTestBadge(status: a.status),
                          ],
                        ),
                        Text(a.plotReference, style: Theme.of(context).textTheme.labelSmall),
                        if (a.status == SoilTestStatus.permitGranted) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payments_outlined, size: 18),
                              label: const Text('Pay now'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                                );
                              },
                            ),
                          ),
                        ] else if (a.status == SoilTestStatus.completed) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Your soil testing document is ready to be received.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.lake),
                          ),
                        ],
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _showApplyDialog(BuildContext context) {
    final plotController = TextEditingController();
    final projectController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply for soil testing'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: projectController,
                decoration: const InputDecoration(
                  labelText: 'Project name',
                  hintText: 'e.g. My Residence Extension',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: plotController,
                decoration: const InputDecoration(
                  labelText: 'Plot reference',
                  hintText: 'e.g. Plot 3-015, Sector 3, Main Boulevard',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop();
              await _submitApplication(
                context,
                plotReference: plotController.text.trim(),
                projectName: projectController.text.trim(),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitApplication(
    BuildContext context, {
    required String plotReference,
    required String projectName,
  }) async {
    if (!AuthSession.isLoggedIn) {
      showActionSnackBar(context, 'Please sign in to apply for soil testing');
      return;
    }
    try {
      final saved = await runWithLoadingOverlay(
        context,
        () => BackendRepository.createSoilTest(
          plotReference: plotReference,
          projectName: projectName,
        ),
        message: 'Submitting application…',
      );
      MockData.soilTestApplications.insert(
        0,
        SoilTestApplication(
          applicantName: MockData.currentUser.fullName,
          plotReference: saved.plotReference,
          projectName: saved.projectName,
          appliedAt: saved.appliedAt,
          status: saved.status,
          note: saved.note,
        ),
      );
      widget.onChanged();
      if (!context.mounted) return;
      setState(() {});
      showActionSnackBar(context, 'Soil testing permit requested');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      if (!context.mounted) return;
      showActionSnackBar(context, "Can't reach the server — check your connection");
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resident: Permits section (inside Build Track)
// ─────────────────────────────────────────────────────────────────────────────

class _ResidentPermitsSection extends StatelessWidget {
  final ConstructionProject project;
  final VoidCallback onChanged;

  const _ResidentPermitsSection({
    required this.project,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // GET /api/construction/soil-tests/mine already scopes this to the
    // signed-in resident's own applications — matching by exact plot text
    // used to hide a real application whenever the free-typed plot
    // reference didn't character-for-character match the project's, so we
    // just take the most recent application overall instead.
    final applications = List<SoilTestApplication>.from(MockData.soilTestApplications)
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    final latest = applications.isEmpty ? null : applications.first;

    return Column(
      children: [
        // Construction permit (approved/rejected by the Authority).
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: AppColors.parade, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Construction Permit',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('Issued by Jolshiri Management Authority',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                _PermitBadge(status: project.permitStatus),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Soil testing permit.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.landscape_outlined,
                        color: AppColors.parade, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Soil Testing Permit',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (latest != null) _SoilTestBadge(status: latest.status),
                  ],
                ),
                const SizedBox(height: 8),
                if (latest == null) ...[
                  Text(
                    'Required before foundation work begins. Apply to have the Authority schedule a soil test for this plot.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_task_outlined, size: 18),
                      label: const Text('Apply for soil testing'),
                      onPressed: () async {
                        // POST /api/construction/soil-tests — real backend
                        // call when the user is signed in; falls back to a
                        // local mock insert if the backend is unreachable.
                        if (AuthSession.isLoggedIn) {
                          try {
                            final saved = await runWithLoadingOverlay(
                              context,
                              () => BackendRepository.createSoilTest(
                                plotReference: project.plotReference,
                                projectName: project.projectName,
                              ),
                              message: 'Submitting application…',
                            );
                            MockData.soilTestApplications.insert(
                              0,
                              SoilTestApplication(
                                applicantName: MockData.currentUser.fullName,
                                plotReference: saved.plotReference,
                                projectName: saved.projectName,
                                appliedAt: saved.appliedAt,
                                status: saved.status,
                                note: saved.note,
                              ),
                            );
                            onChanged();
                            if (!context.mounted) return;
                            showActionSnackBar(
                                context, 'Soil testing permit requested');
                            return;
                          } on ApiException catch (e) {
                            if (!context.mounted) return;
                            showActionSnackBar(context, e.message);
                            return;
                          } on ApiUnreachableException {
                            // fall through to the offline demo flow below
                          }
                        }
                        MockData.soilTestApplications.insert(
                          0,
                          SoilTestApplication(
                            applicantName: MockData.currentUser.fullName,
                            plotReference: project.plotReference,
                            projectName: project.projectName,
                            appliedAt: DateTime.now(),
                          ),
                        );
                        onChanged();
                        if (!context.mounted) return;
                        showActionSnackBar(
                            context, 'Soil testing permit requested');
                      },
                    ),
                  ),
                ] else ...[
                  _DetailRow(
                      label: 'Applied by', value: latest.applicantName),
                  _DetailRow(
                      label: 'Applied on',
                      value:
                          '${latest.appliedAt.day}/${latest.appliedAt.month}/${latest.appliedAt.year}'),
                  if (latest.note.isNotEmpty)
                    Text(latest.note,
                        style: Theme.of(context).textTheme.bodyMedium),
                  if (latest.status == SoilTestStatus.permitGranted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Pay now'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PaymentsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (latest.status == SoilTestStatus.paymentDone) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Payment received — the Authority will run the test and mark it complete.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else if (latest.status == SoilTestStatus.completed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Your soil testing document is ready to be received.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.lake),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SoilTestBadge extends StatelessWidget {
  final SoilTestStatus status;

  const _SoilTestBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      SoilTestStatus.completed => (AppColors.lake, Icons.task_alt_outlined),
      SoilTestStatus.paymentDone => (AppColors.lake, Icons.verified_outlined),
      SoilTestStatus.permitGranted => (AppColors.brass, Icons.event_outlined),
      SoilTestStatus.requested => (AppColors.brass, Icons.pending_outlined),
      SoilTestStatus.rejected => (AppColors.brick, Icons.cancel_outlined),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status.label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PermitBadge extends StatelessWidget {
  final ConstructionPermitStatus status;

  const _PermitBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ConstructionPermitStatus.approved => (AppColors.lake, Icons.verified_outlined),
      ConstructionPermitStatus.rejected => (AppColors.brick, Icons.cancel_outlined),
      ConstructionPermitStatus.pending => (AppColors.brass, Icons.pending_outlined),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status.label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
