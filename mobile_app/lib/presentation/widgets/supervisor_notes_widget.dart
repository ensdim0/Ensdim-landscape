import 'package:flutter/material.dart';
import 'package:bustan_amari/domain/entities/supervisor_note.dart';

class SupervisorNotesWidget extends StatefulWidget {
  final String visitId;
  final String contractId;
  final List<SupervisorNote> notes;
  final bool isLoading;
  final Future<void> Function(String content, String visibility) onAddNote;
  final Future<void> Function(String noteId, String content, String visibility)
  onUpdateNote;
  final Future<void> Function(String noteId) onDeleteNote;

  const SupervisorNotesWidget({
    super.key,
    required this.visitId,
    required this.contractId,
    required this.notes,
    required this.isLoading,
    required this.onAddNote,
    required this.onUpdateNote,
    required this.onDeleteNote,
  });

  @override
  State<SupervisorNotesWidget> createState() => _SupervisorNotesWidgetState();
}

class _SupervisorNotesWidgetState extends State<SupervisorNotesWidget> {
  late TextEditingController _newNoteController;
  late TextEditingController _editNoteController;
  String _newVisibility = 'supervisors_only';
  String _editVisibility = 'supervisors_only';
  String? _editingNoteId;
  bool _isAddingNote = false;

  @override
  void initState() {
    super.initState();
    _newNoteController = TextEditingController();
    _editNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _newNoteController.dispose();
    _editNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleAddNote() async {
    if (_newNoteController.text.trim().isEmpty) return;

    try {
      setState(() => _isAddingNote = true);
      await widget.onAddNote(_newNoteController.text.trim(), _newVisibility);
      _newNoteController.clear();
      _newVisibility = 'supervisors_only';
      if (mounted) {
        setState(() => _isAddingNote = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
        setState(() => _isAddingNote = false);
      }
    }
  }

  Future<void> _handleUpdateNote(String noteId) async {
    if (_editNoteController.text.trim().isEmpty) return;

    try {
      setState(() => _isAddingNote = true);
      await widget.onUpdateNote(
        noteId,
        _editNoteController.text.trim(),
        _editVisibility,
      );
      setState(() {
        _editingNoteId = null;
        _isAddingNote = false;
      });
      _editNoteController.clear();
      _editVisibility = 'supervisors_only';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
        setState(() => _isAddingNote = false);
      }
    }
  }

  Future<void> _handleDeleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملاحظة'),
        content: const Text('هل تريد حذف هذه الملاحظة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isAddingNote = true);
        await widget.onDeleteNote(noteId);
        if (mounted) {
          setState(() => _isAddingNote = false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
          setState(() => _isAddingNote = false);
        }
      }
    }
  }

  void _startEdit(SupervisorNote note) {
    setState(() {
      _editingNoteId = note.id;
      _editNoteController.text = note.content;
      _editVisibility = note.visibility;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingNoteId = null;
      _editNoteController.clear();
      _editVisibility = 'supervisors_only';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'ملاحظات المشرف',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // Add new note section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.outline.withValues(alpha: 0.2)
                  : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ملاحظة جديدة',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newNoteController,
                enabled: !widget.isLoading && !_isAddingNote,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: 'أضف ملاحظتك هنا...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(8),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _newVisibility,
                      items: [
                        DropdownMenuItem(
                          value: 'supervisors_only',
                          child: const Text('🔒 للمشرفين فقط'),
                        ),
                        DropdownMenuItem(
                          value: 'all',
                          child: const Text('👥 للمشرفين والعملاء'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _newVisibility = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        _newNoteController.text.trim().isNotEmpty &&
                            !widget.isLoading &&
                            !_isAddingNote
                        ? _handleAddNote
                        : null,
                    child: _isAddingNote
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Existing notes
        if (widget.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${widget.notes.length} ملاحظات',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final note = widget.notes[index];
              final isPublic = note.visibility == 'all';

              if (_editingNoteId == note.id) {
                // Edit mode
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.outline.withValues(alpha: 0.2)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _editNoteController,
                        enabled: !widget.isLoading && !_isAddingNote,
                        maxLines: 3,
                        minLines: 2,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(8),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _editVisibility,
                              items: [
                                DropdownMenuItem(
                                  value: 'supervisors_only',
                                  child: const Text('🔒 للمشرفين فقط'),
                                ),
                                DropdownMenuItem(
                                  value: 'all',
                                  child: const Text('👥 للمشرفين والعملاء'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _editVisibility = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed:
                                _editNoteController.text.trim().isNotEmpty &&
                                    !widget.isLoading &&
                                    !_isAddingNote
                                ? () => _handleUpdateNote(note.id)
                                : null,
                            child: _isAddingNote
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('حفظ'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _cancelEdit,
                            child: const Text('إلغاء'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              } else {
                // View mode
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPublic
                        ? (isDark
                              ? Color.alphaBlend(
                                  Colors.green.withValues(alpha: 0.1),
                                  theme.colorScheme.surface,
                                )
                              : Colors.green[50])
                        : (isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : Colors.grey[50]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPublic
                          ? (isDark
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.green[300]!)
                          : (isDark
                                ? theme.colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  )
                                : Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Chip(
                              label: Text(
                                isPublic ? '👥 للعملاء' : '🔒 للمشرفين',
                                style: theme.textTheme.labelSmall,
                              ),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: isPublic
                                  ? Colors.green[100]
                                  : Colors.grey[200],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateTime.parse(
                              note.createdAt,
                            ).toLocal().toString().split('.').first,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(note.content, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _startEdit(note),
                            icon: const Icon(Icons.edit),
                            label: const Text('تعديل'),
                          ),
                          TextButton.icon(
                            onPressed: () => _handleDeleteNote(note.id),
                            icon: const Icon(Icons.delete),
                            label: const Text('حذف'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ],
    );
  }
}
