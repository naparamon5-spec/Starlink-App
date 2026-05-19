import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String downloadUrl;

  const ForceUpdateDialog({super.key, required this.downloadUrl});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Update Required'),
        content: const Text('A new version of the app is available. Please update to continue.'),
        actions: [
          TextButton(
            onPressed: () async {
              final Uri url = Uri.parse(downloadUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
