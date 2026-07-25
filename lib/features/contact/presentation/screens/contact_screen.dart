import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/contact_repository.dart';

/// Turns a thread build error into a short human-readable detail so we can see
/// exactly why chat failed to initialise (bad room, /users/me error, ...).
String _describeThreadError(Object error) {
  if (error is ContactSendException) {
    return error.message;
  }
  if (error is DioException) {
    final status = error.response?.statusCode;
    final path = error.requestOptions.path;
    final data = error.response?.data;
    final apiMessage = data is Map && data['message'] != null
        ? data['message'].toString()
        : '';
    return 'Request failed ${status ?? ''} $path'
            '${apiMessage.isNotEmpty ? ': $apiMessage' : ''}'
        .trim();
  }
  return error.toString();
}

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingImage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auto-scroll to the newest message whenever the thread grows.
    ref.listen<AsyncValue<List<ContactMessage>>>(contactThreadProvider,
        (previous, next) {
      final previousCount = previous?.valueOrNull?.length ?? 0;
      final nextCount = next.valueOrNull?.length ?? 0;
      if (nextCount > previousCount) {
        _scrollToBottom();
      }
    });

    final threadAsync = ref.watch(contactThreadProvider);

    return Container(
      color: AppTheme.lightBackground,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(contactThreadProvider.future),
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
                children: [
                  Text(
                    'contact_title'.tr(),
                    style: TextStyle(
                      color: const Color(0xFF111111),
                      fontSize: 30.sp,
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
                          for (
                            var i = 0;
                            i < effectiveMessages.length;
                            i++
                          ) ...[
                            _ChatBubble(
                              key: ValueKey('contact-bubble-$i'),
                              message: effectiveMessages[i],
                            ),
                            SizedBox(height: 10.h),
                          ],
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => _ErrorCard(
                      detail: _describeThreadError(error),
                      onRetry: () => ref.invalidate(contactThreadProvider),
                    ),
                  ),
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 50.w,
                    height: 50.w,
                    child: ElevatedButton(
                      key: const ValueKey('contact-attach-button'),
                      onPressed: _uploadingImage ? null : _pickAndSendImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEAF4FF),
                        foregroundColor: AppTheme.brandBlue,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        elevation: 0,
                      ),
                      child: _uploadingImage
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.image_outlined, size: 22.sp),
                    ),
                  ),
                  SizedBox(width: 10.w),
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
                        fillColor: const Color(0xFFEAF4FF),
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
                      onPressed: _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        elevation: 0,
                      ),
                      child: Icon(Icons.send_rounded, size: 22.sp),
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

    try {
      ref.read(contactThreadProvider.notifier).sendMessage(text);
      _messageController.clear();
      // The sent message is appended when the server echoes it back via the
      // `new-message` socket event; the ref.listen in build handles scrolling.
    } on ContactSendException catch (error) {
      if (kDebugMode) {
        debugPrint('[ContactScreen] Send failed error=$error');
      }
      final fallback = 'contact_send_failed'.tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message.isNotEmpty ? error.message : fallback),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ContactScreen] Send failed error=$error');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('contact_send_failed'.tr())),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ContactScreen] pickImage failed error=$error');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('contact_image_pick_failed'.tr())),
        );
      }
      return;
    }
    if (picked == null) {
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      // Send the typed text along with the image as a caption, then clear it.
      final caption = _messageController.text.trim();
      await ref
          .read(contactThreadProvider.notifier)
          .sendImage(File(picked.path), caption: caption);
      _messageController.clear();
    } on ContactSendException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ContactScreen] send image failed error=$error');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('contact_image_upload_failed'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
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
    final agentName = message.senderName?.trim();
    final showAgentName = isAgent && agentName != null && agentName.isNotEmpty;

    return Align(
      alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 340.w),
        child: Column(
          crossAxisAlignment:
              isAgent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (showAgentName) ...[
              Padding(
                padding: EdgeInsets.only(left: 6.w, bottom: 4.h),
                child: Text(
                  agentName,
                  style: TextStyle(
                    color: const Color(0xFF6E7D92),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            Container(
              padding: message.hasImage && message.text.isEmpty
                  ? EdgeInsets.all(6.w)
                  : EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: isAgent ? const Color(0xFFEAF4FF) : AppTheme.brandBlue,
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: isAgent ? Radius.circular(4.r) : radius,
                  bottomRight: isAgent ? radius : Radius.circular(4.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.hasImage)
                    _ChatImage(
                      imageUrl: AppEnv.resolveMediaUrl(message.imageUrl!),
                    ),
                  if (message.hasImage && message.text.isNotEmpty)
                    SizedBox(height: 8.h),
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isAgent ? const Color(0xFF2E58B5) : Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 4.h,
                left: isAgent ? 6.w : 0,
                right: isAgent ? 0 : 6.w,
              ),
              child: Text(
                _formatMessageTime(message.createdAt),
                style: TextStyle(
                  color: const Color(0xFF9AA7B8),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats the message time in the device's local zone as `HH:mm`, prefixing
  /// the date (`dd/MM`) when the message is not from today.
  static String _formatMessageTime(DateTime createdAt) {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final time = '$hh:$mm';

    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) {
      return time;
    }
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$dd/$mo $time';
  }
}

class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap opens a full-screen, pinch-to-zoom preview.
      onTap: () => _openPreview(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 240.w, maxHeight: 280.h),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                return child;
              }
              return SizedBox(
                width: 200.w,
                height: 150.h,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200.w,
                height: 120.h,
                color: const Color(0xFFDCE6F2),
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: const Color(0xFF8A99AD),
                  size: 28.sp,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openPreview(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, _, _) => _ImagePreview(imageUrl: imageUrl),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// Full-screen image preview with pinch-to-zoom and a close button.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tap on the dark backdrop closes the preview.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 48.sp,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Material(
                  color: Colors.black38,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const ValueKey('chat-image-preview-close'),
                    tooltip: 'common_close'.tr(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry, this.detail});

  final VoidCallback onRetry;
  final String? detail;

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
          if (detail != null && detail!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFB23B3B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: 8.h),
          TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
        ],
      ),
    );
  }
}
