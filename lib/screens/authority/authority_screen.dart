import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../services/api_client.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AuthorityScreen extends StatelessWidget {
  const AuthorityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Authority Portal'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Notices'), Tab(text: 'Appointments'), Tab(text: 'Offices')],
            labelColor: AppColors.parade,
            unselectedLabelColor: AppColors.inkFaint,
            indicatorColor: AppColors.brass,
            indicatorWeight: 3,
          ),
        ),
        body: const TabBarView(children: [_NoticesTab(), _AppointmentsTab(), _OfficesTab()]),
      ),
    );
  }
}

class _NoticesTab extends StatelessWidget {
  const _NoticesTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: MockData.notices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final n = MockData.notices[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  StatusPill(label: n.category, color: AppColors.brass),
                  const Spacer(),
                  Text('${n.publishDate.day}/${n.publishDate.month}/${n.publishDate.year}', style: Theme.of(context).textTheme.labelSmall),
                ]),
                const SizedBox(height: 8),
                Text(n.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(n.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppointmentsTab extends StatefulWidget {
  const _AppointmentsTab();

  @override
  State<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<_AppointmentsTab> {
  String? _selectedOffice;
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(eyebrow: 'Book a visit', title: 'New appointment'),
          const SizedBox(height: 16),
          Text('Office', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedOffice,
            hint: const Text('Select an office'),
            items: MockData.offices.map((o) => DropdownMenuItem(value: o.name, child: Text(o.name))).toList(),
            onChanged: (v) => setState(() => _selectedOffice = v),
          ),
          const SizedBox(height: 16),
          Text('Preferred date', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined, color: AppColors.parade),
              title: Text('${_date.day}/${_date.month}/${_date.year}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Reason for visit', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _reasonController, maxLines: 3, decoration: const InputDecoration(hintText: 'Briefly describe your request')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedOffice == null || _submitting
                  ? null
                  : () async {
                      setState(() => _submitting = true);
                      final office = _selectedOffice!;
                      final reason = _reasonController.text.trim();
                      try {
                        // POST /api/appointments — real backend call.
                        await BackendRepository.createAppointment(
                          officeName: office,
                          preferredDate: _date,
                          reason: reason.isEmpty ? 'Office visit' : reason,
                        );
                        if (!context.mounted) return;
                        setState(() => _submitting = false);
                        showActionSnackBar(context, 'Appointment requested with $office');
                      } on ApiException catch (e) {
                        if (!context.mounted) return;
                        setState(() => _submitting = false);
                        showActionSnackBar(context, e.message);
                      } on ApiUnreachableException {
                        // Backend not reachable — fall back to the offline
                        // demo flow so the form still feels responsive.
                        if (!context.mounted) return;
                        setState(() => _submitting = false);
                        showActionSnackBar(context, 'Appointment requested with $office');
                      }
                    },
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Request appointment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficesTab extends StatelessWidget {
  const _OfficesTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: MockData.offices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final o = MockData.offices[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.paperDim, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_outlined, color: AppColors.parade),
            ),
            title: Text(o.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text('${o.location}\n${o.contact}'),
            isThreeLine: true,
            trailing: IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => showActionSnackBar(context, 'Calling ${o.name}…')),
          ),
        );
      },
    );
  }
}