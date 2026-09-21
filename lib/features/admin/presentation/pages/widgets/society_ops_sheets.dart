import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Mongo/API id from a society-ops list item.
String? societyOpsItemId(Map<String, dynamic> m) {
  final v = m['_id'] ?? m['id'];
  return v?.toString();
}

DateTime? societyOpsParseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

InputDecoration _sheetInputDecoration({
  required String label,
  String? hint,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
    hintStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF94A3B8)),
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)) : null,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFEF4444)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
    ),
  );
}

// --- Furniture Sheet ---

class SocietyOpsFurnitureSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const SocietyOpsFurnitureSheet({super.key, this.existing});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? existing,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SocietyOpsFurnitureSheet(existing: existing),
      ),
    );
  }

  @override
  State<SocietyOpsFurnitureSheet> createState() => _SocietyOpsFurnitureSheetState();
}

class _SocietyOpsFurnitureSheetState extends State<SocietyOpsFurnitureSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _itemType;
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _avail;
  late final TextEditingController _location;
  late String _status;
  late final TextEditingController _notes;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _itemType = (e?['itemType'] as String?) ?? 'chair';
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _qty = TextEditingController(text: '${e?['quantity'] ?? 0}');
    _avail = TextEditingController(text: '${e?['availableQuantity'] ?? 0}');
    _location = TextEditingController(text: e?['location']?.toString() ?? '');
    _status = (e?['status'] as String?) ?? 'available';
    _notes = TextEditingController(text: e?['notes']?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _avail.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final q = int.tryParse(_qty.text.trim()) ?? 0;
    final a = int.tryParse(_avail.text.trim()) ?? 0;
    Navigator.pop(context, {
      'itemType': _itemType,
      'name': _name.text.trim(),
      'quantity': q,
      'availableQuantity': a,
      'location': _location.text.trim(),
      'status': _status,
      'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: _SocietyOpsSheetChrome(
        headerColor: const Color(0xFF13275D),
        icon: Icons.chair_rounded,
        title: _isEdit ? 'Edit Chairs / Tables' : 'Add Chairs / Tables',
        onSubmit: _submit,
        submitLabel: _isEdit ? 'Save Changes' : 'Add Furniture',
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _itemType,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Item type', prefixIcon: Icons.category_outlined),
                items: [
                  DropdownMenuItem(value: 'chair', child: Text('Chair', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'table', child: Text('Table', style: GoogleFonts.inter())),
                ],
                onChanged: (v) => setState(() => _itemType = v ?? 'chair'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Name', hint: 'e.g. Banquet Chairs', prefixIcon: Icons.edit_note_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qty,
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      decoration: _sheetInputDecoration(label: 'Quantity', prefixIcon: Icons.pin_outlined),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n < 0) return 'Valid number ≥ 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _avail,
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      decoration: _sheetInputDecoration(label: 'Available qty', prefixIcon: Icons.check_circle_outline_rounded),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n < 0) return 'Valid number ≥ 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Location', hint: 'e.g. Clubhouse Store Room', prefixIcon: Icons.place_outlined),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Status', prefixIcon: Icons.info_outline_rounded),
                items: [
                  DropdownMenuItem(value: 'available', child: Text('Available', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'reserved', child: Text('Reserved', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance', style: GoogleFonts.inter())),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'available'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Notes', hint: 'Additional details or conditions', prefixIcon: Icons.notes_rounded),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Lift Service Sheet ---

class SocietyOpsLiftServiceSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const SocietyOpsLiftServiceSheet({super.key, this.existing});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? existing,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SocietyOpsLiftServiceSheet(existing: existing),
      ),
    );
  }

  @override
  State<SocietyOpsLiftServiceSheet> createState() => _SocietyOpsLiftServiceSheetState();
}

class _SocietyOpsLiftServiceSheetState extends State<SocietyOpsLiftServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  static final _dateFormat = DateFormat('dd MMM yyyy');
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _vendor;
  late final TextEditingController _cost;
  late String _status;
  late DateTime _serviceDate;
  DateTime? _nextServiceDate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?['title']?.toString() ?? '');
    _description = TextEditingController(text: e?['description']?.toString() ?? '');
    _vendor = TextEditingController(text: e?['vendorName']?.toString() ?? '');
    _cost = TextEditingController(text: e != null ? '${e['cost'] ?? 0}' : '0');
    _status = (e?['status'] as String?) ?? 'scheduled';
    _serviceDate = societyOpsParseDate(e?['serviceDate']) ?? DateTime.now();
    _nextServiceDate = societyOpsParseDate(e?['nextServiceDate']);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _vendor.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _pickServiceDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0D9488)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _serviceDate = d);
  }

  Future<void> _pickNextDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _nextServiceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0D9488)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _nextServiceDate = d);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final cost = double.tryParse(_cost.text.trim()) ?? 0;
    Navigator.pop(context, {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'vendorName': _vendor.text.trim(),
      'serviceDate': _serviceDate,
      'nextServiceDate': _nextServiceDate,
      'cost': cost,
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: _SocietyOpsSheetChrome(
        headerColor: const Color(0xFF0D9488),
        icon: Icons.elevator_rounded,
        title: _isEdit ? 'Edit Lift Service' : 'Add Lift Service',
        onSubmit: _submit,
        submitLabel: _isEdit ? 'Save Changes' : 'Log Lift Service',
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _title,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Title', hint: 'e.g. Monthly Lift Maintenance', prefixIcon: Icons.title_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Description', hint: 'Work done or notes', prefixIcon: Icons.description_outlined),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _vendor,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Vendor name', hint: 'e.g. Otis Elevators', prefixIcon: Icons.business_rounded),
              ),
              const SizedBox(height: 14),

              // Date Picker Tiles
              _DateTile(
                label: 'Service Date',
                dateString: _dateFormat.format(_serviceDate),
                icon: Icons.calendar_today_rounded,
                accentColor: const Color(0xFF0D9488),
                onTap: _pickServiceDate,
              ),
              const SizedBox(height: 10),
              _DateTile(
                label: 'Next Service Date (optional)',
                dateString: _nextServiceDate != null ? _dateFormat.format(_nextServiceDate!) : 'Not scheduled',
                icon: Icons.event_repeat_rounded,
                accentColor: const Color(0xFF0D9488),
                onTap: _pickNextDate,
                onClear: _nextServiceDate != null ? () => setState(() => _nextServiceDate = null) : null,
              ),

              const SizedBox(height: 14),
              TextFormField(
                controller: _cost,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Cost (₹)', prefixIcon: Icons.currency_rupee_rounded),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return 'Valid cost ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Status', prefixIcon: Icons.info_outline_rounded),
                items: [
                  DropdownMenuItem(value: 'scheduled', child: Text('Scheduled', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'completed', child: Text('Completed', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'delayed', child: Text('Delayed', style: GoogleFonts.inter())),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'scheduled'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Lift Payment Sheet ---

class SocietyOpsLiftPaymentSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const SocietyOpsLiftPaymentSheet({super.key, this.existing});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? existing,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SocietyOpsLiftPaymentSheet(existing: existing),
      ),
    );
  }

  @override
  State<SocietyOpsLiftPaymentSheet> createState() => _SocietyOpsLiftPaymentSheetState();
}

class _SocietyOpsLiftPaymentSheetState extends State<SocietyOpsLiftPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  static final _dateFormat = DateFormat('dd MMM yyyy');
  late final TextEditingController _vendor;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late String _status;
  late DateTime _dueDate;
  DateTime? _paidDate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _vendor = TextEditingController(text: e?['vendorName']?.toString() ?? '');
    _description = TextEditingController(text: e?['description']?.toString() ?? '');
    _amount = TextEditingController(text: e != null ? '${e['amount'] ?? ''}' : '');
    _status = (e?['status'] as String?) ?? 'pending';
    _dueDate = societyOpsParseDate(e?['dueDate']) ?? DateTime.now();
    _paidDate = societyOpsParseDate(e?['paidDate']);
  }

  @override
  void dispose() {
    _vendor.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFD97706)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Future<void> _pickPaid() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _paidDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFD97706)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _paidDate = d);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt < 0) return;
    Navigator.pop(context, {
      'vendorName': _vendor.text.trim(),
      'description': _description.text.trim(),
      'amount': amt,
      'dueDate': _dueDate,
      'paidDate': _paidDate,
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: _SocietyOpsSheetChrome(
        headerColor: const Color(0xFFD97706),
        icon: Icons.payments_rounded,
        title: _isEdit ? 'Edit Lift Payment' : 'Add Lift Payment',
        onSubmit: _submit,
        submitLabel: _isEdit ? 'Save Changes' : 'Record Payment',
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _vendor,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Vendor name', hint: 'e.g. Otis Elevator AMC', prefixIcon: Icons.business_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vendor name is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Description', hint: 'Invoice details or quarter info', prefixIcon: Icons.description_outlined),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amount,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Amount (₹)', prefixIcon: Icons.account_balance_wallet_outlined),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return 'Valid amount ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _DateTile(
                label: 'Due Date',
                dateString: _dateFormat.format(_dueDate),
                icon: Icons.event_rounded,
                accentColor: const Color(0xFFD97706),
                onTap: _pickDue,
              ),
              const SizedBox(height: 10),
              _DateTile(
                label: 'Paid Date (optional)',
                dateString: _paidDate != null ? _dateFormat.format(_paidDate!) : 'Not paid yet',
                icon: Icons.event_available_rounded,
                accentColor: const Color(0xFFD97706),
                onTap: _pickPaid,
                onClear: _paidDate != null ? () => setState(() => _paidDate = null) : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Status', prefixIcon: Icons.info_outline_rounded),
                items: [
                  DropdownMenuItem(value: 'pending', child: Text('Pending', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'paid', child: Text('Paid', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue', style: GoogleFonts.inter())),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'pending'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Asset Sheet ---

class SocietyOpsAssetSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const SocietyOpsAssetSheet({super.key, this.existing});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? existing,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SocietyOpsAssetSheet(existing: existing),
      ),
    );
  }

  @override
  State<SocietyOpsAssetSheet> createState() => _SocietyOpsAssetSheetState();
}

class _SocietyOpsAssetSheetState extends State<SocietyOpsAssetSheet> {
  final _formKey = GlobalKey<FormState>();
  static final _dateFormat = DateFormat('dd MMM yyyy');
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _qty;
  late final TextEditingController _location;
  late String _condition;
  late final TextEditingController _notes;
  DateTime? _purchaseDate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _category = TextEditingController(text: e?['category']?.toString() ?? '');
    _qty = TextEditingController(text: '${e?['quantity'] ?? 1}');
    _location = TextEditingController(text: e?['location']?.toString() ?? '');
    _condition = (e?['condition'] as String?) ?? 'good';
    _notes = TextEditingController(text: e?['notes']?.toString() ?? '');
    _purchaseDate = societyOpsParseDate(e?['purchaseDate']);
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _qty.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPurchase() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _purchaseDate = d);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final q = int.tryParse(_qty.text.trim()) ?? 1;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'category': _category.text.trim(),
      'quantity': q,
      'location': _location.text.trim(),
      'condition': _condition,
      'purchaseDate': _purchaseDate,
      'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: _SocietyOpsSheetChrome(
        headerColor: const Color(0xFF7C3AED),
        icon: Icons.inventory_2_rounded,
        title: _isEdit ? 'Edit Asset' : 'Add Asset',
        onSubmit: _submit,
        submitLabel: _isEdit ? 'Save Changes' : 'Register Asset',
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Name', hint: 'e.g. CCTV Camera System', prefixIcon: Icons.devices_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _category,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Category', hint: 'e.g. Electronics, Plumbing, Furniture', prefixIcon: Icons.category_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Category is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _qty,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Quantity', prefixIcon: Icons.pin_outlined),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return 'Valid number ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Location', hint: 'e.g. Block A Lobby', prefixIcon: Icons.place_outlined),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Condition', prefixIcon: Icons.build_outlined),
                items: [
                  DropdownMenuItem(value: 'good', child: Text('Good', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'retired', child: Text('Retired', style: GoogleFonts.inter())),
                ],
                onChanged: (v) => setState(() => _condition = v ?? 'good'),
              ),
              const SizedBox(height: 14),
              _DateTile(
                label: 'Purchase Date (optional)',
                dateString: _purchaseDate != null ? _dateFormat.format(_purchaseDate!) : 'Not set',
                icon: Icons.shopping_bag_outlined,
                accentColor: const Color(0xFF7C3AED),
                onTap: _pickPurchase,
                onClear: _purchaseDate != null ? () => setState(() => _purchaseDate = null) : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: _sheetInputDecoration(label: 'Notes', hint: 'Warranty details or model numbers', prefixIcon: Icons.notes_rounded),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String dateString;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTile({
    required this.label,
    required this.dateString,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateString,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: onClear,
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared chrome: header + scrollable form + actions.
class _SocietyOpsSheetChrome extends StatelessWidget {
  final Color headerColor;
  final IconData icon;
  final String title;
  final VoidCallback onSubmit;
  final String submitLabel;
  final Widget child;

  const _SocietyOpsSheetChrome({
    required this.headerColor,
    required this.icon,
    required this.title,
    required this.onSubmit,
    required this.submitLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Header Banner including top rounded corners and integrated drag handle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [headerColor, headerColor.withValues(alpha: 0.88)],
              ),
            ),
            child: Column(
              children: [
                // Integrated Drag Handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  child,
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: headerColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      submitLabel,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
