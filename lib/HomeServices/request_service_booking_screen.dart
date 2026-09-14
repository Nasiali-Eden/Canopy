// lib/HomeServices/request_service_booking_screen.dart
//
// Opens a ServiceBooking against a listing. No price is set here — the
// requester describes the job, the provider quotes it, and the requester
// accepts (or doesn't) on ServiceBookingDetailScreen. See
// lib/Models/services/service_booking.dart's header for the full flow and
// the fee split that only gets computed once a quote is accepted.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/geo/canopy_location.dart';
import '../Models/services/service_booking.dart';
import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../Shared/theme/app_theme.dart';
import 'service_booking_detail_screen.dart';

class RequestServiceBookingScreen extends StatefulWidget {
  final ServiceListing listing;

  const RequestServiceBookingScreen({required this.listing, super.key});

  @override
  State<RequestServiceBookingScreen> createState() =>
      _RequestServiceBookingScreenState();
}

class _RequestServiceBookingScreenState
    extends State<RequestServiceBookingScreen> {
  final _messageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _preferredDate;
  bool _isRecurring = false;
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _isRecurring = widget.listing.category == ServiceCategory.trashCollection;
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'anon';
      String requesterName = user?.displayName ?? '';
      if (requesterName.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
        requesterName = (doc.data()?['name'] as String?) ?? 'Canopy member';
      }

      final listing = widget.listing;
      final booking = ServiceBooking(
        id: '',
        listingId: listing.id,
        listingTitle: listing.title,
        category: listing.category,
        requesterUid: uid,
        requesterName: requesterName,
        requesterPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        providerUid: listing.postedByUid,
        providerName: listing.provider.shopName,
        providerOrgId: listing.orgId,
        providerOrgName: listing.orgName,
        serviceLocation: CanopyLocation(
          countyName: listing.location.countyName,
          venue: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        ),
        addressNote: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        preferredDate: _preferredDate,
        isRecurring: _isRecurring,
        requestMessage: _messageCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      final bookingId = await ServiceMarketplaceService.instance.requestBooking(booking);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceBookingDetailScreen(bookingId: bookingId),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent — the provider will send you a quote'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Request Service',
            style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(listing.category.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listing.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
                        Text(listing.pricing.display,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Label('Describe the job'),
            const SizedBox(height: 8),
            _FieldBox(
              child: TextFormField(
                controller: _messageCtrl,
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Tell the provider what you need' : null,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.darkGreen),
                decoration: InputDecoration(
                  hintText: listing.category == ServiceCategory.trashCollection
                      ? 'e.g. 4-bedroom home, weekly pickup, gate access after 8am'
                      : 'e.g. 200m² backyard, wants full redesign with irrigation',
                  hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.30)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Address / drop-off details'),
            const SizedBox(height: 8),
            _FieldBox(
              child: TextFormField(
                controller: _addressCtrl,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.darkGreen),
                decoration: InputDecoration(
                  hintText: 'Gate number, landmark, estate',
                  hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.30)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Your phone (optional)'),
            const SizedBox(height: 8),
            _FieldBox(
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.darkGreen),
                decoration: InputDecoration(
                  hintText: '07xx xxx xxx',
                  hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.30)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Preferred date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: _FieldBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppTheme.darkGreen.withOpacity(0.5)),
                      const SizedBox(width: 8),
                      Text(
                        _preferredDate == null
                            ? 'Any time / provider suggests'
                            : '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}',
                        style: const TextStyle(fontSize: 13.5, color: AppTheme.darkGreen),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Standing / recurring service',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
                        Text(
                          "Waives the requester booking fee — pick this for an ongoing "
                          'arrangement, not a one-off job.',
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.darkGreen.withOpacity(0.55), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isRecurring,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setState(() => _isRecurring = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This just sends your request — nothing is charged yet. '
                      "You'll see the provider's price and can accept or decline before anything is paid.",
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.75), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Send Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
      );
}

class _FieldBox extends StatelessWidget {
  final Widget child;
  const _FieldBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
