import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task_visit_result.dart';
import 'package:ensdim_landscape/presentation/providers/supervisor_provider.dart';

enum StandaloneTaskVisitPhase { start, end }

/// Captures GPS (mandatory) and optional photos to either start or end a
/// standalone task's on-site visit. Mirrors FinishVisitScreen's GPS-capture
/// mechanics, trimmed to what this flow actually needs — no video, no
/// summary text, since the checklist already records what was done.
///
/// Takes [provider] explicitly rather than looking it up via Provider.of —
/// this screen is reached via Navigator.push, which in this app's shell
/// isn't reliably a descendant of wherever SupervisorProvider is created.
class StandaloneTaskVisitActionScreen extends StatefulWidget {
  final StandaloneTask task;
  final StandaloneTaskVisitPhase phase;
  final SupervisorProvider provider;

  const StandaloneTaskVisitActionScreen({
    super.key,
    required this.task,
    required this.phase,
    required this.provider,
  });

  @override
  State<StandaloneTaskVisitActionScreen> createState() =>
      _StandaloneTaskVisitActionScreenState();
}

class _StandaloneTaskVisitActionScreenState
    extends State<StandaloneTaskVisitActionScreen> {
  final _imagePicker = ImagePicker();
  final List<String> _photoPaths = [];
  double? _gpsLat;
  double? _gpsLng;
  bool _capturingGps = false;

  bool get _isStart => widget.phase == StandaloneTaskVisitPhase.start;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _captureGps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: CustomAppBar(
        title: t.tr(_isStart ? 'startVisit' : 'finishVisit'),
        backButtonBackgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: widget.provider,
        builder: (context, _) {
          final provider = widget.provider;
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: provider.isActionLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  icon: provider.isActionLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isStart
                              ? Icons.play_circle_rounded
                              : Icons.check_circle_rounded,
                          size: 24,
                        ),
                  label: Text(
                    t.tr(_isStart ? 'startVisit' : 'finishVisit'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 96 + bottomSafeInset),
        children: [
          _buildTaskHeaderCard(theme),
          const SizedBox(height: 16),

          _buildSectionTitle(theme, t.tr('visitPhotos')),
          _buildPhotosCard(theme, t),
          const SizedBox(height: 16),

          _buildSectionTitle(theme, t.tr('recordGps')),
          _buildGpsCard(theme, t),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTaskHeaderCard(ThemeData theme) {
    return _ModernCard(
      theme: theme,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isStart
                  ? Icons.play_circle_outline_rounded
                  : Icons.assignment_turned_in_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.task.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(ThemeData theme, AppLocalizations t) {
    return _ModernCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '${t.tr('photos')}: ${_photoPaths.length}',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_photoPaths.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _photoPaths.asMap().entries.map((entry) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(entry.value),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 84,
                          height: 84,
                          color: theme.colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _photoPaths.removeAt(entry.key)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _pickPhoto,
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: Text(t.tr('addPhotos')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsCard(ThemeData theme, AppLocalizations t) {
    return _ModernCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: _gpsLat != null
                    ? const Color(0xFF2F2160)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _gpsLat != null ? t.tr('locationCaptured') : t.tr('captureLocation'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _gpsLat != null
                        ? const Color(0xFF2F2160)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_gpsLat != null && _gpsLng != null)
            Text(
              '${_gpsLat!.toStringAsFixed(4)}, ${_gpsLng!.toStringAsFixed(4)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 10),
          if (_capturingGps)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(t.tr('capturingLocation')),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _captureGps,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(t.tr('captureLocation')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final action = await showModalBottomSheet<_PhotoPickAction>(
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
                  onTap: () => Navigator.pop(ctx, _PhotoPickAction.takePhoto),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(t.tr('chooseFromGallery')),
                  onTap: () => Navigator.pop(ctx, _PhotoPickAction.choosePhoto),
                ),
              ],
            ),
          );
        },
      );

      if (action == null) return;

      final picked = await _imagePicker.pickImage(
        source: action == _PhotoPickAction.takePhoto
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 70,
      );

      if (!mounted || picked == null) return;
      setState(() => _photoPaths.add(picked.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('errorUploadingPhoto'))),
      );
    }
  }

  Future<void> _captureGps() async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    _setCapturingGps(true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tr('locationServicesDisabled'))),
          );
        }
        _setCapturingGps(false);
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
        _setCapturingGps(false);
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tr('locationPermissionDenied'))),
          );
        }
        _setCapturingGps(false);
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
        position = await Geolocator.getCurrentPosition(locationSettings: bestSettings);
      } catch (_) {
        try {
          position = await Geolocator.getCurrentPosition(locationSettings: highSettings);
        } catch (_) {
          final last = await Geolocator.getLastKnownPosition();
          if (last == null) rethrow;
          if (!mounted) return;
          setState(() {
            _gpsLat = last.latitude;
            _gpsLng = last.longitude;
            _capturingGps = false;
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
        _capturingGps = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.tr('locationFetchFailed'))));
      }
      if (mounted) _setCapturingGps(false);
    }
  }

  void _setCapturingGps(bool value) {
    if (!mounted) return;
    setState(() => _capturingGps = value);
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_gpsLat == null || _gpsLng == null) {
      scaffold.showSnackBar(
        SnackBar(content: Text(t.tr('locationRequired')), backgroundColor: Colors.red),
      );
      return;
    }

    final provider = widget.provider;

    final StandaloneTaskVisitResult? result = _isStart
        ? await provider.startStandaloneTaskVisit(
            taskId: widget.task.id,
            gpsLat: _gpsLat,
            gpsLng: _gpsLng,
            photoPaths: _photoPaths,
          )
        : await provider.endStandaloneTaskVisit(
            taskId: widget.task.id,
            gpsLat: _gpsLat,
            gpsLng: _gpsLng,
            photoPaths: _photoPaths,
          );

    if (!mounted) return;

    if (result == null) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(t.tr('errorUpdatingVisit')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (result.success) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(t.tr(_isStart ? 'visitStartedMessage' : 'visitEndedMessage')),
          backgroundColor: const Color(0xFF2F2160),
        ),
      );
      navigator.pop(true);
      return;
    }

    // Someone else on the team already acted, or the checklist isn't
    // complete yet — show why and let the caller re-open with fresh state.
    final message = switch (result.reason) {
      'pending_items' => t.tr('visitEndBlockedPendingItems'),
      _ => _isStart ? t.tr('visitAlreadyStartedByOther') : t.tr('visitAlreadyEndedByOther'),
    };
    scaffold.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orange));
    navigator.pop(false);
  }
}

class _ModernCard extends StatelessWidget {
  final ThemeData theme;
  final Widget child;

  const _ModernCard({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

enum _PhotoPickAction { takePhoto, choosePhoto }
