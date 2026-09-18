import 'package:flutter/material.dart';

import '../../config/auth_legal_content.dart';

class RegistrationPrivacyNotice extends StatefulWidget {
  const RegistrationPrivacyNotice({
    super.key,
    required this.dark,
    required this.onAcknowledgedChanged,
  });

  final bool dark;
  final ValueChanged<bool> onAcknowledgedChanged;

  @override
  State<RegistrationPrivacyNotice> createState() => _RegistrationPrivacyNoticeState();
}

class _RegistrationPrivacyNoticeState extends State<RegistrationPrivacyNotice> {
  final _scrollController = ScrollController();
  bool _reachedBottom = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent <= 12 ||
        position.pixels >= position.maxScrollExtent - 12;
    if (atBottom && !_reachedBottom) {
      setState(() => _reachedBottom = true);
    }
  }

  void _emit() {
    widget.onAcknowledgedChanged(_reachedBottom && _accepted);
  }

  @override
  Widget build(BuildContext context) {
    final document = AuthLegalContent.documents[AuthLegalDocumentId.privacy]!;
    final titleColor = widget.dark ? Colors.white.withValues(alpha: 0.96) : const Color(0xFF0F172A);
    final bodyColor = widget.dark ? Colors.white.withValues(alpha: 0.78) : const Color(0xFF475569);
    final muted = widget.dark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B);
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.42).clamp(200.0, 320.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AuthLegalContent.privacyNoticeTitle,
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AuthLegalContent.privacyNoticeIntro,
          style: TextStyle(color: bodyColor, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 6),
        Text(
          'Last updated: ${document.updated}',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.dark ? const Color(0xA80B1018) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.dark
                    ? Colors.white.withValues(alpha: 0.18)
                    : const Color(0xFFDCE3EC),
              ),
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical) {
                  _onScroll();
                }
                return true;
              },
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                itemCount: document.sections.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: widget.dark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFDCE3EC),
                  ),
                ),
                itemBuilder: (context, index) {
                  final section = document.sections[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.heading,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.body,
                        style: TextStyle(color: bodyColor, fontSize: 13.2, height: 1.6),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (!_reachedBottom) ...[
          const SizedBox(height: 10),
          Text(
            AuthLegalContent.privacyNoticeScrollHint,
            style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12.5, height: 1.45),
          ),
        ],
        const SizedBox(height: 12),
        AbsorbPointer(
          absorbing: !_reachedBottom,
          child: Opacity(
            opacity: _reachedBottom ? 1 : 0.5,
            child: CheckboxListTile(
              value: _accepted,
              onChanged: _reachedBottom
                  ? (value) {
                      setState(() => _accepted = value == true);
                      _emit();
                    }
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFFE53935),
              checkColor: Colors.white,
              title: Text(
                AuthLegalContent.privacyNoticeCheckbox,
                style: TextStyle(color: titleColor, fontSize: 13.5, height: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
