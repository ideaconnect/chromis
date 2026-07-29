import 'dart:io';

/// Replaces [target]'s contents in one step: the bytes go to a sibling
/// `<name>.tmp` (flushed to the device, not just to the OS page cache), which is
/// then renamed over the target. A same-filesystem [File.rename] replaces the
/// destination atomically, so a process kill or a full disk mid-write leaves
/// either the old file or the new one - never a truncated mixture of both.
///
/// This exists as one function because it was written twice and only once:
/// `ProjectRepository.save` did tmp + flush + rename and documented why, while
/// `SettingsStore` wrote in place. A truncated `settings.json` reads back as
/// `{}`, which clears the Pro entitlement, the onboarding flag and the model
/// preference together - and nothing restores them. Two hand-maintained copies
/// of a durability primitive is how one of them drifts, so there is now one.
///
/// Rethrows whatever the write failed with, after a best-effort cleanup of the
/// temp file; the caller decides whether that is worth surfacing.
Future<void> writeFileAtomically(File target, String contents) async {
  final tmp = File('${target.path}.tmp');
  try {
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(target.path);
  } catch (_) {
    try {
      if (tmp.existsSync()) tmp.deleteSync();
    } catch (_) {
      // Best-effort: a stray .tmp is inert - every reader matches on the real
      // name, and the next successful write replaces it.
    }
    rethrow;
  }
}
