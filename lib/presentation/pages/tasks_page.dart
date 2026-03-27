import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/task.dart';
import '../blocs/task/task_bloc.dart';
import '../blocs/user/user_cubit.dart';
import '../blocs/voice/voice_cubit.dart';
import '../widgets/task_card_widget.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  void _loadTasks() {
    final userState = context.read<UserCubit>().state;
    if (userState is UserAuthenticated) {
      context.read<TaskBloc>().add(LoadTasksEvent(userState.user.id));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kullanıcı değişince görevleri anında yenile (gizlilik)
    return BlocListener<UserCubit, UserState>(
      listener: (context, state) {
        if (state is UserAuthenticated) {
          context.read<TaskBloc>().add(LoadTasksEvent(state.user.id));
        } else if (state is UsersLoaded) {
          // Kullanıcı çıkış yaptı — görev listesini temizle
          context.read<TaskBloc>().add(const LoadTasksEvent(''));
        }
      },
      child: SafeArea(
        child: Column(
          children: [
            _TasksHeader(searchController: _searchController),
            _FilterTabs(controller: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _TaskList(showCompleted: false),
                  _TaskList(showCompleted: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _TasksHeader extends StatelessWidget {
  final TextEditingController searchController;
  const _TasksHeader({required this.searchController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Görevlerim',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              FloatingActionButton.small(
                heroTag: 'add_task',
                onPressed: () => _showAddTaskSheet(context),
                backgroundColor: AppTheme.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Görev ara...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textDisabled),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppTheme.textDisabled),
                      onPressed: () {
                        searchController.clear();
                      },
                    )
                  : null,
            ),
            onChanged: (q) {
              final userState = context.read<UserCubit>().state;
              if (userState is UserAuthenticated) {
                context.read<TaskBloc>().add(
                      SearchTasksEvent(userId: userState.user.id, query: q),
                    );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskSheet(BuildContext context) async {
    final userState = context.read<UserCubit>().state;
    final userId = userState is UserAuthenticated ? userState.user.id : '';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görev eklemek için önce bir profil seçin.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<TaskBloc>(),
        child: _AddTaskSheet(userId: userId),
      ),
    );
  }
}

// ── Filtre Sekmeleri ──────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  final TabController controller;
  const _FilterTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'Aktif'),
          Tab(text: 'Tamamlanan'),
        ],
      ),
    );
  }
}

// ── Görev Listesi ─────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final bool showCompleted;
  const _TaskList({required this.showCompleted});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state is TaskLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (state is TaskLoaded) {
          final tasks = state.filteredTasks
              .where((t) => t.isCompleted == showCompleted)
              .toList();

          if (tasks.isEmpty) {
            final neverAdded = state.tasks.isEmpty;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    neverAdded
                        ? Icons.add_task
                        : showCompleted
                            ? Icons.task_alt
                            : Icons.playlist_add_check_circle_outlined,
                    size: 56,
                    color: neverAdded
                        ? AppTheme.primary
                        : AppTheme.textDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    neverAdded
                        ? 'Henüz görev eklenmedi.'
                        : showCompleted
                            ? 'Henüz tamamlanan görev yok.'
                            : 'Harika! Tüm görevler tamamlandı.',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (neverAdded) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Sağ üstteki + butonunu kullanın.',
                      style: TextStyle(
                        color: AppTheme.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 100),
            itemCount: tasks.length,
            itemBuilder: (ctx, i) => TaskCardWidget(
              task: tasks[i],
              onToggle: () =>
                  context.read<TaskBloc>().add(ToggleTaskEvent(tasks[i].id)),
              onDelete: () =>
                  context.read<TaskBloc>().add(RemoveTaskEvent(tasks[i].id)),
              onSpeak: () => _speakTask(context, tasks[i]),
            ),
          );
        }

        if (state is TaskError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: AppTheme.error),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  static void _speakTask(BuildContext context, Task task) {
    final voiceCubit = context.read<VoiceCubit>();
    final buffer = StringBuffer(task.title);
    if (task.description != null && task.description!.isNotEmpty) {
      buffer.write('. ${task.description}');
    }
    buffer.write('. Öncelik: ${task.priority.label}');
    if (task.dueDate != null) {
      final formatted = '${task.dueDate!.day} ${_monthName(task.dueDate!.month)}';
      buffer.write('. Son tarih: $formatted');
    }
    if (task.isCompleted) buffer.write('. Tamamlandı.');
    voiceCubit.speak(buffer.toString());
  }

  static String _monthName(int month) {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return months[month];
  }
}

