import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:alluwalacademyadmin/core/models/zoom_host.dart';
import 'package:alluwalacademyadmin/core/services/zoom_host_service.dart';
import 'package:intl/intl.dart';

/// Admin screen for managing Zoom host accounts.
/// Allows viewing, adding, editing, and removing Zoom hosts
/// that are used for distributing meeting creation across multiple accounts.
class ZoomHostsScreen extends StatefulWidget {
  const ZoomHostsScreen({super.key});

  @override
  State<ZoomHostsScreen> createState() => _ZoomHostsScreenState();
}

class _ZoomHostsScreenState extends State<ZoomHostsScreen> {
  List<ZoomHost> _hosts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final hosts = await ZoomHostService.listHosts();
      if (mounted) {
        setState(() {
          _hosts = hosts;
          _isLoading = false;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Failed to load hosts';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddHostDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddHostDialog(),
    );

    if (result == true) {
      _loadHosts();
    }
  }

  Future<void> _showEditHostDialog(ZoomHost host) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditHostDialog(host: host),
    );

    if (result == true) {
      _loadHosts();
    }
  }

  Future<void> _confirmRemoveHost(ZoomHost host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Zoom Host'),
        content: Text(
          'Are you sure you want to remove "${host.displayName}"?\n\n'
          'This will deactivate the host, preventing new meetings from being assigned to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ZoomHostService.removeHost(hostId: host.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Host removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadHosts();
        }
      } on FirebaseFunctionsException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Failed to remove host'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _hosts.isEmpty
                        ? _buildEmptyState()
                        : _buildHostsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.video_camera_front,
              color: Color(0xff0386FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zoom Hosts',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  'Manage Zoom accounts for meeting distribution',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showAddHostDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Host'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_camera_front_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Zoom Hosts Configured',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Zoom host accounts to enable automatic meeting distribution.\n'
              'Multiple hosts allow concurrent meetings without conflicts.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddHostDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Host'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Hosts',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHosts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostsList() {
    return RefreshIndicator(
      onRefresh: _loadHosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _hosts.length,
        itemBuilder: (context, index) {
          final host = _hosts[index];
          return _buildHostCard(host);
        },
      ),
    );
  }

  Widget _buildHostCard(ZoomHost host) {
    final isEnvFallback = host.isEnvFallback;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Priority badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${host.priority + 1}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff0386FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            host.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff111827),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isEnvFallback)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ENV FALLBACK',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                          if (!host.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'INACTIVE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        host.email,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isEnvFallback) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditHostDialog(host),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmRemoveHost(host),
                    tooltip: 'Remove',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Utilization stats
            Row(
              children: [
                _buildStatItem(
                  label: 'Max Concurrent',
                  value: '${host.maxConcurrentMeetings}',
                  icon: Icons.groups_outlined,
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  label: 'Current Meetings',
                  value: '${host.currentMeetings}',
                  icon: Icons.videocam,
                  highlight: host.currentMeetings > 0,
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  label: 'Upcoming (7 days)',
                  value: '${host.upcomingMeetings}',
                  icon: Icons.calendar_today_outlined,
                ),
                const Spacer(),
                // Utilization bar
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Utilization',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: host.utilizationPercentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            host.isAtCapacity ? Colors.red : const Color(0xff0386FF),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (host.notes != null && host.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                host.notes!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
            if (host.lastUsedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last used: ${DateFormat('MMM d, yyyy h:mm a').format(host.lastUsedAt!)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff9CA3AF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: highlight ? const Color(0xff0386FF) : const Color(0xff6B7280),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: highlight ? const Color(0xff0386FF) : const Color(0xff111827),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xff6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddHostDialog extends StatefulWidget {
  const _AddHostDialog();

  @override
  State<_AddHostDialog> createState() => _AddHostDialogState();
}

class _AddHostDialogState extends State<_AddHostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _notesController = TextEditingController();
  int _maxConcurrent = 1;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ZoomHostService.addHost(
        email: _emailController.text.trim(),
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : null,
        maxConcurrentMeetings: _maxConcurrent,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message ?? 'Failed to add host';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Zoom Host'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Zoom Email *',
                  hintText: 'zoom.host@company.com',
                  helperText: 'Must be a licensed Zoom Pro account',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name (optional)',
                  hintText: 'e.g., Main Host, Backup Host',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _maxConcurrent,
                decoration: const InputDecoration(
                  labelText: 'Max Concurrent Meetings',
                ),
                items: [1, 2, 3, 4, 5].map((n) {
                  return DropdownMenuItem(
                    value: n,
                    child: Text('$n meeting${n > 1 ? 's' : ''}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _maxConcurrent = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Internal notes about this host',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff0386FF),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Add Host'),
        ),
      ],
    );
  }
}

class _EditHostDialog extends StatefulWidget {
  final ZoomHost host;

  const _EditHostDialog({required this.host});

  @override
  State<_EditHostDialog> createState() => _EditHostDialogState();
}

class _EditHostDialogState extends State<_EditHostDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _notesController;
  late int _maxConcurrent;
  late int _priority;
  late bool _isActive;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.host.displayName);
    _notesController = TextEditingController(text: widget.host.notes ?? '');
    _maxConcurrent = widget.host.maxConcurrentMeetings;
    _priority = widget.host.priority;
    _isActive = widget.host.isActive;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ZoomHostService.updateHost(
        hostId: widget.host.id,
        displayName: _displayNameController.text.trim(),
        maxConcurrentMeetings: _maxConcurrent,
        priority: _priority,
        isActive: _isActive,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message ?? 'Failed to update host';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.host.displayName}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              // Email (read-only)
              Text(
                'Email: ${widget.host.email}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _maxConcurrent,
                decoration: const InputDecoration(
                  labelText: 'Max Concurrent Meetings',
                ),
                items: [1, 2, 3, 4, 5].map((n) {
                  return DropdownMenuItem(
                    value: n,
                    child: Text('$n meeting${n > 1 ? 's' : ''}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _maxConcurrent = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority (lower = used first)',
                ),
                items: List.generate(10, (i) => i).map((n) {
                  return DropdownMenuItem(
                    value: n,
                    child: Text('$n${n == 0 ? ' (highest)' : ''}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Inactive hosts won\'t receive new meetings'),
                value: _isActive,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff0386FF),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}
