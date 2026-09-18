import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../models/organization.dart';
import '../../services/app_state.dart';
import '../../utils/bylaws_display.dart';

Future<void> showOrgBylawsSheet(BuildContext context, Organization org) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    builder: (context) => _OrgBylawsSheet(orgId: org.id, fallback: org),
  );
}

class _OrgBylawsSheet extends StatelessWidget {
  const _OrgBylawsSheet({required this.orgId, required this.fallback});

  final int orgId;
  final Organization fallback;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<AppState>().organizations.getById(orgId) ?? fallback;
    final org = live;
    final colors = context.trackit;
    final title = (org.bylawsTitle ?? '').trim().isEmpty
        ? 'Constitution and By-Laws of ${org.name}'
        : org.bylawsTitle!.trim();
    final blocks = parseBylawsDisplayBlocks(org.bylawsBody ?? '');
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.92;
    final bottomInset = media.padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppTheme.red, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.red,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.3,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 32 + bottomInset),
                children: [
                  if (org.logoUrl != null && org.logoUrl!.trim().isNotEmpty) ...[
                    Center(child: _BylawsLogo(url: org.logoUrl!)),
                    const SizedBox(height: 16),
                    Divider(color: colors.border),
                    const SizedBox(height: 12),
                  ],
                  if (!org.hasBylaws)
                    Text(
                      'No constitution is saved for ${org.name} yet.',
                      style: TextStyle(color: colors.textSecondary, height: 1.45),
                    )
                  else
                    ...blocks.map((block) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            block.text,
                            style: TextStyle(
                              fontWeight: block.kind == BylawsDisplayKind.paragraph
                                  ? FontWeight.w400
                                  : FontWeight.w800,
                              fontSize: block.kind == BylawsDisplayKind.article ? 13.5 : 13,
                              height: 1.5,
                              letterSpacing:
                                  block.kind == BylawsDisplayKind.heading ||
                                          block.kind == BylawsDisplayKind.article
                                      ? 0.3
                                      : 0,
                              color: block.kind == BylawsDisplayKind.paragraph
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BylawsLogo extends StatelessWidget {
  const _BylawsLogo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (url.startsWith('data:')) {
      final payload = url.split(',').last;
      image = Image.memory(
        base64Decode(payload),
        height: 140,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else if (url.startsWith('http')) {
      image = Image.network(
        url,
        height: 140,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      image = Image.asset(
        url,
        height: 140,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return image;
  }
}
