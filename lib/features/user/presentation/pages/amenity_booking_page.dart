import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/models/amenity_slot_model.dart';
import '../../../../core/services/api_service.dart';

class AmenityBookingPage extends StatefulWidget {
  final String amenityId;
  final String amenityName;

  const AmenityBookingPage({
    super.key,
    required this.amenityId,
    required this.amenityName,
  });

  @override
  State<AmenityBookingPage> createState() => _AmenityBookingPageState();
}

class _AmenityBookingPageState extends State<AmenityBookingPage> {
  final ApiService _apiService = ApiService();
  DateTime _selectedDate = DateTime.now();
  List<AmenitySlotModel> _slots = [];
  final Set<String> _selectedSlotStarts = {};
  bool _isLoading = false;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSlots() async {
    setState(() => _isLoading = true);
    _selectedSlotStarts.clear();
    try {
      final response = await _apiService.getAmenitySlots(widget.amenityId, _dateStr(_selectedDate));
      if (mounted && response['success'] == true) {
        setState(() {
          _slots = List<AmenitySlotModel>.from(response['slots'] ?? []);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadSlots();
    }
  }

  Future<void> _bookSelected() async {
    if (_selectedSlotStarts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one slot')),
      );
      return;
    }
    setState(() => _isBooking = true);
    try {
      final response = await _apiService.bookAmenitySlots(
        widget.amenityId,
        _dateStr(_selectedDate),
        _selectedSlotStarts.toList(),
      );
      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Slots booked successfully')),
          );
          _selectedSlotStarts.clear();
          _loadSlots();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to book'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.amenityName),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_slots.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No slots available for this date.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _slots.length,
                itemBuilder: (context, index) {
                  final slot = _slots[index];
                  final canSelect = slot.available > 0;
                  final selected = _selectedSlotStarts.contains(slot.slotStart);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: canSelect
                          ? (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedSlotStarts.add(slot.slotStart);
                                } else {
                                  _selectedSlotStarts.remove(slot.slotStart);
                                }
                              });
                            }
                          : null,
                      title: Text(
                        '${slot.slotStart} – ${slot.slotEnd}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: canSelect ? AppTheme.textColor : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        '${slot.available} available',
                        style: TextStyle(
                          fontSize: 12,
                          color: canSelect ? AppTheme.secondaryColor : Colors.grey,
                        ),
                      ),
                      activeColor: AppTheme.primaryColor,
                    ),
                  );
                },
              ),
            ),
          if (!_isLoading && _slots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: BrandGradientCtaButton(
                height: 52,
                isLoading: _isBooking,
                icon: Icons.event_available_rounded,
                label: 'Book ${_selectedSlotStarts.length} slot(s)',
                onPressed: (_isBooking || _selectedSlotStarts.isEmpty) ? null : _bookSelected,
              ),
            ),
        ],
      ),
    );
  }
}
