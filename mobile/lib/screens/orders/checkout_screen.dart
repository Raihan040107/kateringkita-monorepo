import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_time.dart';
import '../../models/cart_line.dart';
import '../../models/menu.dart';
import '../../models/meta.dart';
import '../../models/order.dart';
import '../../providers/session_provider.dart';
import '../../services/api_client.dart';
import '../../services/catalog_api.dart';
import '../../services/orders_api.dart';
import '../../widgets/app_modal_dialog.dart';
import '../../widgets/menu_image.dart';
import '../../widgets/payment_method_tile.dart';
import '../../widgets/primary_button.dart';
import 'pickup_point_picker_screen.dart';

/// Checkout satu toko: hitungan dari `POST /orders/quote`, lalu `POST /orders`.
/// Argumen rute: `List<CartLine>` (dari detail menu atau "Pesan lagi").
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static List<PaymentMethodOption> get _paymentOptions => [
        PaymentMethodOption(
          method: PaymentMethod.va,
          code: 'VA',
          title: 'Virtual Account',
          subtitle: 'BCA, BNI, BRI',
          badge: 'Otomatis',
          accent: AppColors.blue,
          accentBg: AppColors.blueLight,
        ),
        PaymentMethodOption(
          method: PaymentMethod.online,
          code: 'QR',
          title: 'Bayar Online',
          subtitle: 'QRIS, GoPay, ShopeePay',
          badge: 'Cepat',
          accent: AppColors.primaryDark,
          accentBg: AppColors.primarySoft,
        ),
      ];

  List<CartLine> _lines = const [];
  bool _argsLoaded = false;
  MenuDetail? _menu;
  List<PickupPoint> _pickupPoints = const [];
  int? _pickupPointId;
  DateTime? _pickupAt;
  PaymentMethod _payment = PaymentMethod.va;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  Quote? _quote;
  bool _quoting = false;
  String? _quoteError;
  String? _promoError;
  String? _pickupAtError;
  Timer? _debounce;

  // Idempotency-Key dipakai ulang selama body tidak berubah: coba ulang setelah
  // galat jaringan tidak membuat pesanan ganda.
  String? _idemKey;
  String? _idemBody;
  bool _submitting = false;

  ApiClient get _api => context.read<ApiClient>();

  bool get _needsPickupAt =>
      _lines.any((l) => l.isPreorder) ||
      (_menu?.isPreorder ?? false) ||
      _pickupAtError != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is List<CartLine> && args.isNotEmpty) _lines = args;
    final user = context.read<SessionProvider>().user;
    _nameController.text = user?.fullName ?? '';
    _phoneController.text = user?.phone ?? '';
    if (_lines.isNotEmpty) _init(user?.favoritePickupPointId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  /// Titik temu checkout harus milik toko → diambil dari detail menu pertama.
  Future<void> _init(int? favoriteId) async {
    try {
      final menu = await _api.menu(_lines.first.menuId);
      if (!mounted) return;
      final points = menu.pickupPoints;
      setState(() {
        _menu = menu;
        _pickupPoints = points;
        _pickupPointId = points.any((p) => p.id == favoriteId)
            ? favoriteId
            : points.firstOrNull?.id;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _quoteError = e.message);
      return;
    }
    await _requestQuote();
  }

  Map<String, dynamic> _body({bool withPayment = false}) {
    final note = _noteController.text.trim();
    final promo = _promoController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    return {
      'items': [for (final l in _lines) l.toJson()],
      'pickup_point_id': _pickupPointId,
      if (note.isNotEmpty) 'note': note,
      if (promo.isNotEmpty) 'promo_code': promo,
      if (name.isNotEmpty) 'customer_name': name,
      if (phone.isNotEmpty) 'customer_phone': phone,
      if (_pickupAt != null) 'pickup_at': AppTime.isoWib(_pickupAt!),
      if (withPayment) 'payment_method': _payment.name,
    };
  }

  void _scheduleQuote() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _requestQuote);
  }

  /// Galat kolom promo/waktu ambil → inline. false bila tidak ada yang cocok.
  bool _applyFieldErrors(ApiException e) {
    _promoError = e.field('promo_code') ??
        (e.code == 'PROMO_INVALID' ? e.message : null);
    _pickupAtError = e.field('pickup_at');
    return _promoError != null || _pickupAtError != null;
  }

  Future<void> _requestQuote() async {
    if (_pickupPointId == null || !mounted) return;
    setState(() {
      _quoting = true;
      _quoteError = null;
      _promoError = null;
      _pickupAtError = null;
    });
    try {
      final quote = await _api.quote(_body());
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _quoting = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _quoting = false;
        if (!_applyFieldErrors(e)) _quoteError = e.message;
      });
    }
  }

  int _minQty(CartLine line) {
    final m = _menu;
    if (m == null || m.card.id != line.menuId) return 1;
    return m.minOrderQty < 1 ? 1 : m.minOrderQty;
  }

  int? _maxQty(CartLine line) {
    final m = _menu;
    if (m == null || m.card.id != line.menuId || m.isPreorder) return null;
    return m.card.available;
  }

  void _changeQty(CartLine line, int delta) {
    final next = line.qty + delta;
    final max = _maxQty(line);
    if (next < _minQty(line) || (max != null && next > max)) return;
    setState(() => line.qty = next);
    _scheduleQuote();
  }

  Future<void> _pickPickupPoint() async {
    final picked = await Navigator.push<PickupPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => PickupPointPickerScreen(
          selectedId: _pickupPointId,
          points: _pickupPoints,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _pickupPointId = picked.id);
    _scheduleQuote();
  }

  Future<void> _pickPickupAt() async {
    final now = DateTime.now();
    final days = (_menu?.preorderDays ?? 0) > 0 ? _menu!.preorderDays : 30;
    final current = _pickupAt;
    final initial = current != null && !current.isBefore(now)
        ? current
        : now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(Duration(days: days < 1 ? 1 : days)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          current ?? DateTime(now.year, now.month, now.day, 10)),
    );
    if (time == null || !mounted) return;
    setState(() {
      _pickupAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _pickupAtError = null;
    });
    _scheduleQuote();
  }

  /// Jam dinding yang dipilih pengguna (WIB), tanpa konversi zona perangkat.
  static String _wall(DateTime d) {
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(d.day)}/${dd(d.month)}/${d.year} ${dd(d.hour)}.${dd(d.minute)} WIB';
  }

  void _confirm() {
    final total = _quote?.total;
    if (total == null) return;
    AppModalDialog.showPaymentConfirmation(
      context,
      total: total,
      onConfirm: _submit,
    );
  }

  Future<void> _submit() async {
    final body = _body(withPayment: true);
    final encoded = jsonEncode(body);
    if (encoded != _idemBody) {
      _idemBody = encoded;
      _idemKey = uuidV4();
    }
    setState(() => _submitting = true);
    try {
      final order = await _api.createOrder(body, _idemKey!);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.payment,
          arguments: order.code);
    } on ApiException catch (e) {
      if (!mounted) return;
      var inline = false;
      setState(() {
        _submitting = false;
        inline = _applyFieldErrors(e);
      });
      if (!inline) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              e.field('customer_phone') ?? e.field('items') ?? e.message),
        ));
      }
    }
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
      );

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Checkout', style: AppTextStyles.h3.copyWith(fontSize: 18)),
    );
    if (_lines.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: Center(
          child: Text('Tidak ada menu untuk dipesan.',
              style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final quote = _quote;
    final canSubmit = quote != null &&
        !_quoting &&
        !_submitting &&
        _quoteError == null &&
        _promoError == null &&
        _pickupAtError == null &&
        _pickupPointId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStoreBanner(),
              const SizedBox(height: 16),
              for (final line in _lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildItemCard(line),
                ),
              const SizedBox(height: 12),
              _sectionLabel('DATA PEMESAN'),
              const SizedBox(height: 10),
              _OrderField(label: 'Nama Lengkap', controller: _nameController),
              const SizedBox(height: 12),
              _OrderField(
                label: 'Nomor WhatsApp',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                hint: '08xxxxxxxxxx',
              ),
              const SizedBox(height: 12),
              _OrderField(
                label: 'Catatan untuk penjual (opsional)',
                controller: _noteController,
                fillColor: AppColors.secondaryBg,
                lines: 2,
                action: TextInputAction.done,
                hint: 'Contoh: sambal dipisah',
              ),
              const SizedBox(height: 22),
              _sectionLabel('PENGAMBILAN'),
              const SizedBox(height: 10),
              _buildPickupCard(),
              if (_needsPickupAt) ...[
                const SizedBox(height: 12),
                _buildPickupAtCard(),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel('METODE PEMBAYARAN'),
                  _pill('Auto-Verifikasi'),
                ],
              ),
              const SizedBox(height: 10),
              for (final option in _paymentOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PaymentMethodTile(
                    option: option,
                    selected: _payment == option.method,
                    onTap: () => setState(() => _payment = option.method),
                  ),
                ),
              const SizedBox(height: 6),
              _sectionLabel('KODE PROMO'),
              const SizedBox(height: 10),
              _OrderField(
                label: 'Kode promo (opsional)',
                controller: _promoController,
                hint: 'Contoh: KK10',
                action: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                errorText: _promoError,
                onChanged: (_) => _scheduleQuote(),
                trailing: _promoController.text.isNotEmpty && _promoError == null && quote != null && quote.discount > 0
                    ? Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                    : null,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(quote),
            ],
          ),
        ),
      ),
      // bottomNavigationBar agar area scroll menyesuaikan tinggi tombol.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.6)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: PrimaryButton(
              text: quote == null
                  ? 'Proses Pembayaran'
                  : 'Bayar ${AppCurrency.format(quote.total)}',
              isLoading: _submitting,
              onPressed: canSubmit ? _confirm : null,
              gradient: canSubmit ? AppColors.primaryGradient : null,
              backgroundColor: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Sections ----------

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        fontSize: 11,
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.successDark,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildStoreBanner() {
    final m = _menu;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.primaryDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m?.card.merchant.businessName ?? 'Memuat toko…',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kuota dikunci saat pesanan dibuat. Selesaikan pembayaran sebelum waktunya habis.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(CartLine line) {
    final quoted =
        _quote?.items.where((q) => q.menuId == line.menuId).firstOrNull;
    final unit = quoted?.unitPrice ?? line.unitPrice;
    final max = _maxQty(line);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Row(
        children: [
          MenuImage(line.imageUrl, width: 64, height: 64, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(fontSize: 15),
                ),
                if (line.optionNames.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    line.optionNames.join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: AppCurrency.format(unit),
                        style: AppTextStyles.price.copyWith(fontSize: 14),
                      ),
                      TextSpan(
                        text: ' / ${_menu?.card.unitLabel ?? 'porsi'}',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (max != null && max > 0)
                  Text(
                    'Tersisa $max',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStepper(line),
        ],
      ),
    );
  }

  Widget _buildStepper(CartLine line) {
    Widget button(String label, Color color, VoidCallback onTap) {
      return InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('-', AppColors.textPrimary, () => _changeQty(line, -1)),
          Text('${line.qty}', style: AppTextStyles.h4.copyWith(fontSize: 14)),
          button('+', AppColors.primary, () => _changeQty(line, 1)),
        ],
      ),
    );
  }

  Widget _buildPickupCard() {
    final point =
        _pickupPoints.where((p) => p.id == _pickupPointId).firstOrNull;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickupPoints.isEmpty ? null : _pickPickupPoint,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Titik Temu',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_pickupPoints.length > 1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ganti',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFE53935),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point?.name ??
                            (_menu == null
                                ? 'Memuat titik temu…'
                                : 'Toko belum punya titik temu'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (point?.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          point!.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupAtCard() {
    final error = _pickupAtError;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickPickupAt,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: error != null ? AppColors.danger : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waktu Ambil (Pre-order)',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pickupAt == null ? 'Pilih tanggal & jam' : _wall(_pickupAt!),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _pickupAt == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      error,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.danger,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Quote? quote) {
    final totalQty = _lines.fold<int>(0, (s, l) => s + l.qty);
    Widget row(String label, String value,
        {Color? valueColor, bool bold = false}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: _tabular,
              color: valueColor,
              fontSize: bold ? 16 : null,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote == null && _quoteError == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (quote != null) ...[
            row('Subtotal ($totalQty ${_menu?.card.unitLabel ?? 'porsi'})',
                AppCurrency.format(quote.subtotal)),
            if (quote.discount > 0) ...[
              const SizedBox(height: 8),
              row('Diskon', '- ${AppCurrency.format(quote.discount)}',
                  valueColor: AppColors.success),
            ],
            const SizedBox(height: 8),
            row(
              'Biaya Layanan',
              quote.serviceFee == 0
                  ? 'Gratis'
                  : AppCurrency.format(quote.serviceFee),
              valueColor: quote.serviceFee == 0 ? AppColors.success : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.cardBorder, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Pembayaran',
                    style: AppTextStyles.h4.copyWith(fontSize: 16)),
                Text(
                  AppCurrency.format(quote.total),
                  style: AppTextStyles.price.copyWith(
                    fontSize: 18,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
            for (final w in quote.warnings) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (_quoteError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _quoteError!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _menu == null
                      ? () => _init(
                          context.read<SessionProvider>().user?.favoritePickupPointId)
                      : _requestQuote,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ],
          if (_quoting && quote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Menghitung ulang…',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kolom data pemesan: label kecil di dalam kotak, border berubah saat fokus.
class _OrderField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction action;
  final Widget? trailing;
  final Color? fillColor;
  final int lines;
  final String? hint;
  final String? errorText;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const _OrderField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.action = TextInputAction.next,
    this.trailing,
    this.fillColor,
    this.lines = 1,
    this.hint,
    this.errorText,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  State<_OrderField> createState() => _OrderFieldState();
}

class _OrderFieldState extends State<_OrderField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final error = widget.errorText;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: widget.fillColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: error != null
                ? AppColors.danger
                : focused
                    ? AppColors.primary
                    : AppColors.cardBorder,
            width: focused ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: widget.lines > 1
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.action,
                    textCapitalization: widget.textCapitalization,
                    minLines: widget.lines,
                    maxLines: widget.lines,
                    onChanged: widget.onChanged,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.hint ?? '',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(
                error,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.danger,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
