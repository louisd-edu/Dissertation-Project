import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class TakeDoseSheet extends StatefulWidget {
  final ScheduledDose scheduledDose;
  const TakeDoseSheet({super.key, required this.scheduledDose});

  @override
  State<TakeDoseSheet> createState() => _TakeDoseSheetState();
}

class _TakeDoseSheetState extends State<TakeDoseSheet> {
  File? _capturedMedia;
  bool _isVideo = false;
  bool _isSaving = false;

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file != null) {
      setState(() {
        _capturedMedia = File(file.path);
        _isVideo = false;
      });
    }
  }

  Future<void> _captureVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.camera);
    if (file != null) {
      setState(() {
        _capturedMedia = File(file.path);
        _isVideo = true;
      });
    }
  }

  Future<void> _takeDose() async {
    setState(() => _isSaving = true);
    final state = context.read<AppState>();
    final existingDose = widget.scheduledDose.dose;
    final success = existingDose != null && existingDose.id.isNotEmpty
        ? await state.updateDose(
            existingDose.id,
            DoseStatus.taken,
            evidenceFile: _capturedMedia,
            planId: widget.scheduledDose.plan.id,
            scheduledFor: widget.scheduledDose.scheduledTime,
          )
        : await state.logDose(
            widget.scheduledDose.plan.id,
            DoseStatus.taken,
            scheduledFor: widget.scheduledDose.scheduledTime,
            evidenceFile: _capturedMedia,
          );
    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.scheduledDose.plan.name} marked as taken!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not save this dose. Please try again.'),
            backgroundColor: AppTheme.missedRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _skipDose() async {
    setState(() => _isSaving = true);
    final state = context.read<AppState>();
    final existingDose = widget.scheduledDose.dose;
    final scheduledAt = widget.scheduledDose.scheduledTime;

    bool success = false;
    if (existingDose != null && existingDose.id.isNotEmpty) {
      success = await state.updateDose(
        existingDose.id,
        DoseStatus.skipped,
        takenAt: scheduledAt,
        planId: widget.scheduledDose.plan.id,
        scheduledFor: scheduledAt,
      );
    }

    if (!success) {
      await state.logDose(
        widget.scheduledDose.plan.id,
        DoseStatus.skipped,
        scheduledFor: scheduledAt,
        takenAt: scheduledAt,
      );
      success = true;
    }

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not save this dose. Please try again.'),
          backgroundColor: AppTheme.missedRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.scheduledDose.plan;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Medication Reminder label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Medication Reminder',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Med name + dosage
          Text(
            plan.name,
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            plan.dosageLabel,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // camera preview
          _capturedMedia != null
              ? ClipRRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _isVideo
                      ? const SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: Center(child: Icon(Icons.videocam, size: 48)),
                        )
                      : Image.file(_capturedMedia!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover),
                )
              : GestureDetector(
                  onTap: _captureImage,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              size: 40, color: AppTheme.textLight),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to record a photo.\nPress and hold to record video.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

          if (_capturedMedia == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _captureImage,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Photo'),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _captureVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _skipDose,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Skip',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _takeDose,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Take'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore camel_case_types
class ClipRRRect extends StatelessWidget {
  final BorderRadius borderRadius;
  final Widget child;
  const ClipRRRect(
      {super.key, required this.borderRadius, required this.child});

  @override
  Widget build(BuildContext context) =>
      ClipRRect(borderRadius: borderRadius, child: child);
}