// ── Görev Ekleme Bottom Sheet ─────────────────────────────────────────────

class _AddTaskSheet extends StatefulWidget {
  final String userId;
  const _AddTaskSheet({required this.userId});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  TaskPriority _priority = TaskPriority.medium;
  TaskCategory _category = TaskCategory.general;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Yeni Görev',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Görev başlığı *',
                  prefixIcon: Icon(Icons.task_alt, color: AppTheme.primary),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Başlık zorunludur.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (isteğe bağlı)',
                  prefixIcon: Icon(Icons.notes, color: AppTheme.textDisabled),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel(label: 'Öncelik'),
              const SizedBox(height: 8),
              _PrioritySelector(
                selected: _priority,
                onChanged: (p) => setState(() => _priority = p),
              ),
              const SizedBox(height: 16),
              const _SectionLabel(label: 'Kategori'),
              const SizedBox(height: 8),
              _CategorySelector(
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 16),
              const _SectionLabel(label: 'Son Tarih'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppTheme.primary,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (date != null) {
                    setState(() => _dueDate = date);
                    if (context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppTheme.primary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (time != null) setState(() => _dueTime = time);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: _dueDate != null
                            ? AppTheme.primary
                            : AppTheme.textDisabled,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _dueDate != null
                            ? _dueTime != null
                                ? '${DateFormat('d MMMM yyyy', 'tr_TR').format(_dueDate!)}  ${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}'
                                : DateFormat('d MMMM yyyy', 'tr_TR').format(_dueDate!)
                            : 'Tarih ve saat seç',
                        style: TextStyle(
                          color: _dueDate != null
                              ? AppTheme.textPrimary
                              : AppTheme.textDisabled,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Görev Ekle'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.userId.isEmpty) return;

    // Saat secildiyse dueDate'e saat bilgisini ekle
    DateTime? finalDueDate;
    if (_dueDate != null) {
      if (_dueTime != null) {
        finalDueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _dueTime!.hour,
          _dueTime!.minute,
        );
      } else {
        finalDueDate = _dueDate;
      }
    }

    final task = Task(
      id: const Uuid().v4(),
      userId: widget.userId,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      createdAt: DateTime.now(),
      dueDate: finalDueDate,
      priority: _priority,
      category: _category,
    );

    context.read<TaskBloc>().add(AddTaskEvent(task));
    Navigator.pop(context);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final TaskPriority selected;
  final ValueChanged<TaskPriority> onChanged;
  const _PrioritySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: TaskPriority.values.map((p) {
        final isSelected = selected == p;
        final color = _color(p);
        return FilterChip(
          label: Text(p.label),
          selected: isSelected,
          onSelected: (_) => onChanged(p),
          backgroundColor: AppTheme.surfaceVariant,
          selectedColor: color.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: isSelected ? color : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          checkmarkColor: color,
          side: BorderSide(
            color: isSelected ? color : AppTheme.dividerColor,
          ),
        );
      }).toList(),
    );
  }

  Color _color(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent:
        return AppTheme.error;
      case TaskPriority.high:
        return AppTheme.warning;
      case TaskPriority.medium:
        return AppTheme.primary;
      case TaskPriority.low:
        return AppTheme.textSecondary;
    }
  }
}

class _CategorySelector extends StatelessWidget {
  final TaskCategory selected;
  final ValueChanged<TaskCategory> onChanged;
  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: TaskCategory.values.map((c) {
          final isSelected = selected == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c.label),
              selected: isSelected,
              onSelected: (_) => onChanged(c),
              backgroundColor: AppTheme.surfaceVariant,
              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              checkmarkColor: AppTheme.primary,
              side: BorderSide(
                color: isSelected ? AppTheme.primary : AppTheme.dividerColor,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
