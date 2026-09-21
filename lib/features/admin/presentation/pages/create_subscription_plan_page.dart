import 'package:flutter/material.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/services/api_service.dart';

class CreateSubscriptionPlanPage extends StatefulWidget {
  const CreateSubscriptionPlanPage({super.key});

  @override
  State<CreateSubscriptionPlanPage> createState() => _CreateSubscriptionPlanPageState();
}

class _CreateSubscriptionPlanPageState extends State<CreateSubscriptionPlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _daysValidityController = TextEditingController();
  final _amountController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _saving = false;
  String? _error;
  String? _selectedApartmentId;
  List<ApartmentModel> _apartments = [];
  bool _loadingApartments = true;
  Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _loadApartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _daysValidityController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadApartments() async {
    setState(() => _loadingApartments = true);
    final result = await _apiService.getApartments();
    if (!mounted) return;
    setState(() {
      _loadingApartments = false;
      if (result['success'] == true) {
        final list = result['apartments'] as List<dynamic>? ?? [];
        _apartments = list
            .map((e) => ApartmentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _submit() async {
    _error = null;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    
    final result = await _apiService.createSubscriptionPlan(
      name: _nameController.text.trim(),
      daysValidity: int.parse(_daysValidityController.text.trim()),
      amount: double.parse(_amountController.text.trim()),
      description: null,
      color: _selectedColor != null ? _colorToHex(_selectedColor!) : null,
      displayOrder: null,
      apartmentId: _selectedApartmentId,
    );
    
    if (!mounted) return;
    setState(() => _saving = false);
    
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription plan created successfully'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result['error'] as String? ?? 'Failed to create subscription plan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Subscription Plan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Plan Name *',
                  hintText: 'e.g. Basic, Standard, Premium',
                  prefixIcon: Icon(Icons.card_membership, color: AppTheme.primaryColor),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Plan name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _daysValidityController,
                      decoration: const InputDecoration(
                        labelText: 'Days Validity *',
                        hintText: 'e.g. 30, 90, 365',
                        prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Days validity is required';
                        final days = int.tryParse(v.trim());
                        if (days == null || days < 1) return 'Must be at least 1 day';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹) *',
                        hintText: 'e.g. 999, 2499',
                        prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryColor),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        final amount = double.tryParse(v.trim());
                        if (amount == null || amount < 0) return 'Must be a valid positive number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final Color? pickedColor = await showDialog<Color>(
                    context: context,
                    builder: (context) => _ColorPickerDialog(selectedColor: _selectedColor),
                  );
                  if (pickedColor != null) {
                    setState(() => _selectedColor = pickedColor);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.color_lens, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      const Text('Color'),
                      const Spacer(),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedColor ?? AppTheme.dividerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.textColor.withAlpha(90)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textColor.withAlpha(120)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedApartmentId,
                decoration: const InputDecoration(
                  labelText: 'Apartment (Optional)',
                  hintText: 'Select apartment for apartment-specific plan',
                  prefixIcon: Icon(Icons.apartment, color: AppTheme.primaryColor),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Global (All Apartments)', overflow: TextOverflow.ellipsis),
                  ),
                  ..._apartments.map((apt) => DropdownMenuItem<String>(
                        value: apt.id,
                        child: Text(
                          apt.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: _loadingApartments
                    ? null
                    : (value) {
                        setState(() => _selectedApartmentId = value);
                      },
                validator: (v) => null, // Optional field
                isExpanded: true,
              ),
              if (_loadingApartments)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Create Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Color> _planAccentPalette() => [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      AppTheme.primaryColor.withAlpha(200),
      AppTheme.secondaryColor.withAlpha(200),
      AppTheme.accentColor.withAlpha(220),
      AppTheme.primaryColor.withAlpha(110),
      AppTheme.secondaryColor.withAlpha(110),
      AppTheme.accentColor.withAlpha(120),
      AppTheme.primaryColor.withAlpha(55),
      AppTheme.secondaryColor.withAlpha(55),
      AppTheme.accentColor.withAlpha(60),
      AppTheme.primaryColor.withAlpha(30),
      AppTheme.secondaryColor.withAlpha(30),
      AppTheme.accentColor.withAlpha(35),
      AppTheme.textColor.withAlpha(180),
      AppTheme.errorColor,
    ];

class _ColorPickerDialog extends StatelessWidget {
  final Color? selectedColor;

  const _ColorPickerDialog({this.selectedColor});

  @override
  Widget build(BuildContext context) {
    final colors = _planAccentPalette();
    return AlertDialog(
      title: const Text('Select Color'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: colors.length,
          itemBuilder: (context, index) {
            final color = colors[index];
            final isSelected =
                selectedColor != null && selectedColor == color;
            return GestureDetector(
              onTap: () => Navigator.pop(context, color),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.textColor : AppTheme.dividerColor,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, color: AppTheme.textColor)
                    : null,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (selectedColor != null)
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Clear'),
          ),
      ],
    );
  }
}
