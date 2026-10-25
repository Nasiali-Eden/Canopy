// lib/HomeServices/request_service_booking_screen.dart
//
// Request a booking (SERVICES_HANDOFF §3.4): offerings chips · address note ·
// phone (+254) · preferred date · Standing service switch with the
// fee-waiver callout · message → sticky "Send request" + "Nothing is charged
// now." Success: timeline of what happens next + View my bookings.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/geo/canopy_location.dart';
import '../Models/services/service_booking.dart';
import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import '../theme/tokens/services_tokens.dart' show CanopyFees;
import 'my_service_bookings_screen.dart';
import 'service_booking_detail_screen.dart';
import 'services_ui.dart';

class RequestServiceBookingScreen extends StatefulWidget {
  final ServiceListing listing;
  const RequestServiceBookingScreen({required this.listing, super.key});

  @override
  State<RequestServiceBookingScreen> createState() => _RequestServiceBookingScreenState();
}

class _RequestServiceBookingScreenState extends State<RequestServiceBookingScreen> {
  final _message = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final Set<String> _offerings = {};
  DateTime? _date;
  late bool _standing = widget.listing.category == ServiceCategory.trashCollection;
  bool _sending = false;
  bool _failed = false;
  bool _showErrors = false;
  String? _sentId;

  @override
  void dispose() {
    _message.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? get _messageError =>
      _message.text.trim().length < 10 ? 'Describe the job in a sentence or two.' : null;
  String? get _addressError =>
      _address.text.trim().isEmpty ? 'Say where the job is.' : null;
  String? get _phoneError {
    final d = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return null;
    return d.length < 9 ? 'Enter a full phone number.' : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    if (_messageError != null || _addressError != null || _phoneError != null) return;
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      var name = user.displayName ?? '';
      if (name.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
        name = (doc.data()?['name'] as String?) ?? 'Canopy member';
      }
      final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
      final phone = digits.isEmpty
          ? null
          : '254${digits.startsWith('254') ? digits.substring(3) : digits.startsWith('0') ? digits.substring(1) : digits}';
      final l = widget.listing;
      final id = await ServiceMarketplaceService.instance.requestBooking(ServiceBooking(
        id: '',
        listingId: l.id,
        listingTitle: l.title,
        category: l.category,
        requesterUid: user.uid,
        requesterName: name,
        requesterPhone: phone,
        providerUid: l.postedByUid,
        providerName: l.orgName?.isNotEmpty == true ? l.orgName! : l.provider.shopName,
        providerOrgId: l.orgId,
        providerOrgName: l.orgName,
        serviceLocation: CanopyLocation(
          countyName: l.location.countyName,
          venue: _address.text.trim(),
        ),
        addressNote: _address.text.trim(),
        preferredDate: _date,
        isRecurring: _standing,
        requestMessage: _message.text.trim(),
        requestedOfferings: _offerings.toList(),
        createdAt: DateTime.now(),
      ));
      if (mounted) setState(() => _sentId = id);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sentId != null ? _success() : _form();
  }

  Widget _form() {
    final p = context.canopy;
    final l = widget.listing;
    final provider = l.orgName?.isNotEmpty == true ? l.orgName! : l.provider.shopName;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Request a booking'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
        children: [
          CanopyCard(
            padding: const EdgeInsets.all(CanopySpace.s12),
            child: Row(
              children: [
                CategoryGlyph(l.category, size: 24),
                const SizedBox(width: CanopySpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                      Text(provider, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                    ],
                  ),
                ),
                PriceDisplay(l.pricing, fontSize: 13),
              ],
            ),
          ),
          if (l.offerings.isNotEmpty) ...[
            const SizedBox(height: CanopySpace.section),
            Text('What do you need?', style: CanopyType.label.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s4),
            Wrap(
              spacing: CanopySpace.s8,
              children: [
                for (final o in l.offerings)
                  CanopyFilterChip(
                    label: ServiceCategory.offeringLabel(o),
                    selected: _offerings.contains(o),
                    onTap: () => setState(
                        () => _offerings.contains(o) ? _offerings.remove(o) : _offerings.add(o)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Where is the job?',
            hint: 'Estate, street, house or landmark',
            controller: _address,
            error: _showErrors ? _addressError : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField.phone(
            label: 'Phone (optional)',
            controller: _phone,
            helper: 'Shared with the provider so they can reach you.',
            error: _showErrors ? _phoneError : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyPickerField(
            label: 'Preferred date',
            value: _date == null ? null : serviceDate(_date!),
            placeholder: 'Any time',
            icon: Icons.calendar_today_outlined,
            onTap: _pickDate,
          ),
          const SizedBox(height: CanopySpace.s8),
          CanopySwitchRow(
            title: 'Standing service',
            caption: 'A regular arrangement, e.g. weekly collection',
            value: _standing,
            onChanged: (v) => setState(() => _standing = v),
          ),
          CanopyCallout(
            kind: _standing ? CalloutKind.success : CalloutKind.info,
            text: _standing
                ? 'No booking fee on standing services — you pay only the agreed price.'
                : 'A ${CanopyFees.ksh(CanopyFees.bookingFeeKsh)} booking fee is added when you pay. Standing services don\'t have one.',
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Describe the job',
            hint: 'What needs doing, how much, anything the provider should know',
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 800,
            error: _showErrors ? _messageError : null,
            onChanged: (_) => setState(() {}),
          ),
          if (_failed) ...[
            const SizedBox(height: CanopySpace.s8),
            const CanopyCallout(
                kind: CalloutKind.danger,
                text: "Your request didn't send. Nothing was lost — try again."),
          ],
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
            label: _failed ? 'Try again' : 'Send request',
            expand: true,
            loading: _sending,
            onPressed: _submit),
        Text('Nothing is charged now.',
            textAlign: TextAlign.center, style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ]),
    );
  }

  Widget _success() {
    final p = context.canopy;
    final l = widget.listing;
    final provider = l.orgName?.isNotEmpty == true ? l.orgName! : l.provider.shopName;
    return CanopyScaffold(
      appBar: canopyAppBar(context, showBack: false, actions: [
        CanopyIconButton(
            icon: Icons.close, tooltip: 'Close', onPressed: () => Navigator.pop(context)),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Icon(Icons.check_circle_outline, size: CanopyIconSize.empty, color: p.success),
          const SizedBox(height: CanopySpace.s12),
          Text('Request sent', style: CanopyType.display.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s4),
          Text('$provider will look at your job and send a quote.',
              style: CanopyType.body.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.section),
          CanopyCard(
            child: CanopyTimeline(steps: [
              const TimelineStep('Request sent', state: TimelineState.done),
              TimelineStep('$provider sends a quote',
                  line: 'You\'ll get a notification', state: TimelineState.now),
              const TimelineStep('You accept the quote',
                  line: 'Then you contact each other to agree payment'),
              const TimelineStep('The job is scheduled and done'),
            ]),
          ),
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: 'View my bookings',
          expand: true,
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const MyServiceBookingsScreen())),
        ),
        CanopyButton.quiet(
          label: 'Open this request',
          expand: true,
          onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => ServiceBookingDetailScreen(bookingId: _sentId!))),
        ),
      ]),
    );
  }
}
