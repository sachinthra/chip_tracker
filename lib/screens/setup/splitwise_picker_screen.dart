import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/player.dart';
import '../../providers/game_providers.dart';

/// Result of the Splitwise import: which group to settle into and which
/// members were chosen to sit at the table.
class SplitwiseImport {
  final String groupId;
  final List<Player> players;
  const SplitwiseImport({required this.groupId, required this.players});
}

/// Pick a Splitwise group, then multi-select which of its members are playing.
/// Selected members become [Player]s linked by `splitwiseUserId`.
class SplitwisePickerScreen extends ConsumerStatefulWidget {
  const SplitwisePickerScreen({super.key});

  @override
  ConsumerState<SplitwisePickerScreen> createState() =>
      _SplitwisePickerScreenState();
}

class _SplitwisePickerScreenState extends ConsumerState<SplitwisePickerScreen> {
  late Future<List<Map<String, dynamic>>> _groupsFuture;
  Map<String, dynamic>? _selectedGroup;
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _groupsFuture = ref.read(splitwiseServiceProvider).getGroups();
  }

  List<Map<String, dynamic>> _membersOf(Map<String, dynamic> group) {
    final raw = group['members'];
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return const [];
  }

  String _memberName(Map<String, dynamic> member) {
    final first = (member['first_name'] as String?)?.trim() ?? '';
    final last = (member['last_name'] as String?)?.trim() ?? '';
    final name = [first, last].where((s) => s.isNotEmpty).join(' ');
    return name.isEmpty ? 'Splitwise user' : name;
  }

  void _confirm() {
    final group = _selectedGroup!;
    final players = _membersOf(group)
        .where((m) => _selectedUserIds.contains(m['id'].toString()))
        .map((m) => Player(
              name: _memberName(m),
              source: PlayerSource.splitwise,
              splitwiseUserId: m['id'].toString(),
            ))
        .toList();
    Navigator.of(context).pop(
      SplitwiseImport(groupId: group['id'].toString(), players: players),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedGroup == null ? 'Choose Group' : 'Choose Players'),
      ),
      body: _selectedGroup == null ? _groupList() : _memberList(_selectedGroup!),
      floatingActionButton: _selectedGroup != null && _selectedUserIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: Text('Seat ${_selectedUserIds.length}'),
            )
          : null,
    );
  }

  Widget _groupList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load Splitwise groups.'));
        }
        final groups = (snapshot.data ?? [])
            .where((g) => g['id'].toString() != '0') // skip "non-group expenses"
            .toList();
        if (groups.isEmpty) {
          return const Center(child: Text('No Splitwise groups found.'));
        }
        return ListView(
          children: [
            for (final group in groups)
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(group['name']?.toString() ?? 'Group'),
                subtitle: Text('${_membersOf(group).length} members'),
                onTap: () => setState(() => _selectedGroup = group),
              ),
          ],
        );
      },
    );
  }

  Widget _memberList(Map<String, dynamic> group) {
    final members = _membersOf(group);
    return ListView(
      children: [
        for (final member in members)
          CheckboxListTile(
            title: Text(_memberName(member)),
            value: _selectedUserIds.contains(member['id'].toString()),
            onChanged: (checked) {
              setState(() {
                final id = member['id'].toString();
                if (checked == true) {
                  _selectedUserIds.add(id);
                } else {
                  _selectedUserIds.remove(id);
                }
              });
            },
          ),
      ],
    );
  }
}
