import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../services/api_client.dart';
import '../../services/orders_api.dart';
import '../../widgets/primary_button.dart';

/// `08xx…` → `628xx…` untuk tautan wa.me.
String waIntl(String number) {
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.startsWith('0') ? '62${digits.substring(1)}' : digits;
}

/// Pesan WhatsApp ke penjual dari `GET /orders/:code/whatsapp`.
/// Argumen rute: `String code`.
class WhatsAppGeneratorScreen extends StatefulWidget {
  const WhatsAppGeneratorScreen({super.key});

  @override
  State<WhatsAppGeneratorScreen> createState() =>
      _WhatsAppGeneratorScreenState();
}

class _WhatsAppGeneratorScreenState extends State<WhatsAppGeneratorScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _code;
  String _waNumber = '';
  String _serverMessage = '';
  String _serverUrl = '';
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_code != null || _error != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _code = args;
      _load();
    } else {
      _loading = false;
      _error = 'Pesanan tidak ditemukan.';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    if (!_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final d = await api.whatsapp(_code!);
      if (!mounted) return;
      setState(() {
        _waNumber = '${d['wa_number'] ?? ''}';
        _serverMessage = '${d['message'] ?? ''}';
        _serverUrl = '${d['url'] ?? ''}';
        _messageController.text = _serverMessage;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Tautan server dipakai selama pesan belum diubah; selain itu dirakit ulang.
  Uri get _waUri {
    final text = _messageController.text;
    if (text == _serverMessage && _serverUrl.isNotEmpty) {
      return Uri.parse(_serverUrl);
    }
    return Uri.parse(
        'https://wa.me/${waIntl(_waNumber)}?text=${Uri.encodeComponent(text)}');
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: _messageController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pesan berhasil disalin ke clipboard!'),
        backgroundColor: AppColors.successDark,
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(_waUri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
          const SnackBar(content: Text('WhatsApp tidak dapat dibuka.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chat Penjual',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: AppTextStyles.bodyMedium),
                        if (_code != null)
                          TextButton(
                              onPressed: _load,
                              child: const Text('Coba lagi')),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pesan untuk penjual',
                                      style: AppTextStyles.h4.copyWith(
                                        color: const Color(0xFF065F46),
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Berisi kode dan rincian pesanan $_code. '
                                      'Ubah bila perlu, lalu kirim ke $_waNumber.',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: const Color(0xFF047857),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Pesan',
                          style: AppTextStyles.h4.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.cardBorder
                                    .withValues(alpha: 0.8)),
                          ),
                          child: TextField(
                            controller: _messageController,
                            minLines: 8,
                            maxLines: 16,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.5,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: Icon(Icons.copy_rounded,
                              size: 16, color: AppColors.textPrimary),
                          label: Text(
                            'Salin Pesan',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            side: BorderSide(color: AppColors.cardBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _copyMessage,
                        ),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: PrimaryButton(
                  text: 'Kirim via WhatsApp',
                  icon: Icons.chat_bubble_rounded,
                  backgroundColor: const Color(0xFF10B981),
                  gradient: null,
                  onPressed: _openWhatsApp,
                ),
              ),
            ),
    );
  }
}
