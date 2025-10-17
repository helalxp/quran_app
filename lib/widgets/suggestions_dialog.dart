// lib/widgets/suggestions_dialog.dart

import 'package:flutter/material.dart';
import '../services/suggestions_service.dart';
import '../services/analytics_service.dart';

class SuggestionsDialog extends StatefulWidget {
  const SuggestionsDialog({super.key});

  @override
  State<SuggestionsDialog> createState() => _SuggestionsDialogState();
}

class _SuggestionsDialogState extends State<SuggestionsDialog> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Log analytics when dialog is opened
    AnalyticsService.logSuggestionsOpened();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitSuggestion() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الرجاء كتابة اقتراحك',
            textDirection: TextDirection.rtl,
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await SuggestionsService.submitSuggestion(
        message: message,
      );

      if (mounted) {
        if (success) {
          // Log successful submission
          AnalyticsService.logSuggestionSubmitted(
            false, // no screenshots
            message.length,
          );

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'شكراً لك! تم إرسال اقتراحك بنجاح',
                textDirection: TextDirection.rtl,
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );

          // Close dialog
          Navigator.of(context).pop();
        } else {
          // Log failure
          AnalyticsService.logSuggestionFailed('submission_failed');

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'حدث خطأ. الرجاء المحاولة لاحقاً',
                textDirection: TextDirection.rtl,
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AnalyticsService.logSuggestionFailed(e.toString());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'حدث خطأ. الرجاء المحاولة لاحقاً',
              textDirection: TextDirection.rtl,
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text(
          'اقتراحاتك تهمنا',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'شاركنا أفكارك واقتراحاتك لتحسين التطبيق',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                textDirection: TextDirection.rtl,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'اكتب اقتراحك هنا...',
                  hintTextDirection: TextDirection.rtl,
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitSuggestion,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text('إرسال'),
          ),
        ],
      ),
    );
  }
}
