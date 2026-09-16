import 'package:flutter/material.dart';

import '../../core/models/pet.dart';
import '../../core/models/scan.dart';
import '../../core/models/urgency_level.dart';
import '../../core/services/ai_triage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/urgency_colors.dart';
import '../../core/utils/photo_image_provider.dart';
import '../scan/result_screen.dart';

/// Per-pet scan history, per section 7 of the "Paw Check claude design"
/// handoff doc (see that folder's README.md at the repo root): back
/// chevron + "{pet name}'s timeline" heading, a scrollable list of scan
/// rows (thumbnail, date, note, tier badge), and an empty state.
///
/// [scans] is passed in rather than loaded here — `HomeScreen` owns the
/// live `ScanRepository` subscription for whichever pet is selected and
/// hands the current list down. Per the doc's own interaction rule, opening
/// a Results screen from here uses `push` (not `pushReplacement` like a
/// fresh scan does), so the back chevron on that historical Results screen
/// returns here rather than to Home.
///
/// [onDelete], if given, shows a delete icon on each row (PRD Milestone 6:
/// "delete individual scan / delete pet profile (with confirmation)" — a
/// functional requirement the design doc's static mockup doesn't depict,
/// so its placement here is this screen's own call, not the doc's).
/// Tapping it always confirms first; the actual removal is the caller's
/// responsibility (same optional-callback pattern as `HomeScreen`'s
/// `addPetPickPhoto`) — omit it to render a read-only list.
///
/// [bottomNavigationBar], if given, lets `HomeScreen` embed this screen as
/// one of its bottom-nav tabs (rendered directly, not pushed) while
/// keeping the same floating nav bar visible — see `HomeScreen`'s class
/// doc comment for why tapping Timeline/Settings no longer navigates at
/// all. Left null when Timeline is used standalone (as every existing
/// test here does).
class TimelineScreen extends StatelessWidget {
  const TimelineScreen({
    super.key,
    required this.pet,
    required this.scans,
    this.onDelete,
    this.bottomNavigationBar,
  });

  final Pet pet;
  final List<Scan> scans;
  final void Function(Scan scan)? onDelete;
  final Widget? bottomNavigationBar;

  Future<void> _confirmDelete(BuildContext context, Scan scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete!(scan);
  }

  void _openScan(BuildContext context, Scan scan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          pet: pet,
          result: TriageResult(
            description: scan.aiDescription,
            causes: scan.aiCauses,
            urgencyLevel: scan.urgencyLevel,
            vetRecommended: scan.showsFindVetCta,
          ),
          photo: photoImageProvider(scan.photoUrl),
          scanDate: scan.timestamp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // Most-recent-first, per PRD Milestone 6 — [scans] arrives in whatever
    // order the caller happens to hold it in, not necessarily sorted.
    final sortedScans = [...scans]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final initial = pet.name.isEmpty ? '?' : pet.name[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        // When embedded as a bottom-nav tab (`bottomNavigationBar` given),
        // this must never grow a back chevron — it's a peer destination,
        // not a pushed screen. Can't rely on `Navigator.canPop(context)`
        // alone: the real app's actual route stack is
        // `[OnboardingScreen, HomeScreen]` (Onboarding `push`ed
        // AccountSetup, which then `pushReplacement`d itself with
        // HomeScreen), so `canPop` is genuinely `true` here even though
        // this screen has nothing of its own to pop back to.
        automaticallyImplyLeading: bottomNavigationBar == null,
        titleSpacing: AppTheme.spaceMd,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: Text(
                initial,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${pet.name}'s timeline",
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '${pet.species} · ${scans.length} scans',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: scans.isEmpty
            ? _EmptyTimeline(pet: pet)
            : ListView.separated(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                itemCount: sortedScans.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.spaceSm),
                itemBuilder: (context, index) {
                  final scan = sortedScans[index];
                  return _ScanRow(
                    scan: scan,
                    onTap: () => _openScan(context, scan),
                    onDelete: onDelete == null
                        ? null
                        : () => _confirmDelete(context, scan),
                  );
                },
              ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Empty state — was a single line of plain gray text ("No scans yet."),
/// which read as an afterthought against every other screen's more
/// deliberate empty/placeholder treatment (e.g. `AccountSetupScreen`'s
/// icon-in-a-circle header badge). Same icon as this screen's own bottom-
/// nav tab (`Icons.watch_later_outlined`), so the empty state visually
/// echoes how the user got here.
class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.watch_later_outlined,
                size: 44,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text('No scans yet', style: textTheme.headlineSmall),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              "Scan ${pet.name} and their results will show up here, so "
              "you can track how things change over time.",
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanRow extends StatelessWidget {
  const _ScanRow({required this.scan, required this.onTap, this.onDelete});

  final Scan scan;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Image(
                  image: photoImageProvider(scan.photoUrl),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 48,
                    height: 48,
                    color: colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(scan.timestamp),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scan.note ?? scan.aiDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              _TierBadge(level: scan.urgencyLevel),
              if (onDelete != null)
                IconButton(
                  key: Key('delete_scan_button_${scan.id}'),
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: colorScheme.onSurfaceVariant,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tier badge pill. [UrgencyTierColors.forLevel] has no triplet for
/// [UrgencyLevel.emergency] (it's a full-screen takeover elsewhere, not a
/// tint) so that case is handled separately here with the same solid red
/// `emergencyBackground` used on the Emergency results view.
class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.level});

  final UrgencyLevel level;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (level == UrgencyLevel.emergency) {
      background = UrgencyTierColors.emergencyBackground;
      foreground = Colors.white;
    } else {
      final tier = UrgencyTierColors.forLevel(level);
      background = tier.backgroundTint;
      foreground = tier.textOnTint;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        level.wireValue,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
