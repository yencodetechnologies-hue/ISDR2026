import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import 'tick_box.dart';

/// Calendar days (ISO date + short label) between an event's start and end date.
List<({String iso, String label})> eventDays(Map<String, dynamic> event) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final startRaw = DateTime.tryParse(event['eventDate']?.toString() ?? '')?.toLocal();
  if (startRaw == null) return [];
  final endRaw = DateTime.tryParse(event['eventEndDate']?.toString() ?? '')?.toLocal() ?? startRaw;
  var cursor = DateTime(startRaw.year, startRaw.month, startRaw.day);
  final end = DateTime(endRaw.year, endRaw.month, endRaw.day);
  final days = <({String iso, String label})>[];
  var guard = 0;
  while (!cursor.isAfter(end) && guard < 60) {
    final iso =
        '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
    days.add((iso: iso, label: '${cursor.day} ${months[cursor.month - 1]}'));
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    guard++;
  }
  return days;
}

/// Inclusions as `{name, dates}` maps (legacy plain strings are upgraded).
List<Map<String, dynamic>> normalizeInclusions(dynamic raw) {
  final out = <Map<String, dynamic>>[];
  for (final i in (raw as List? ?? [])) {
    if (i is Map) {
      final name = (i['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      out.add({
        'name': name,
        'dates': (i['dates'] as List? ?? []).map((d) => d.toString()).toList(),
      });
    } else {
      final name = i.toString().trim();
      if (name.isNotEmpty) out.add({'name': name, 'dates': <String>[]});
    }
  }
  return out;
}

String paymentModeLabel(String mode) =>
    mode == 'upi' ? 'UPI' : (mode.isEmpty ? '' : mode[0].toUpperCase() + mode.substring(1));

/// Add / edit package sheet: name, rate (or Free toggle), payment mode and a
/// per-day inclusion matrix.
class EventPackageSheet extends StatefulWidget {
  final Map<String, dynamic> event;
  final Map<String, dynamic>? existing;

  const EventPackageSheet({super.key, required this.event, this.existing});

  @override
  State<EventPackageSheet> createState() => _EventPackageSheetState();
}

class _EventPackageSheetState extends State<EventPackageSheet> {
  final _nameController = TextEditingController();
  final _rateController = TextEditingController();
  final _inclusionController = TextEditingController();
  bool _isFree = false;
  List<Map<String, dynamic>> _inclusions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameController.text = p['name']?.toString() ?? '';
      final rate = num.tryParse(p['rate']?.toString() ?? '') ?? 0;
      _isFree = rate == 0;
      _rateController.text = rate == 0 ? '' : rate.toString();
      _inclusions = normalizeInclusions(p['inclusions']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    _inclusionController.dispose();
    super.dispose();
  }

  void _addInclusion() {
    final value = _inclusionController.text.trim();
    if (value.isEmpty) return;
    if (!_inclusions.any((i) => i['name'].toString().toLowerCase() == value.toLowerCase())) {
      setState(() => _inclusions.add({'name': value, 'dates': <String>[]}));
    }
    _inclusionController.clear();
  }

  void _toggleDay(Map<String, dynamic> inc, String iso, bool on) {
    final dates = List<String>.from(inc['dates'] as List);
    if (on) {
      if (!dates.contains(iso)) dates.add(iso);
    } else {
      dates.remove(iso);
    }
    setState(() => inc['dates'] = dates);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Package name is required');
      return;
    }
    num rate = 0;
    if (!_isFree) {
      if (_rateController.text.trim().isEmpty) {
        setState(() => _error = 'Enter a rate or turn on Free');
        return;
      }
      final parsed = num.tryParse(_rateController.text.trim());
      if (parsed == null || parsed < 0) {
        setState(() => _error = 'Enter a valid rate');
        return;
      }
      rate = parsed;
    }
    Navigator.pop(context, {
      if (widget.existing?['id'] != null) 'id': widget.existing!['id'],
      'name': name,
      'rate': rate,
      'paymentMode': '',
      'inclusions': _inclusions,
    });
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
      );

  Widget _section(String text, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
            ],
            Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ],
        ),
      );

  Future<void> _editInclusion(Map<String, dynamic> inc) async {
    final controller = TextEditingController(text: inc['name']?.toString() ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Inclusion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Inclusion name',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(ctx, trimmed);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() => inc['name'] = newName);
    }
  }

  Widget _dayChip(Map<String, dynamic> inc, ({String iso, String label}) d, bool on) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _toggleDay(inc, d.iso, !on),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            TickBox(value: on, onChanged: (v) => _toggleDay(inc, d.iso, v)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                d.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: on ? const Color(0xFF166534) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inclusionCard(Map<String, dynamic> inc, List<({String iso, String label})> days) {
    final dates = (inc['dates'] as List).map((d) => d.toString()).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.restaurant_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inc['name'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                    if (days.isNotEmpty)
                      Text(
                        '${days.where((d) => dates.contains(d.iso)).length} of ${days.length} days',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit name',
                onPressed: () => _editInclusion(inc),
                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2563EB)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
                onPressed: () => setState(() => _inclusions.remove(inc)),
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.errorColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (days.isEmpty)
            const Text('Set the event dates to pick days.', style: TextStyle(fontSize: 12, color: Colors.black45))
          else
            LayoutBuilder(
              builder: (context, c) {
                const gap = 6.0;
                const cols = 3;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: days
                      .map((d) => SizedBox(width: w, child: _dayChip(inc, d, dates.contains(d.iso))))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = eventDays(widget.event);
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(editing ? 'Edit Package' : 'Add Package',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.errorColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    _section('Details', icon: Icons.inventory_2_outlined),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: _isFree ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isFree ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.card_giftcard_rounded,
                              size: 20, color: _isFree ? TickBox.green : const Color(0xFF94A3B8)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Free package', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Switch(
                            value: _isFree,
                            activeThumbColor: TickBox.green,
                            onChanged: (v) => setState(() {
                              _isFree = v;
                              if (v) {
                                _rateController.clear();
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                    if (!_isFree) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _rateController,
                        keyboardType: TextInputType.number,
                        decoration: _dec('Rate (₹) *'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(controller: _nameController, decoration: _dec('Package name *')),
                    const SizedBox(height: 18),
                    _section('Inclusions', icon: Icons.checklist_rounded),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inclusionController,
                            onSubmitted: (_) => _addInclusion(),
                            decoration: _dec('Add inclusion', hint: 'e.g. Lunch'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _addInclusion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Icon(Icons.add_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_inclusions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text('No inclusions yet. Add one above, then tick the days it applies to.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      )
                    else
                      ..._inclusions.map((inc) => _inclusionCard(inc, days)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(editing ? 'Save Package' : 'Add Package'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
