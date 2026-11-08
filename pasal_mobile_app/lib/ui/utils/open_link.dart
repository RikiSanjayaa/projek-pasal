import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_notification.dart';

/// Membuka [url] di browser eksternal (tab baru di web). Bila gagal, tautan
/// disalin ke clipboard.
Future<void> openExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  var opened = false;
  if (uri != null && uri.hasScheme) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (opened) return;

  await Clipboard.setData(ClipboardData(text: url.trim()));
  if (context.mounted) {
    AppNotification.show(
      context,
      'Link disalin',
      color: Colors.green,
      icon: Icons.link_rounded,
    );
  }
}
