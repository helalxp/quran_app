// lib/widgets/jump_to_page_dialog.dart

import 'package:flutter/material.dart';
import '../utils/input_sanitizer.dart';
import '../constants/app_strings.dart';

/// Reusable dialog widget for jumping to a specific page
class JumpToPageDialog extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageSelected;

  const JumpToPageDialog({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  @override
  State<JumpToPageDialog> createState() => _JumpToPageDialogState();
}

class _JumpToPageDialogState extends State<JumpToPageDialog> {
  final TextEditingController _pageController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _pageController.text = widget.currentPage.toString();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _validateAndJump() {
    final input = _pageController.text.trim();
    final pageNumber = InputSanitizer.sanitizeNumber(input, min: 1, max: widget.totalPages);

    if (pageNumber == null) {
      setState(() {
        _errorText = AppStrings.invalidInput;
      });
      return;
    }

    if (pageNumber < 1 || pageNumber > widget.totalPages) {
      setState(() {
        _errorText = 'رقم الصفحة يجب أن يكون بين 1 و ${widget.totalPages}';
      });
      return;
    }

    Navigator.of(context).pop();
    widget.onPageSelected(pageNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppStrings.jumpToPage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Amiri',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _pageController,
              keyboardType: TextInputType.number,
              maxLength: widget.totalPages.toString().length,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'Amiri',
                fontSize: 18,
              ),
              decoration: InputDecoration(
                labelText: 'رقم الصفحة',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'Amiri',
                ),
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              validator: InputSanitizer.createValidator(
                fieldName: 'رقم الصفحة',
                required: true,
                isNumeric: true,
                minValue: 1,
                maxValue: widget.totalPages,
              ),
              onChanged: (value) {
                // Real-time input formatting and validation
                final formatted = InputSanitizer.formatInput(
                  value,
                  isNumeric: true,
                  maxLength: widget.totalPages.toString().length,
                );

                if (formatted != value) {
                  _pageController.value = _pageController.value.copyWith(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }

                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
              onFieldSubmitted: (value) => _validateAndJump(),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppStrings.cancel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'Amiri',
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _validateAndJump,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(
              AppStrings.ok,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}