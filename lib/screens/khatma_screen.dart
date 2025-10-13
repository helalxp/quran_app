import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/khatma.dart';
import '../utils/haptic_utils.dart';
import '../services/khatma_manager.dart';
import '../services/analytics_service.dart';
import 'khatma_detail_screen.dart';

class KhatmaScreen extends StatefulWidget {
  const KhatmaScreen({super.key});

  @override
  State<KhatmaScreen> createState() => _KhatmaScreenState();
}

class _KhatmaScreenState extends State<KhatmaScreen> {
  List<Khatma> _khatmas = [];
  bool _isLoading = true;
  final _khatmaManager = KhatmaManager();

  @override
  void initState() {
    super.initState();
    _loadKhatmas();

    // Listen for errors from KhatmaManager
    _khatmaManager.errorNotifier.addListener(_onError);
  }

  @override
  void dispose() {
    _khatmaManager.errorNotifier.removeListener(_onError);
    super.dispose();
  }

  void _onError() {
    final error = _khatmaManager.errorNotifier.value;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'حسناً',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _loadKhatmas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final khatmasJson = prefs.getString('khatmas');

      if (khatmasJson != null) {
        final List<dynamic> decoded = json.decode(khatmasJson);
        setState(() {
          _khatmas = decoded.map((json) => Khatma.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading khatmas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveKhatmas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('khatmas', json.encode(_khatmas.map((k) => k.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving khatmas: $e');
    }
  }

  void _showCreateKhatmaSheet({Khatma? editingKhatma, int? editingIndex}) {
    HapticUtils.dialogOpen();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _KhatmaCreationSheet(
        existingKhatma: editingKhatma,
        onKhatmaCreated: (khatma) {
          setState(() {
            if (editingIndex != null) {
              // Edit mode
              _khatmas[editingIndex] = khatma;
            } else {
              // Create mode
              _khatmas.add(khatma);
            }
          });
          _saveKhatmas();

          // Schedule/update notification
          final khatmaManager = KhatmaManager();
          if (editingIndex != null) {
            khatmaManager.updateKhatma(khatma.id, khatma);
          } else {
            khatmaManager.addKhatma(khatma);
            // Log analytics for new khatma creation
            final duration = khatma.mode == KhatmaMode.endDate && khatma.endDate != null
                ? khatma.endDate!.difference(DateTime.now()).inDays
                : khatma.mode == KhatmaMode.pagesPerDay && khatma.pagesPerDay != null
                    ? (khatma.totalPages / khatma.pagesPerDay!).ceil()
                    : 0;
            AnalyticsService.logKhatmaCreated(
              khatma.name,
              khatma.pagesPerDay ?? 0,
              duration,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            HapticUtils.navigation();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_outlined),
        ),
        title: const Text(
          "الختمة",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Uthmanic',
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: _khatmas.isNotEmpty
            ? [
                IconButton(
                  onPressed: _showCreateKhatmaSheet,
                  icon: const Icon(Icons.add),
                  tooltip: 'إضافة ختمة جديدة',
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _khatmas.isEmpty
              ? _buildEmptyState()
              : _buildKhatmasList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showCreateKhatmaSheet,
                customBorder: const CircleBorder(),
                child: Icon(
                  Icons.add,
                  size: 60,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "ابدأ ختمة جديدة",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Uthmanic',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "اضغط على الزر لإنشاء ختمتك الأولى",
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKhatmasList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _khatmas.length,
      itemBuilder: (context, index) {
        final khatma = _khatmas[index];
        return Dismissible(
          key: Key(khatma.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text(
                  'حذف الختمة',
                  style: TextStyle(fontFamily: 'Uthmanic'),
                  textDirection: TextDirection.rtl,
                ),
                content: Text(
                  'هل تريد حذف "${khatma.name}"؟\nسيتم حذف جميع البيانات والتقدم.',
                  textDirection: TextDirection.rtl,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            HapticUtils.heavyImpact();
            final deletedKhatma = _khatmas[index];
            final errorColor = Theme.of(context).colorScheme.error;
            final scaffoldMessenger = ScaffoldMessenger.of(context);

            setState(() {
              _khatmas.removeAt(index);
            });
            await _saveKhatmas();

            // Log analytics for deletion
            final progress = (deletedKhatma.pagesRead / deletedKhatma.totalPages * 100).round();
            await AnalyticsService.logKhatmaDeleted(deletedKhatma.name, progress);

            // Cancel notifications
            final khatmaManager = KhatmaManager();
            await khatmaManager.deleteKhatma(deletedKhatma.id);

            if (!mounted) return;

            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'تم حذف ${deletedKhatma.name}',
                  textDirection: TextDirection.rtl,
                ),
                action: SnackBarAction(
                  label: 'تراجع',
                  onPressed: () {
                    setState(() {
                      _khatmas.insert(index, deletedKhatma);
                    });
                    _saveKhatmas();
                    khatmaManager.addKhatma(deletedKhatma);
                  },
                ),
                backgroundColor: errorColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 32,
            ),
          ),
          child: _KhatmaCard(
            khatma: khatma,
            onTap: () async {
              HapticUtils.selectionClick();
              final result = await Navigator.push<dynamic>(
                context,
                MaterialPageRoute(
                  builder: (context) => KhatmaDetailScreen(
                    khatma: khatma,
                    onKhatmaUpdated: (updated) {
                      setState(() {
                        _khatmas[index] = updated;
                      });
                      _saveKhatmas();
                    },
                  ),
                ),
              );

              // Handle return from detail screen
              if (result != null) {
                if (result is Map && result['action'] == 'edit') {
                  // Open edit sheet
                  _showCreateKhatmaSheet(editingKhatma: result['khatma'], editingIndex: index);
                } else if (result is Khatma) {
                  setState(() {
                    _khatmas[index] = result;
                  });
                  _saveKhatmas();
                }
              }
            },
            onLongPress: () {
              HapticUtils.heavyImpact();
              _showCreateKhatmaSheet(editingKhatma: khatma, editingIndex: index);
            },
          ),
        );
      },
    );
  }
}

// Khatma Card Widget
class _KhatmaCard extends StatelessWidget {
  final Khatma khatma;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _KhatmaCard({
    required this.khatma,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final progress = khatma.pagesRead / khatma.totalPages;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        khatma.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${khatma.pagesRead} / ${khatma.totalPages}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress bar
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoChip(
                      context,
                      Icons.calendar_today,
                      _getModeText(),
                    ),
                    _buildInfoChip(
                      context,
                      Icons.book,
                      'من الجزء ${khatma.startJuz} إلى ${khatma.endJuz}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  String _getModeText() {
    switch (khatma.mode) {
      case KhatmaMode.endDate:
        if (khatma.endDate != null) {
          final days = khatma.endDate!.difference(DateTime.now()).inDays;
          return 'باقي $days يوم';
        }
        return 'تاريخ الانتهاء';
      case KhatmaMode.pagesPerDay:
        return '${khatma.pagesPerDay} صفحة/يوم';
      case KhatmaMode.tracking:
        return 'متابعة فقط';
    }
  }
}

// Khatma Creation Sheet
class _KhatmaCreationSheet extends StatefulWidget {
  final Function(Khatma) onKhatmaCreated;
  final Khatma? existingKhatma;

  const _KhatmaCreationSheet({
    required this.onKhatmaCreated,
    this.existingKhatma,
  });

  @override
  State<_KhatmaCreationSheet> createState() => _KhatmaCreationSheetState();
}

class _KhatmaCreationSheetState extends State<_KhatmaCreationSheet> {
  final _nameController = TextEditingController();
  KhatmaMode _selectedMode = KhatmaMode.endDate;
  int _startJuz = 1;
  int _endJuz = 30;
  DateTime? _selectedEndDate;
  int? _selectedPagesPerDay;
  TimeOfDay? _selectedNotificationTime;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if editing
    if (widget.existingKhatma != null) {
      final khatma = widget.existingKhatma!;
      _nameController.text = khatma.name;
      _selectedMode = khatma.mode;
      _startJuz = khatma.startJuz;
      _endJuz = khatma.endJuz;
      _selectedEndDate = khatma.endDate;
      _selectedPagesPerDay = khatma.pagesPerDay;

      // Parse notification time
      if (khatma.notificationTime != null) {
        final parts = khatma.notificationTime!.split(':');
        if (parts.length == 2) {
          _selectedNotificationTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _generateKhatmaName() {
    // Auto-generate name based on settings if user didn't provide one
    if (_selectedMode == KhatmaMode.tracking) {
      return 'متابعة القراءة';
    }

    // Generate name based on Juz range
    if (_startJuz == _endJuz) {
      return 'ختمة الجزء $_startJuz';
    } else if (_startJuz == 1 && _endJuz == 30) {
      return 'ختمة كاملة';
    } else {
      return 'ختمة من الجزء $_startJuz إلى $_endJuz';
    }
  }

  void _createKhatma() {
    // Auto-generate name if empty
    final khatmaName = _nameController.text.trim().isEmpty
        ? _generateKhatmaName()
        : _nameController.text.trim();

    // Validate based on mode
    if (_selectedMode == KhatmaMode.endDate && _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار تاريخ الانتهاء', textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedMode == KhatmaMode.pagesPerDay && _selectedPagesPerDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال عدد الصفحات في اليوم', textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final khatma = Khatma(
      id: widget.existingKhatma?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: khatmaName,
      mode: _selectedMode,
      startJuz: _startJuz,
      endJuz: _endJuz,
      createdAt: widget.existingKhatma?.createdAt ?? DateTime.now(),
      endDate: _selectedEndDate,
      pagesPerDay: _selectedPagesPerDay,
      notificationTime: _selectedNotificationTime != null
          ? '${_selectedNotificationTime!.hour.toString().padLeft(2, '0')}:${_selectedNotificationTime!.minute.toString().padLeft(2, '0')}'
          : null,
      dailyProgress: widget.existingKhatma?.dailyProgress ?? {},
      allPagesRead: widget.existingKhatma?.allPagesRead ?? {}, // ✅ Preserve reading history
    );

    widget.onKhatmaCreated(khatma);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  widget.existingKhatma != null ? "تعديل الختمة" : "إنشاء ختمة جديدة",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Uthmanic',
                  ),
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Name field
                      const Text(
                        'اسم الختمة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'اختياري - سيتم إنشاء اسم تلقائياً',
                          hintTextDirection: TextDirection.rtl,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Mode selector
                      const Text(
                        'نوع الختمة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      _buildModeSelector(),
                      const SizedBox(height: 24),

                      // Juz selectors
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'من الجزء',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Uthmanic',
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                const SizedBox(height: 8),
                                _buildJuzSelector(
                                  value: _startJuz,
                                  onChanged: (value) {
                                    setState(() {
                                      _startJuz = value;
                                      if (_startJuz > _endJuz) {
                                        _endJuz = _startJuz;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'إلى الجزء',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Uthmanic',
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                const SizedBox(height: 8),
                                _buildJuzSelector(
                                  value: _endJuz,
                                  onChanged: (value) {
                                    setState(() {
                                      _endJuz = value;
                                      if (_endJuz < _startJuz) {
                                        _startJuz = _endJuz;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Mode-specific fields
                      if (_selectedMode == KhatmaMode.endDate) ...[
                        _buildEndDateField(),
                        const SizedBox(height: 24),
                      ],
                      if (_selectedMode == KhatmaMode.pagesPerDay) ...[
                        _buildPagesPerDayField(),
                        const SizedBox(height: 24),
                      ],

                      // Notification time
                      const Text(
                        'وقت التذكير اليومي',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      _buildNotificationTimePicker(),
                    ],
                  ),
                ),
              ),

              // Create button
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _createKhatma,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            widget.existingKhatma != null ? "حفظ التغييرات" : "إنشاء الختمة",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Uthmanic',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Beautiful mode selector with gradient cards
  Widget _buildModeSelector() {
    return Column(
      children: [
        _buildModeOption(
          mode: KhatmaMode.endDate,
          icon: Icons.event,
          title: 'تحديد تاريخ الانتهاء',
          subtitle: 'نحدد لك عدد الصفحات يومياً',
        ),
        const SizedBox(height: 12),
        _buildModeOption(
          mode: KhatmaMode.pagesPerDay,
          icon: Icons.auto_stories,
          title: 'عدد الصفحات يومياً',
          subtitle: 'نحسب لك موعد الانتهاء',
        ),
        const SizedBox(height: 12),
        _buildModeOption(
          mode: KhatmaMode.tracking,
          icon: Icons.track_changes,
          title: 'متابعة فقط',
          subtitle: 'تتبع تقدمك بدون أهداف',
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required KhatmaMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMode == mode;

    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              )
            : null,
        color: isSelected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Colors.transparent
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticUtils.selectionClick();
            setState(() {
              _selectedMode = mode;
              // Reset mode-specific fields when changing mode
              if (mode != KhatmaMode.endDate) _selectedEndDate = null;
              if (mode != KhatmaMode.pagesPerDay) _selectedPagesPerDay = null;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : null,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Juz selector with beautiful dropdown
  Widget _buildJuzSelector({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return InkWell(
      onTap: () {
        HapticUtils.selectionClick();
        _showJuzPicker(value, onChanged);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الجزء $value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'Uthmanic',
              ),
              textDirection: TextDirection.rtl,
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showJuzPicker(int currentValue, ValueChanged<int> onChanged) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'اختر الجزء',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Uthmanic',
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: 30,
                itemBuilder: (context, index) {
                  final juzNumber = index + 1;
                  final isSelected = juzNumber == currentValue;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            )
                          : null,
                      color: isSelected ? null : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticUtils.selectionClick();
                          onChanged(juzNumber);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الجزء $juzNumber',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : null,
                                  fontFamily: 'Uthmanic',
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                              if (isSelected)
                                const Icon(Icons.check, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // End date field
  Widget _buildEndDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'تاريخ الانتهاء المطلوب',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Uthmanic',
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            HapticUtils.selectionClick();
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedEndDate ?? DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() {
                _selectedEndDate = date;
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedEndDate != null
                      ? '${_selectedEndDate!.year}-${_selectedEndDate!.month.toString().padLeft(2, '0')}-${_selectedEndDate!.day.toString().padLeft(2, '0')}'
                      : 'اختر التاريخ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontFamily: 'Uthmanic',
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Icon(
                  Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Pages per day field
  Widget _buildPagesPerDayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'عدد الصفحات في اليوم',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Uthmanic',
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              IconButton(
                onPressed: () {
                  HapticUtils.selectionClick();
                  setState(() {
                    _selectedPagesPerDay = (_selectedPagesPerDay ?? 5) + 1;
                  });
                },
                icon: Icon(
                  Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_selectedPagesPerDay ?? 5} صفحة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontFamily: 'Uthmanic',
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticUtils.selectionClick();
                  setState(() {
                    final current = _selectedPagesPerDay ?? 5;
                    if (current > 1) {
                      _selectedPagesPerDay = current - 1;
                    }
                  });
                },
                icon: Icon(
                  Icons.remove_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Notification time picker
  Widget _buildNotificationTimePicker() {
    return InkWell(
      onTap: () async {
        HapticUtils.selectionClick();
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedNotificationTime ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (time != null) {
          setState(() {
            _selectedNotificationTime = time;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedNotificationTime != null
                  ? '${_selectedNotificationTime!.hour.toString().padLeft(2, '0')}:${_selectedNotificationTime!.minute.toString().padLeft(2, '0')}'
                  : 'اختر الوقت (اختياري)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'Uthmanic',
              ),
              textDirection: TextDirection.rtl,
            ),
            Icon(
              Icons.access_time,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
