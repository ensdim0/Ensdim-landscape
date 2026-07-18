import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/presentation/widgets/custom_app_bar.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/domain/entities/contract_task.dart';
import 'package:bustan_amari/domain/entities/visit.dart';
import 'package:bustan_amari/presentation/providers/supervisor_provider.dart';

class TaskExecutionScreen extends StatefulWidget {
  final ContractTask task;
  final Visit visit;

  const TaskExecutionScreen({
    super.key,
    required this.task,
    required this.visit,
  });

  @override
  State<TaskExecutionScreen> createState() => _TaskExecutionScreenState();
}

class _TaskExecutionScreenState extends State<TaskExecutionScreen> {
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();
  double? _gpsLat;
  double? _gpsLng;
  final List<_PhotoEntry> _pendingPhotos = [];
  bool _gpsRecorded = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;
    final buttonHeight = screenWidth < 360 ? 46.0 : 48.0;

    return Scaffold(
      appBar: CustomAppBar(
        title: t.tr('taskExecution'),
        backButtonBackgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          horizontalPadding,
          horizontalPadding,
          horizontalPadding + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // Task info
          _buildTaskInfoCard(theme, t),
          const SizedBox(height: 16),

          // Notes
          _buildNotesCard(theme, t),
          const SizedBox(height: 16),

          // Photos
          _buildPhotosCard(theme, t),
          const SizedBox(height: 16),

          // GPS
          _buildGpsCard(theme, t),
          const SizedBox(height: 24),

          // Submit
          Consumer<SupervisorProvider>(
            builder: (context, provider, _) {
              return SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: FilledButton.icon(
                  onPressed: provider.isActionLoading ? null : _submit,
                  icon: provider.isActionLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(t.tr('executeTask')),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInfoCard(ThemeData theme, AppLocalizations t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${t.tr('taskMonth')}: ${widget.task.month}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(ThemeData theme, AppLocalizations t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.tr('taskNotes'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: t.tr('taskNotesHint'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosCard(ThemeData theme, AppLocalizations t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  t.tr('photos'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_pendingPhotos.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Photo grid
            if (_pendingPhotos.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pendingPhotos.asMap().entries.map((entry) {
                  final photo = entry.value;
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image,
                                color: theme.colorScheme.primary,
                              ),
                              Text(
                                photo.type == 'before'
                                    ? t.tr('beforePhoto')
                                    : t.tr('afterPhoto'),
                                style: theme.textTheme.labelSmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _pendingPhotos.removeAt(entry.key);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Photo actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto('before'),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(t.tr('beforePhoto')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto('after'),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(t.tr('afterPhoto')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsCard(ThemeData theme, AppLocalizations t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: _gpsRecorded
                      ? const Color(0xFF30461F)
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  t.tr('recordGps'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_gpsRecorded) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    t.tr('gpsRecorded'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _recordGps,
                icon: const Icon(Icons.my_location),
                label: Text(t.tr('recordGps')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(String type) async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) {
          final t = AppLocalizations.of(ctx);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(t.tr('takePhoto')),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(t.tr('chooseFromGallery')),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (!mounted || picked == null) return;

      setState(() {
        _pendingPhotos.add(_PhotoEntry(path: picked.path, type: type));
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tr('errorUploadingPhoto')),
        ),
      );
    }
  }

  Future<void> _recordGps() async {
    final t = AppLocalizations.of(context);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tr('locationServicesDisabled'))),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tr('locationPermissionDenied'))),
          );
          await Geolocator.openAppSettings();
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tr('locationPermissionDenied'))),
          );
        }
        return;
      }

      const bestSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 12),
      );
      const highSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      );

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: bestSettings,
        );
      } catch (_) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: highSettings,
          );
        } catch (_) {
          final last = await Geolocator.getLastKnownPosition();
          if (last == null) rethrow;
          if (!mounted) return;
          setState(() {
            _gpsLat = last.latitude;
            _gpsLng = last.longitude;
            _gpsRecorded = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tr('locationUsingLastKnown'))),
          );
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _gpsLat = position.latitude;
        _gpsLng = position.longitude;
        _gpsRecorded = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.tr('locationFetchFailed'))));
      }
    }
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final completedMessage = t.tr('taskCompleted');
    final errorMessage = t.tr('errorExecutingTask');
    final provider = context.read<SupervisorProvider>();

    final execution = await provider.executeTask(
      taskId: widget.task.id,
      visitId: widget.visit.id,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      gpsLat: _gpsLat,
      gpsLng: _gpsLng,
    );

    if (!mounted) return;

    if (execution != null) {
      // Upload pending photos
      for (final photo in _pendingPhotos) {
        await provider.uploadPhoto(
          executionId: execution.id,
          filePath: photo.path,
          photoType: photo.type,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completedMessage),
          backgroundColor: const Color(0xFF30461F),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }
}

class _PhotoEntry {
  final String path;
  final String type;

  const _PhotoEntry({required this.path, required this.type});
}
