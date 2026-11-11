import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../models/meta.dart';
import '../../services/api_client.dart';
import '../../services/meta_api.dart';
import '../../widgets/primary_button.dart';

/// Daftar titik temu dari `GET /meta/pickup-points`; mengembalikan
/// [PickupPoint] yang dipilih (atau null bila dibatalkan).
class PickupPointPickerScreen extends StatefulWidget {
  const PickupPointPickerScreen({super.key, this.selectedId, this.points});

  final int? selectedId;

  /// Bila diisi (mis. titik temu milik satu toko), daftar tidak diambil dari server.
  final List<PickupPoint>? points;

  @override
  State<PickupPointPickerScreen> createState() => _PickupPointPickerScreenState();
}

class _PickupPointPickerScreenState extends State<PickupPointPickerScreen> {
  List<PickupPoint> _points = const [];
  int? _selectedId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
    if (widget.points != null) {
      _points = widget.points!;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final points = await context.read<ApiClient>().pickupPoints();
      if (!mounted) return;
      setState(() {
        _points = points;
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

  @override
  Widget build(BuildContext context) {
    final selected = _points.where((p) => p.id == _selectedId).firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pilih Titik Temu', style: AppTextStyles.h3.copyWith(fontSize: 18)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: AppTextStyles.bodyMedium),
                      TextButton(onPressed: _load, child: const Text('Coba lagi')),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: _points.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = _points[i];
                    final isSelected = p.id == _selectedId;
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.cardBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        leading: Icon(Icons.location_on_rounded,
                            color: isSelected ? AppColors.primary : AppColors.textMuted),
                        title: Text(p.name,
                            style: AppTextStyles.h4.copyWith(fontSize: 14)),
                        subtitle: p.description == null
                            ? null
                            : Text(p.description!,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : null,
                        onTap: () => setState(() => _selectedId = p.id),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            text: 'Pilih Titik Temu Ini',
            onPressed: selected == null ? null : () => Navigator.pop(context, selected),
          ),
        ),
      ),
    );
  }
}
