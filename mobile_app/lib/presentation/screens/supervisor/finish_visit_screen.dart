// ignore_for_file: non_constant_identifier_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/visit.dart';
import 'package:ensdim_landscape/presentation/providers/supervisor_provider.dart';

class FinishVisitScreen extends StatefulWidget {
  final Visit visit;

  const FinishVisitScreen({super.key, required this.visit});

  @override
  State<FinishVisitScreen> createState() => _FinishVisitScreenState();
}

class _FinishVisitScreenState extends State<FinishVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<String> _mediaPaths = [];
  double? _gpsLat;
  double? _gpsLng;
  bool _capturingGps = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _captureGps();
    });
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: CustomAppBar(
        title: t.tr('finishVisit'),
        backButtonBackgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: Consumer<SupervisorProvider>(
        builder: (context, provider, _) {
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
                      : const Icon(Icons.check_circle_rounded, size: 24),
                  label: Text(
                    t.tr('finishVisit'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            96 + bottomSafeInset,
          ),
          children: [
            _buildVisitHeaderCard(theme, t),
            const SizedBox(height: 16),

            // Summary
            _buildSectionTitle(theme, t.tr('visitSummary')),
            _buildSummaryCard(theme, t),
            const SizedBox(height: 16),

            // Photos
            _buildSectionTitle(theme, t.tr('visitPhotos')),
            _buildPhotosCard(theme, t),
            const SizedBox(height: 16),

            // GPS
            _buildSectionTitle(theme, t.tr('recordGps')),
            _buildGpsCard(theme, t),
          ],
        ),
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

  Widget _buildVisitHeaderCard(ThemeData theme, AppLocalizations t) {
    return _ModernCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.assignment_turned_in_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.tr('visitDetails'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.visit.visitDate.split('T').first,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, AppLocalizations t) {
    return _ModernCard(
      child: TextFormField(
        controller: _summaryController,
        decoration: InputDecoration(
          hintText: t.tr('visitSummaryHint'),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.25,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
        maxLines: 5,
      ),
    );
  }

  Widget _buildPhotosCard(ThemeData theme, AppLocalizations t) {
    return _ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${t.tr('photos')}: ${_mediaPaths.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_mediaPaths.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mediaPaths.asMap().entries.map((entry) {
                final isVideo = _isVideoPath(entry.value);
                return Stack(
                  children: [
                    if (isVideo)
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Icon(
                          Icons.videocam_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else
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
                        onTap: () {
                          setState(() {
                            _mediaPaths.removeAt(entry.key);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _pickMedia,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: _gpsLat != null
                    ? const Color(0xFF30461F)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _gpsLat != null
                      ? t.tr('locationCaptured')
                      : t.tr('captureLocation'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _gpsLat != null
                        ? const Color(0xFF30461F)
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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

  Widget _ModernCard({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
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

  bool _isVideoPath(String path) {
    final normalized = path.split('?').first.toLowerCase();
    return normalized.endsWith('.mp4') ||
        normalized.endsWith('.mov') ||
        normalized.endsWith('.m4v') ||
        normalized.endsWith('.avi') ||
        normalized.endsWith('.webm') ||
        normalized.endsWith('.mkv');
  }

  Future<void> _pickMedia() async {
    try {
      final action = await showModalBottomSheet<_MediaPickAction>(
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
                  onTap: () => Navigator.pop(ctx, _MediaPickAction.takePhoto),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(t.tr('chooseFromGallery')),
                  onTap: () => Navigator.pop(ctx, _MediaPickAction.choosePhoto),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: Text(t.tr('recordVideo')),
                  onTap: () => Navigator.pop(ctx, _MediaPickAction.recordVideo),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_rounded),
                  title: Text(t.tr('chooseVideoFromGallery')),
                  onTap: () => Navigator.pop(ctx, _MediaPickAction.chooseVideo),
                ),
              ],
            ),
          );
        },
      );

      if (action == null) return;

      XFile? picked;

      switch (action) {
        case _MediaPickAction.takePhoto:
          picked = await _imagePicker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          break;
        case _MediaPickAction.choosePhoto:
          picked = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          break;
        case _MediaPickAction.recordVideo:
          picked = await _imagePicker.pickVideo(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
          );
          break;
        case _MediaPickAction.chooseVideo:
          picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
          break;
      }

      if (!mounted || picked == null) return;
      final pickedPath = picked.path;

      setState(() {
        _mediaPaths.add(pickedPath);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.tr('locationFetchFailed'))));
      }
      if (mounted) {
        _setCapturingGps(false);
      }
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

    // Validate form
    if (_formKey.currentState?.validate() != true) return;

    // Validate GPS captured
    if (_gpsLat == null || _gpsLng == null) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(t.tr('locationRequired')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = context.read<SupervisorProvider>();

    final success = await provider.completeVisitWithDetails(
      visitId: widget.visit.id,
      summary: _summaryController.text.trim(),
      photoPaths: _mediaPaths,
      gpsLat: _gpsLat,
      gpsLng: _gpsLng,
    );

    if (!mounted) return;

    if (success) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(t.tr('visitCompletedMessage')),
          backgroundColor: const Color(0xFF30461F),
        ),
      );
      // Pop back to visit detail (or beyond)
      navigator.pop(true);
    } else {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(t.tr('errorUpdatingVisit')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

enum _MediaPickAction { takePhoto, choosePhoto, recordVideo, chooseVideo }
