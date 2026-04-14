import 'package:flutter/material.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../data/repositories/home_repository.dart';
import '../../../milk/data/repositories/milk_repository.dart';

class HomeFeaturePage extends StatefulWidget {
  const HomeFeaturePage({
    super.key,
    required this.featureKey,
    required this.role,
    required this.homeRepository,
    required this.milkRepository,
  });

  final String featureKey;
  final String role;
  final HomeRepository homeRepository;
  final MilkRepository milkRepository;

  @override
  State<HomeFeaturePage> createState() => _HomeFeaturePageState();
}

class _HomeFeaturePageState extends State<HomeFeaturePage> {
  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  Map<String, dynamic> _summary = <String, dynamic>{};

  final _inputA = TextEditingController();
  final _inputB = TextEditingController();
  String _issueType = 'not_delivered';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputA.dispose();
    _inputB.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.featureKey) {
      case 'seller_requests':
        return 'Pending Join Requests';
      case 'seller_capacity':
        return 'Capacity Controls';
      case 'seller_issues':
        return 'Delivery Issues';
      case 'seller_pauses':
        return 'Active Delivery Pauses';
      case 'seller_billing':
        return 'Seller Billing Summary';
      case 'customer_join':
        return 'My Join Requests';
      case 'customer_issues':
        return 'Report Delivery Issue';
      case 'customer_pauses':
        return 'Pause / Resume Delivery';
      case 'customer_billing':
        return 'Customer Billing Summary';
      case 'notifications':
        return 'Notifications';
      default:
        return 'Feature';
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      switch (widget.featureKey) {
        case 'seller_requests':
          final requests = await widget.homeRepository.fetchSellerJoinRequests(
            status: 'pending',
            sortBy: 'newest',
          );
          _items = requests
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'title': item.customerName ?? 'Customer',
                  'status': item.status,
                  'distanceKm': item.distanceKm,
                  'requestedQuantityLitres': item.requestedQuantityLitres,
                  'customerArea': item.customerArea,
                  'createdAt': item.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false);
          break;
        case 'seller_capacity':
          _summary = await widget.homeRepository.fetchSellerCapacity();
          _inputA.text = (_summary['maxActiveCustomers']?.toString() ?? '')
              .trim();
          _inputB.text = (_summary['maxLitresPerDay']?.toString() ?? '').trim();
          break;
        case 'seller_issues':
          _items = await widget.homeRepository.fetchSellerDeliveryIssues(
            status: 'open',
          );
          break;
        case 'seller_pauses':
          _items = await widget.homeRepository.fetchSellerDeliveryPauses();
          break;
        case 'seller_billing':
          _summary = await widget.milkRepository.fetchSellerMonthlySummary();
          break;
        case 'customer_join':
          final requests = await widget.homeRepository.fetchMyJoinRequests();
          _items = requests
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'title': item.sellerName ?? 'Seller',
                  'status': item.status,
                  'respondedAt': item.respondedAt?.toIso8601String(),
                  'rejectionReason': item.rejectionReason,
                  'createdAt': item.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false);
          break;
        case 'customer_issues':
          _items = await widget.homeRepository.fetchMyDeliveryIssues();
          break;
        case 'customer_pauses':
          _items = await widget.homeRepository.fetchMyDeliveryPauses();
          break;
        case 'customer_billing':
          _summary = await widget.milkRepository.fetchMyMonthlySummary();
          break;
        case 'notifications':
          final feed = await widget.homeRepository.fetchNotifications();
          _items = feed.items
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'title': item.title,
                  'message': item.message,
                  'isRead': item.isRead,
                  'createdAt': item.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false);
          _summary = <String, dynamic>{'unreadCount': feed.unreadCount};
          break;
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
      }
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _saveCapacity() async {
    setState(() => _saving = true);
    try {
      final maxActive = _inputA.text.trim().isEmpty
          ? null
          : int.tryParse(_inputA.text.trim());
      final maxLitres = _inputB.text.trim().isEmpty
          ? null
          : double.tryParse(_inputB.text.trim());

      _summary = await widget.homeRepository.updateSellerCapacity(
        maxActiveCustomers: maxActive,
        maxLitresPerDay: maxLitres,
      );
      _showMessage('Capacity saved.');
      if (mounted) {
        setState(() => _saving = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
      }
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _resolveIssue(String issueId) async {
    try {
      await widget.homeRepository.resolveSellerDeliveryIssue(issueId: issueId);
      await _load();
      _showMessage('Issue resolved.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _resumePause(String pauseId) async {
    try {
      if (widget.featureKey == 'seller_pauses') {
        await widget.homeRepository.resumeSellerDeliveryPause(pauseId);
      } else {
        await widget.homeRepository.resumeMyDeliveryPause(pauseId);
      }
      await _load();
      _showMessage('Pause resumed.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _reportIssue() async {
    try {
      await widget.homeRepository.reportDeliveryIssue(
        issueType: _issueType,
        description: _inputA.text,
      );
      _inputA.clear();
      await _load();
      _showMessage('Issue submitted.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _createPause() async {
    try {
      await widget.homeRepository.createDeliveryPause(
        startDateKey: _inputA.text.trim(),
        endDateKey: _inputB.text.trim(),
      );
      await _load();
      _showMessage('Pause created.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  String _prettyDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '-';
    }

    try {
      final parsed = DateTime.parse(raw).toLocal();
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      final hh = parsed.hour.toString().padLeft(2, '0');
      final min = parsed.minute.toString().padLeft(2, '0');
      return '${parsed.year}-$mm-$dd  $hh:$min';
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
      case 'resolved':
      case 'active':
        return AppColors.success;
      case 'pending':
      case 'open':
        return AppColors.warning;
      case 'rejected':
      case 'paused':
      case 'expired':
        return AppColors.danger;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, Object? value, {IconData? icon}) {
    final display = value == null ? '-' : value.toString();
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text('$label: $display'),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSellerCapacity() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Capacity Snapshot',
          subtitle:
              'Set safe operating limits for approvals and daily dispatch.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip(
                  'Max active customers',
                  _summary['maxActiveCustomers'],
                ),
                _metricChip('Max litres/day', _summary['maxLitresPerDay']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _sectionTitle('Update Limits'),
        const SizedBox(height: 8),
        TextField(
          controller: _inputA,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Max active customers',
            helperText: 'Leave empty to remove cap',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _inputB,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Max litres/day',
            helperText: 'Leave empty to remove cap',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _saving ? null : _saveCapacity,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save capacity settings'),
        ),
      ],
    );
  }

  Widget _buildSellerRequests() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Pending Requests',
          subtitle:
              'Newest requests first. Open full request flow from dashboard.',
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            description: 'New customer requests will appear here.',
          ),
        ..._items.map((item) {
          final status = item['status']?.toString() ?? 'pending';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(status.toUpperCase()),
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(status).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metricChip(
                        'Litres',
                        item['requestedQuantityLitres'],
                        icon: Icons.opacity_outlined,
                      ),
                      _metricChip(
                        'Distance',
                        '${item['distanceKm'] ?? '-'} km',
                        icon: Icons.route_outlined,
                      ),
                      _metricChip(
                        'Area',
                        item['customerArea'] ?? '-',
                        icon: Icons.place_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Requested: ${_prettyDate(item['createdAt']?.toString())}',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSellerIssues() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Open Delivery Issues',
          subtitle:
              'Resolve complaints to keep trust and delivery quality high.',
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.task_alt_rounded,
            title: 'No open issues',
            description: 'You are all clear for now.',
          ),
        ..._items.map((issue) {
          final issueId = issue['id']?.toString() ?? '';
          final status = issue['status']?.toString() ?? 'open';
          final issueType = issue['issueType']?.toString() ?? '-';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issue['customerName']?.toString() ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(issueType.replaceAll('_', ' ')),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(status.toUpperCase()),
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(status).withValues(alpha: 0.4),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(issue['description']?.toString() ?? '-'),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: issueId.trim().isEmpty
                          ? null
                          : () => _resolveIssue(issueId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark resolved'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPauses({required bool customerMode}) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          customerMode ? 'Pause Planner' : 'Customer Delivery Pauses',
          subtitle: customerMode
              ? 'Set a start and end date in YYYY-MM-DD format.'
              : 'Track active and historical customer pauses.',
        ),
        const SizedBox(height: 8),
        if (customerMode)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _inputA,
                    decoration: const InputDecoration(
                      labelText: 'Start date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inputB,
                    decoration: const InputDecoration(
                      labelText: 'End date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _createPause,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Create pause'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.event_available_outlined,
            title: 'No pauses found',
            description: customerMode
                ? 'Your created pauses will appear here.'
                : 'Customer pauses will appear here when active or scheduled.',
          ),
        ..._items.map((pause) {
          final status = pause['status']?.toString() ?? '-';
          final pauseId = pause['id']?.toString() ?? '';
          final isActive = status.trim().toLowerCase() == 'active';
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              title: Text(
                '${pause['startDateKey'] ?? '-'} to ${pause['endDateKey'] ?? '-'}',
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(status.toUpperCase()),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _statusColor(
                        status,
                      ).withValues(alpha: 0.14),
                      side: BorderSide(
                        color: _statusColor(status).withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: isActive
                  ? OutlinedButton(
                      onPressed: pauseId.trim().isEmpty
                          ? null
                          : () => _resumePause(pauseId),
                      child: const Text('Resume'),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBilling() {
    final month = _summary['month']?.toString();
    final summaryMap = _summary['summary'] is Map<String, dynamic>
        ? _summary['summary'] as Map<String, dynamic>
        : _summary;

    final customerRows =
        (_summary['customers'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Monthly Summary',
          subtitle: month == null || month.trim().isEmpty
              ? 'Current cycle overview'
              : 'Month: $month',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summaryMap.entries
                  .map((entry) => _metricChip(entry.key, entry.value))
                  .toList(growable: false),
            ),
          ),
        ),
        if (customerRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle('Customer Breakdown'),
          const SizedBox(height: 8),
          ...customerRows.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['customerName']?.toString() ??
                          item['title']?.toString() ??
                          'Customer',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.entries
                          .where(
                            (entry) =>
                                entry.key != 'customerName' &&
                                entry.key != 'title' &&
                                entry.key != 'id',
                          )
                          .map((entry) => _metricChip(entry.key, entry.value))
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomerIssues() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Report an Issue',
          subtitle:
              'Share what happened so your seller can resolve it quickly.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _issueType,
                  decoration: const InputDecoration(
                    labelText: 'Issue type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'not_delivered',
                      child: Text('Not Delivered'),
                    ),
                    DropdownMenuItem(
                      value: 'late_delivery',
                      child: Text('Late Delivery'),
                    ),
                    DropdownMenuItem(
                      value: 'wrong_quantity',
                      child: Text('Wrong Quantity'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _issueType = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inputA,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _reportIssue,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Submit issue'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Recent Reports'),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.mark_chat_unread_outlined,
            title: 'No issues reported yet',
            description: 'Your issue history will appear here.',
          ),
        ..._items.map((item) {
          final status = item['status']?.toString() ?? '-';
          final issueType = item['issueType']?.toString() ?? '-';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issueType.replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(status.toUpperCase()),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(status).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item['description']?.toString() ?? '-'),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotifications() {
    final unreadCount = _summary['unreadCount'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Notification Feed',
          subtitle: 'Recent platform and delivery updates.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text('Unread notifications: $unreadCount')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.notifications_off_outlined,
            title: 'No notifications yet',
            description: 'You are up to date.',
          ),
        ..._items.map((item) {
          final isRead = item['isRead'] == true;
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              leading: Icon(
                isRead
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
              ),
              title: Text(item['title']?.toString() ?? 'Notification'),
              subtitle: Text(
                '${item['message'] ?? ''}\n${_prettyDate(item['createdAt']?.toString())}',
              ),
              isThreeLine: true,
              trailing: Chip(
                label: Text(isRead ? 'READ' : 'NEW'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomerJoinRequests() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'My Join Requests',
          subtitle: 'Track request status across sellers.',
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.storefront_outlined,
            title: 'No join requests yet',
            description: 'Start by exploring nearby sellers on home.',
          ),
        ..._items.map((item) {
          final status = item['status']?.toString() ?? '-';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? 'Seller',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(status.toUpperCase()),
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(status).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Created: ${_prettyDate(item['createdAt']?.toString())}',
                  ),
                  if ((item['respondedAt']?.toString() ?? '').trim().isNotEmpty)
                    Text(
                      'Responded: ${_prettyDate(item['respondedAt']?.toString())}',
                    ),
                  if ((item['rejectionReason']?.toString() ?? '')
                      .trim()
                      .isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Reason: ${item['rejectionReason']}',
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGenericList() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing to show',
            description: 'This section will update when data is available.',
          ),
        ..._items.map(
          (item) => Card(
            child: ListTile(
              title: Text(
                item['title']?.toString() ??
                    item['customerName']?.toString() ??
                    item['sellerName']?.toString() ??
                    item['id']?.toString() ??
                    'Item',
              ),
              subtitle: Text(
                item.entries
                    .where((entry) => entry.key != 'title' && entry.key != 'id')
                    .take(3)
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join('  |  '),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (widget.featureKey) {
      case 'seller_capacity':
        return _buildSellerCapacity();

      case 'seller_requests':
        return _buildSellerRequests();

      case 'seller_issues':
        return _buildSellerIssues();

      case 'seller_pauses':
        return _buildPauses(customerMode: false);

      case 'customer_pauses':
        return _buildPauses(customerMode: true);

      case 'seller_billing':
      case 'customer_billing':
        return _buildBilling();

      case 'customer_issues':
        return _buildCustomerIssues();

      case 'customer_join':
        return _buildCustomerJoinRequests();

      case 'notifications':
        return _buildNotifications();

      default:
        return _buildGenericList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _buildBody(),
    );
  }
}
