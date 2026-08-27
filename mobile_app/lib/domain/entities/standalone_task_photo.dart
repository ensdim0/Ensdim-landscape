/// An optional photo taken at the start or end of a standalone task's visit.
class StandaloneTaskPhoto {
  final String id;
  final String taskId;
  final String phase; // 'start' | 'end'
  final String photoPath;
  final String photoUrl;

  const StandaloneTaskPhoto({
    required this.id,
    required this.taskId,
    required this.phase,
    required this.photoPath,
    required this.photoUrl,
  });
}
