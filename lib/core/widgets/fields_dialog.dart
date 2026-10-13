import 'package:flutter/material.dart';

class FieldSpec {
  const FieldSpec(
    this.label, {
    this.initial = '',
    this.keyboard,
    this.required = true,
    this.hint,
    this.obscure = false,
    this.validator,
  });

  final String label;
  final String initial;
  final TextInputType? keyboard;
  final bool required;
  final String? hint;
  final bool obscure;
  final String? Function(String value)? validator;
}

/// A small form in a dialog. Returns the trimmed values in field order, or null
/// when cancelled. Enough for every "add / edit" in Settings and Staff.
Future<List<String>?> showFieldsDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  String confirm = 'Save',
}) {
  final controllers = [for (final f in fields) TextEditingController(text: f.initial)];
  final form = GlobalKey<FormState>();
  return showDialog<List<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                TextFormField(
                  controller: controllers[i],
                  autofocus: i == 0,
                  keyboardType: fields[i].keyboard,
                  obscureText: fields[i].obscure,
                  decoration: InputDecoration(labelText: fields[i].label, hintText: fields[i].hint),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (fields[i].required && value.isEmpty) return 'Required';
                    return fields[i].validator?.call(value);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(context, [for (final c in controllers) c.text.trim()]);
          },
          child: Text(confirm),
        ),
      ],
    ),
  ).whenComplete(() {
    for (final c in controllers) {
      c.dispose();
    }
  });
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirm = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirm)),
      ],
    ),
  );
  return ok ?? false;
}

String? numberValidator(String value) =>
    value.isEmpty || num.tryParse(value) != null ? null : 'Enter a number';
