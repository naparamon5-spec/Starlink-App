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
      child: AlertDialog(
        title: const Text('Update Required'),
        content: Text(buffer.toString()),
        actions: [
          TextButton(
            onPressed: () async {
              final Uri url = Uri.parse(downloadUrl);
              final launched = await launchUrl(
                url,
                mode: LaunchMode.externalApplication,
              );
              if (!launched && context.mounted) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Unable to open the update link.'),
                  ),
                );
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
