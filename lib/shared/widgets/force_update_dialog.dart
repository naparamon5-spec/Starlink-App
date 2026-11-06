import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String downloadUrl;
  final String? currentVersion;
  final String? latestVersion;

  const ForceUpdateDialog({
    super.key,
    required this.downloadUrl,
    this.currentVersion,
    this.latestVersion,
  });

  @override
  Widget build(BuildContext context) {
    final buffer = StringBuffer(
      'A new version of the app is available. Please update to continue.',
    );
    if (currentVersion != null && latestVersion != null) {
      buffer.write('\n\nInstalled: $currentVersion\nLatest: $latestVersion');
    }

    return PopScope(
      canPop: false,
      child: AppDialog(
        icon: Icons.system_update_rounded,
        title: 'Update Required',
        message: buffer.toString(),
        confirmLabel: 'Update Now',
        onConfirm: () async {
          final Uri url = Uri.parse(downloadUrl);
          final launched = await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            AppToast.error(context, 'Unable to open the update link.');
          }
        },
      ),
    );
  }
}
