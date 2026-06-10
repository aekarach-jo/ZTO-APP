import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/contact_repository.dart';

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync = ref.watch(contactThreadProvider);

    return Container(
      color: const Color(0xFFF1F3F7),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
              children: [
                Text(
                  'contact_title'.tr(),
                  style: TextStyle(
                    color: const Color(0xFF111111),
                    fontSize: 46.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 14.h),
                threadAsync.when(
                  data: (messages) {
                    final effectiveMessages = messages.isEmpty
                        ? [
                            ContactMessage(
                              id: 'welcome',
                              role: ContactMessageRole.agent,
                              text: 'contact_welcome_message'.tr(),
                              createdAt: DateTime.now(),
                            ),
                          ]
                        : messages;

                    return Column(
                      children: [
                        for (var i = 0; i < effectiveMessages.length; i++) ...[
                          _ChatBubble(
                            key: ValueKey('contact-bubble-$i'),
                            message: effectiveMessages[i],
                          ),
                          SizedBox(height: 10.h),
                        ],
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _ErrorCard(onRetry: () => ref.invalidate(contactThreadProvider)),
                ),
                SizedBox(height: 80.h),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'contact_input_hint'.tr(),
                        hintStyle: TextStyle(
                          color: const Color(0xFFA8AFB9),
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFECEFF4),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  SizedBox(
                    width: 50.w,
                    height: 50.w,
                    child: ElevatedButton(
                      key: const ValueKey('contact-send-button'),
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE9650E),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text('🚀', style: TextStyle(fontSize: 20.sp)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });
    _messageController.clear();

    ref.read(contactThreadProvider.notifier).sendMessage(text).then((_) {
      if (!mounted) {
        return;
      }
      _scrollToBottom();
    }).catchError((error) {
      if (!mounted) {
        return;
      }
      if (_messageController.text.trim().isEmpty) {
        _messageController.text = text;
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      }

      final fallback = 'contact_send_failed'.tr();
      final details = error is ContactSendException ? error.message : '';
      if (kDebugMode) {
        debugPrint('[ContactScreen] Send failed error=$error');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(details.isNotEmpty ? details : fallback)),
      );
    }).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({super.key, required this.message});

  final ContactMessage message;

  @override
  Widget build(BuildContext context) {
    final isAgent = message.role == ContactMessageRole.agent;
    final radius = Radius.circular(18.r);

    return Align(
      alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 340.w),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: isAgent ? const Color(0xFFEEF2FA) : const Color(0xFFE9650E),
            borderRadius: BorderRadius.only(
              topLeft: radius,
              topRight: radius,
              bottomLeft: isAgent ? Radius.circular(4.r) : radius,
              bottomRight: isAgent ? radius : Radius.circular(4.r),
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: isAgent ? const Color(0xFF2E58B5) : Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Text(
            'contact_load_error'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF6E7D92),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
        ],
      ),
    );
  }
}

