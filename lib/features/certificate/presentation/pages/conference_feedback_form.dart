import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Conference feedback shown after a certificate is enabled and before download.
class ConferenceFeedbackForm extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final bool submitting;
  final ValueChanged<Map<String, String>> onSubmit;

  const ConferenceFeedbackForm({
    super.key,
    required this.questions,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  State<ConferenceFeedbackForm> createState() => _ConferenceFeedbackFormState();
}

class _ConferenceFeedbackFormState extends State<ConferenceFeedbackForm> {
  final Map<String, String> _answers = {};
  String? _error;

  @override
  Widget build(BuildContext context) {
    String? section;
    final children = <Widget>[
      Text(
        'CONFERENCE FEEDBACK',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .6,
          color: DarkColors.muted,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Share your feedback to download your certificate. Rating questions are required. Written comments are optional.',
        style: GoogleFonts.inter(fontSize: 12.5, color: DarkColors.muted, height: 1.4),
      ),
    ];

    for (final q in widget.questions) {
      final next = q['section']?.toString() ?? '';
      if (next != section) {
        section = next;
        children.add(const SizedBox(height: 18));
        children.add(
          Text(
            section,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        );
      }
      children.add(const SizedBox(height: 14));
      children.add(_question(q));
    }

    if (_error != null) {
      children.add(const SizedBox(height: 12));
      children.add(
        Text(
          _error!,
          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFF87171)),
        ),
      );
    }

    children.add(const SizedBox(height: 16));
    children.add(
      SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: widget.submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: DarkColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: widget.submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Submit feedback',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: darkCardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  void _submit() {
    for (final q in widget.questions) {
      if (q['required'] == true && (_answers[q['id']?.toString()] ?? '').trim().isEmpty) {
        setState(() => _error = 'Please answer every required question.');
        return;
      }
    }
    setState(() => _error = null);
    widget.onSubmit(Map<String, String>.from(_answers));
  }

  Widget _question(Map<String, dynamic> q) {
    final id = q['id']?.toString() ?? '';
    final required = q['required'] == true;
    final prompt = Text.rich(
      TextSpan(
        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white, height: 1.35),
        children: [
          TextSpan(text: '${q['number']}. ${q['prompt']}'),
          if (required) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFF87171))),
        ],
      ),
    );
    if (q['type'] == 'text') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          prompt,
          const SizedBox(height: 8),
          TextField(
            maxLength: 2000,
            maxLines: q['multiline'] == true ? 4 : 1,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: DarkColors.field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => _answers[id] = v,
          ),
        ],
      );
    }
    final options = (q['options'] as List? ?? []).map((o) => o.toString()).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        prompt,
        const SizedBox(height: 6),
        for (final option in options)
          InkWell(
            onTap: () => setState(() => _answers[id] = option),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _answers[id] == option ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: _answers[id] == option ? DarkColors.accent : DarkColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option,
                      style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
