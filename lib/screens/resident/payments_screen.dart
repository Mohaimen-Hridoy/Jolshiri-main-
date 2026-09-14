import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with WidgetsBindingObserver {
  bool _processing = false;
  bool _loading = false;
  // Set true right before we send the resident out to the Stripe
  // checkout page in their browser, so that when they come back to the app
  // we know to re-fetch and pick up the status the gateway's callback set.
  bool _awaitingGatewayReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingGatewayReturn) {
      _awaitingGatewayReturn = false;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final payments = await BackendRepository.fetchMyPayments();
      if (mounted && payments.isNotEmpty) {
        setState(() { MockData.payments..clear()..addAll(payments); });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duePayments = MockData.payments.where((payment) => payment.status == PaymentStatus.due).toList();
    final paidPayments = MockData.payments.where((payment) => payment.status == PaymentStatus.paid).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Stripe Payments')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.parade, AppColors.paradeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PAYMENT FRONTEND', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.brass)),
                      const SizedBox(height: 6),
                      const Text(
                        'Consultation and agreement fees',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stripe-powered payment flow for residents, renters, and plot owners.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.payments_outlined, color: AppColors.brass, size: 36),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Due now',
                  value: duePayments.length.toString(),
                  icon: Icons.pending_actions_outlined,
                  color: AppColors.brass,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Paid',
                  value: paidPayments.length.toString(),
                  icon: Icons.verified_outlined,
                  color: AppColors.lake,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available gateway methods', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(label: 'Card', color: AppColors.parade),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            eyebrow: 'Ready to pay',
            title: 'Outstanding requests',
          ),
          const SizedBox(height: 12),
          if (duePayments.isEmpty)
            const EmptyState(
              icon: Icons.credit_score_outlined,
              title: 'No payment due',
              message: 'When a consultation or agreement fee is issued, it will show up here.',
            )
          else
            ...duePayments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PaymentCard(
                  payment: payment,
                  processing: _processing,
                  onPay: () => _pay(payment),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const SectionHeader(
            eyebrow: 'Payment history',
            title: 'Recent transactions',
          ),
          const SizedBox(height: 12),
          ...MockData.payments
              .where((p) => p.status != PaymentStatus.due)
              .map(
                (payment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryCard(payment: payment),
                ),
              ),
          if (MockData.payments.every((p) => p.status == PaymentStatus.due))
            const EmptyState(
              icon: Icons.history_outlined,
              title: 'No transactions yet',
              message: 'Completed and processing payments will appear here.',
            ),
        ],
      )),
    );
  }

  Future<void> _pay(PaymentRecord payment) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm payment', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(payment.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(payment.description, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              StatusPill(label: payment.purpose.label, color: AppColors.lake),
              const SizedBox(height: 12),
              Text(payment.amount, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.parade)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Proceed via Stripe'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _processing = true;
      payment.status = PaymentStatus.processing;
    });

    // POST /api/payments/:id/pay — real backend call when this record came
    // from the backend (has an id) and the user is signed in; otherwise
    // fall back to the simulated instant-settle demo flow.
    if (payment.id != null && AuthSession.isLoggedIn) {
      try {
        final result = await BackendRepository.payPayment(payment.id!);
        if (!mounted) return;

        if (result.checkoutUrl != null) {
          // A real gateway (Stripe) is configured — send the
          // resident to the actual checkout page. Status stays PROCESSING
          // until the gateway's callback confirms it; we re-check once the
          // resident comes back to the app (see didChangeAppLifecycleState).
          setState(() {
            _processing = false;
            payment.status = result.status;
          });
          final opened = await launchUrl(
            Uri.parse(result.checkoutUrl!),
            mode: LaunchMode.externalApplication,
          );
          if (opened) {
            _awaitingGatewayReturn = true;
            if (mounted) showActionSnackBar(context, 'Complete the payment in your browser');
          } else if (mounted) {
            showActionSnackBar(context, 'Could not open the payment page');
          }
          return;
        }

        setState(() {
          _processing = false;
          payment.status = result.status;
        });
        showActionSnackBar(
          context,
          result.status == PaymentStatus.paid ? 'Payment completed successfully' : 'Payment is processing',
        );
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _processing = false;
          payment.status = PaymentStatus.due;
        });
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // fall through to the offline demo flow below
      }
    }

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _processing = false;
      payment.status = PaymentStatus.paid;
    });
    showActionSnackBar(context, 'Payment completed successfully');
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentRecord payment;
  final bool processing;
  final VoidCallback onPay;

  const _PaymentCard({
    required this.payment,
    required this.processing,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(payment.title, style: Theme.of(context).textTheme.titleMedium)),
                StatusPill(label: payment.purpose.label, color: AppColors.brass),
              ],
            ),
            const SizedBox(height: 8),
            Text(payment.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  payment.amount,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.parade),
                ),
                const Spacer(),
                Text(payment.reference, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: processing ? null : onPay,
                child: processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Pay now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PaymentRecord payment;

  const _HistoryCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(payment.title),
        subtitle: Text('${payment.reference} · ${payment.description}'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(payment.amount, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            StatusPill(label: payment.status.label, color: _statusColor(payment.status)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(PaymentStatus status) => switch (status) {
        PaymentStatus.due => AppColors.brass,
        PaymentStatus.processing => AppColors.lake,
        PaymentStatus.paid => AppColors.parade,
        PaymentStatus.failed => AppColors.brick,
      };
}
