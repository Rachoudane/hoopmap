import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/court_report_repository.dart';
import '../../domain/report_reason.dart';
import '../report_court_controller.dart';

const Map<ReportReason, String> _reasonLabels = {
  ReportReason.inaccurate: AppStrings.reportReasonInaccurate,
  ReportReason.offensive: AppStrings.reportReasonOffensive,
  ReportReason.spam: AppStrings.reportReasonSpam,
  ReportReason.doesNotExist: AppStrings.reportReasonDoesNotExist,
  ReportReason.other: AppStrings.reportReasonOther,
};

/// Opens the "Report this court" dialog. Only meaningful for a
/// user-submitted court — see court_detail_page.dart, which never shows the
/// entry point that calls this for an "osm:"-prefixed court.
Future<void> showReportCourtDialog(BuildContext context, String courtId) {
  return showDialog<void>(
    context: context,
    builder: (context) => ReportCourtDialog(courtId: courtId),
  );
}

class ReportCourtDialog extends ConsumerStatefulWidget {
  const ReportCourtDialog({super.key, required this.courtId});

  final String courtId;

  @override
  ConsumerState<ReportCourtDialog> createState() => _ReportCourtDialogState();
}

class _ReportCourtDialogState extends ConsumerState<ReportCourtDialog> {
  ReportReason _selectedReason = ReportReason.inaccurate;
  final _commentController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await ref
        .read(reportCourtControllerProvider.notifier)
        .submit(
          courtId: widget.courtId,
          reason: _selectedReason,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        );

    if (!mounted) return;
    final state = ref.read(reportCourtControllerProvider);
    if (state.hasError) {
      setState(() {
        _errorMessage = state.error is AlreadyReportedException
            ? AppStrings.reportAlreadySubmitted
            : AppStrings.reportError;
      });
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.reportSuccessSnackBar)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(reportCourtControllerProvider).isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text(AppStrings.reportDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.reportDialogDescription),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<ReportReason>(
              groupValue: _selectedReason,
              onChanged: (value) {
                if (isSubmitting || value == null) return;
                setState(() => _selectedReason = value);
              },
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: reason,
                      title: Text(_reasonLabels[reason]!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _commentController,
              enabled: !isSubmitting,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: AppStrings.reportCommentLabel,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text(AppStrings.reportCancel),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : _submit,
          child: isSubmitting
              ? SizedBox(
                  height: 18,
                  width: 18,
                  // The label colour of the button it sits in: white is only
                  // right while the button is dark, which it is not in the
                  // dark theme.
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Text(AppStrings.reportSubmit),
        ),
      ],
    );
  }
}
