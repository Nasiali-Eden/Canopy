import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHECKOUT SCREEN
// M-Pesa native — no card, no login wall. One screen closes the loop.
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceCheckoutScreen extends StatefulWidget {
  final String listingId;
  final String listingTitle;
  final double priceKes;
  final String sellerName;
  final String collectorName;
  final double royaltyKes;

  const MarketplaceCheckoutScreen({
    super.key,
    required this.listingId,
    required this.listingTitle,
    required this.priceKes,
    required this.sellerName,
    required this.collectorName,
    required this.royaltyKes,
  });

  @override
  State<MarketplaceCheckoutScreen> createState() =>
      _MarketplaceCheckoutScreenState();
}

class _MarketplaceCheckoutScreenState
    extends State<MarketplaceCheckoutScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _agreed = false;
  bool _processing = false;
  bool _success = false;

  late AnimationController _successAnim;
  late Animation<double> _scaleFade;

  // Fee breakdown
  double get _platformFee => widget.priceKes * 0.05;
  double get _total => widget.priceKes + 150; // flat delivery placeholder
  double get _sellerReceives => widget.priceKes - _platformFee;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleFade = CurvedAnimation(
        parent: _successAnim, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _successAnim.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      _snack('Please confirm you agree to the terms');
      return;
    }

    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2)); // M-Pesa STK push
    if (!mounted) return;

    setState(() {
      _processing = false;
      _success = true;
    });
    _successAnim.forward();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_success) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppTheme.darkGreen),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Complete Your Purchase',
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderSummary(),
                  const SizedBox(height: 16),
                  _buildRoyaltyCard(),
                  const SizedBox(height: 16),
                  _buildPaymentSection(),
                  const SizedBox(height: 16),
                  _buildDeliverySection(),
                  const SizedBox(height: 16),
                  _buildBreakdown(),
                  const SizedBox(height: 16),
                  _buildAgreement(),
                ],
              ),
            ),
            // Sticky CTA
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPayButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Order summary ────────────────────────────────────────────────────────────

  Widget _buildOrderSummary() {
    return _Card(
      child: Row(children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shopping_bag_outlined,
              size: 32, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.listingTitle,
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 11, color: AppTheme.accent),
                const SizedBox(width: 3),
                Text(
                  'by ${widget.sellerName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.darkGreen.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'KSh ${widget.priceKes.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Royalty card — the distinguishing moment ─────────────────────────────────

  Widget _buildRoyaltyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.tertiary.withOpacity(0.9), AppTheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.tertiary.withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Collector Royalty',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                'When this payment completes, ${widget.collectorName} — who collected the material this object is made from — receives KSh ${widget.royaltyKes.toStringAsFixed(0)} automatically to their M-Pesa.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              children: [
                Text(
                  'KSh ${widget.royaltyKes.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'to collector',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  // ── Payment section ───────────────────────────────────────────────────────────

  Widget _buildPaymentSection() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CheckoutSectionLabel(
              icon: Icons.phone_android_outlined,
              label: 'M-Pesa Number',
              color: AppTheme.primary),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: _inputDecoration(
              label: 'e.g. 0712 345 678',
              icon: Icons.phone_android_outlined,
              color: AppTheme.primary,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'M-Pesa number is required';
              }
              if (v.trim().length < 9) return 'Enter a valid number';
              return null;
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  size: 13, color: AppTheme.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'You will receive an M-Pesa STK push prompt. Enter your PIN to complete.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.darkGreen.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Delivery section ──────────────────────────────────────────────────────────

  Widget _buildDeliverySection() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CheckoutSectionLabel(
              icon: Icons.local_shipping_outlined,
              label: 'Delivery',
              color: AppTheme.accent),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            style: const TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w500,
                fontSize: 14),
            decoration: _inputDecoration(
              label: 'Delivery address',
              icon: Icons.place_outlined,
              color: AppTheme.accent,
            ),
            validator: (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Delivery address is required'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _noteController,
            style: const TextStyle(
                color: AppTheme.darkGreen, fontSize: 13),
            decoration: _inputDecoration(
              label: 'Note to maker (optional)',
              icon: Icons.chat_bubble_outline,
              color: AppTheme.lightGreen,
            ),
          ),
          const SizedBox(height: 10),
          // Flat delivery fee note
          Row(children: [
            const Icon(Icons.motorcycle_outlined,
                size: 13, color: AppTheme.accent),
            const SizedBox(width: 5),
            Text(
              'Delivery within Nairobi — KSh 150 flat.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.darkGreen.withOpacity(0.5),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Breakdown ────────────────────────────────────────────────────────────────

  Widget _buildBreakdown() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CheckoutSectionLabel(
              icon: Icons.receipt_long_outlined,
              label: 'Summary',
              color: AppTheme.secondary),
          const SizedBox(height: 12),
          _BreakdownRow(
              label: widget.listingTitle,
              value: 'KSh ${widget.priceKes.toStringAsFixed(0)}',
              bold: false),
          _BreakdownRow(
              label: 'Delivery', value: 'KSh 150', bold: false),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppTheme.lightGreen.withOpacity(0.3)),
          ),
          _BreakdownRow(
              label: 'Total',
              value: 'KSh ${_total.toStringAsFixed(0)}',
              bold: true),
          const SizedBox(height: 8),
          Divider(color: AppTheme.lightGreen.withOpacity(0.15)),
          const SizedBox(height: 8),
          // Transparent breakdown
          _BreakdownRow(
              label: '↳ ${widget.sellerName} earns',
              value:
              'KSh ${_sellerReceives.toStringAsFixed(0)}',
              bold: false,
              color: AppTheme.primary),
          _BreakdownRow(
              label: '↳ ${widget.collectorName} (royalty)',
              value:
              'KSh ${widget.royaltyKes.toStringAsFixed(0)}',
              bold: false,
              color: AppTheme.tertiary),
          _BreakdownRow(
              label: '↳ Canopy platform',
              value: 'KSh ${_platformFee.toStringAsFixed(0)}',
              bold: false,
              color: AppTheme.darkGreen.withOpacity(0.4)),
        ],
      ),
    );
  }

  // ── Agreement ────────────────────────────────────────────────────────────────

  Widget _buildAgreement() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _agreed ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _agreed
                  ? AppTheme.primary
                  : AppTheme.lightGreen.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: _agreed
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'I understand that purchasing this object automatically generates a royalty payment to the collector who provided the materials, and that all payments are final.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Pay button ───────────────────────────────────────────────────────────────

  Widget _buildPayButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkGreen.withOpacity(0.4),
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'KSh ${_total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _agreed
                        ? [AppTheme.darkGreen, AppTheme.primary]
                        : [Colors.grey.shade300, Colors.grey.shade300],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _agreed
                      ? [
                    BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5)),
                  ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _processing ? null : _pay,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: _processing
                          ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white))
                          : const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_android_outlined,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Pay with M-Pesa',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Success screen ───────────────────────────────────────────────────────────

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleFade,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.darkGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 52),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Purchase Complete',
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.listingTitle} is on its way to you.',
                style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.6),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Royalty confirmation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.tertiary.withOpacity(0.3)),
                ),
                child: Column(children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_outlined,
                          color: AppTheme.tertiary, size: 16),
                      SizedBox(width: 6),
                      Text('Collector Paid',
                          style: TextStyle(
                              color: AppTheme.tertiary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.collectorName} just received KSh ${widget.royaltyKes.toStringAsFixed(0)} to their M-Pesa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.65),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // Impact summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.eco_outlined,
                        color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Your purchase diverted material that would have been lost. The loop is closed.',
                      style: TextStyle(
                        color: AppTheme.darkGreen.withOpacity(0.65),
                        fontSize: 12,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    // Pop back to shop root
                    Navigator.of(context).popUntil(
                            (route) => route.isFirst);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.darkGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Back to Market',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Input decoration ──────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(
      {required String label,
        required IconData icon,
        required Color color}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: color.withOpacity(0.7), fontSize: 13),
      filled: true,
      fillColor: color.withOpacity(0.03),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
      prefixIconConstraints:
      const BoxConstraints(minWidth: 50, minHeight: 50),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: color.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: color.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.red.shade300)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _CheckoutSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CheckoutSectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 7),
      Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.bold,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.darkGreen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? AppTheme.darkGreen : c.withOpacity(0.65),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            color: bold ? AppTheme.darkGreen : c,
          ),
        ),
      ]),
    );
  }
}