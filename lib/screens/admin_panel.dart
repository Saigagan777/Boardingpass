import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/moderation_service.dart';
import '../services/sponsor_service.dart';
import '../state_manager.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  static const _ink = Color(0xFF3E1F11);
  static const _brand = Color(0xFF7A432D);
  static const _surface = Color(0xFFFAF7F5);
  static const _line = Color(0xFFE8E2DD);
  final _state = AppStateManager();
  final _search = TextEditingController();
  int _section = 0;
  String _filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        final users = usersSnapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('reports').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, reportsSnapshot) {
            final reports = reportsSnapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final userNames = {for (final user in users) user.id: (user.data()['name'] as String?)?.trim().isNotEmpty == true ? user.data()['name'] as String : 'Unnamed user'};
            return Scaffold(
              backgroundColor: _surface,
              appBar: AppBar(
                backgroundColor: _surface,
                surfaceTintColor: _surface,
                elevation: 0,
                titleSpacing: 20,
                title: const Row(children: [Icon(Icons.admin_panel_settings_outlined, color: _brand), SizedBox(width: 10), Text('Control centre', style: TextStyle(fontFamily: 'PlayfairDisplay', color: _ink, fontWeight: FontWeight.bold))]),
                actions: [
                  IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout_outlined, color: _ink), onPressed: _state.logOut),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 850;
                  final content = _body(users, reports, userNames);
                  return Row(
                    children: [
                      if (wide) _rail(),
                      Expanded(child: content),
                    ],
                  );
                },
              ),
              bottomNavigationBar: MediaQuery.sizeOf(context).width < 850 ? NavigationBar(
                selectedIndex: _section,
                onDestinationSelected: (value) => setState(() => _section = value),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Overview'),
                  NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'People'),
                  NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Reports'),
                  NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Ads'),
                ],
              ) : null,
            );
          },
        );
      },
    );
  }

  Widget _rail() => NavigationRail(
    selectedIndex: _section,
    onDestinationSelected: (value) => setState(() => _section = value),
    backgroundColor: Colors.white,
    labelType: NavigationRailLabelType.all,
    leading: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Icon(Icons.shield_outlined, color: _brand)),
    destinations: const [
      NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
      NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('People')),
      NavigationRailDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: Text('Reports')),
      NavigationRailDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: Text('Ads')),
    ],
  );

  Widget _body(List<QueryDocumentSnapshot<Map<String, dynamic>>> users, List<QueryDocumentSnapshot<Map<String, dynamic>>> reports, Map<String, String> names) {
    final pending = reports.where((r) => r.data()['status'] == 'pending').length;
    final restricted = users.where((u) => u.data()['isLoginRestricted'] == true).length;
    final discoverable = users.where((u) => u.data()['isDiscoverable'] != false && u.data()['isLoginRestricted'] != true).length;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 850 ? 32 : 16, 16, MediaQuery.sizeOf(context).width >= 850 ? 32 : 16, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: switch (_section) {
          0 => _overview(users.length, discoverable, pending, restricted, reports, names),
          1 => _people(users),
          2 => _reports(reports, names),
          _ => _ads(),
        },
      ),
    );
  }

  Widget _overview(int users, int discoverable, int pending, int restricted, List<QueryDocumentSnapshot<Map<String, dynamic>>> reports, Map<String, String> names) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('System at a glance', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 28, color: _ink, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Live account health, safety queue, and moderation actions.', style: TextStyle(color: Color(0xFF6B5A52))),
      const SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _metric('Total users', '$users', Icons.people_outline, _brand),
        _metric('In discovery', '$discoverable', Icons.explore_outlined, const Color(0xFF276749)),
        _metric('Needs review', '$pending', Icons.flag_outlined, const Color(0xFFB45309)),
        _metric('Restricted', '$restricted', Icons.lock_outline, const Color(0xFFC62828)),
      ]),
      const SizedBox(height: 32),
      Row(children: [const Expanded(child: Text('Newest safety reports', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 20, color: _ink, fontWeight: FontWeight.bold))), TextButton(onPressed: () => setState(() => _section = 2), child: const Text('Open queue'))]),
      const SizedBox(height: 8),
      if (reports.isEmpty) _empty('No reports have been submitted.'),
      ...reports.take(4).map((report) => _reportCard(report, names, compact: true)),
    ],
  );

  Widget _metric(String label, String value, IconData icon, Color color) => SizedBox(
    width: 210,
    child: Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _line)),
      child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _ink)), Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5A52)))])])),
    ),
  );

  Widget _people(List<QueryDocumentSnapshot<Map<String, dynamic>>> users) {
    final query = _search.text.trim().toLowerCase();
    final filtered = users.where((user) {
      final data = user.data();
      final haystack = '${data['name'] ?? ''} ${data['email'] ?? ''} ${data['company'] ?? ''}'.toLowerCase();
      final matchesFilter = _filter == 'All' || (_filter == 'Restricted' ? data['isLoginRestricted'] == true : data['isDiscoverable'] != false && data['isLoginRestricted'] != true);
      return haystack.contains(query) && matchesFilter;
    }).toList()..sort((a, b) => ((b.data()['reportCount'] as num?)?.toInt() ?? 0).compareTo((a.data()['reportCount'] as num?)?.toInt() ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('People', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 28, color: _ink, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), const Text('Search accounts, inspect report counts, and apply safety restrictions.'),
      const SizedBox(height: 20),
      TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search name, email, or company', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: ['All', 'Active', 'Restricted'].map((item) => ChoiceChip(label: Text(item), selected: _filter == item, onSelected: (_) => setState(() => _filter = item))).toList()),
      const SizedBox(height: 16),
      if (filtered.isEmpty) _empty('No users match these filters.'),
      ...filtered.map(_userCard),
    ]);
  }

  Widget _userCard(QueryDocumentSnapshot<Map<String, dynamic>> user) {
    final data = user.data();
    final restricted = data['isLoginRestricted'] == true;
    final reportCount = (data['reportCount'] as num?)?.toInt() ?? 0;
    final name = (data['name'] as String?)?.trim().isNotEmpty == true ? data['name'] as String : 'Unnamed user';
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 10), color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _line)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: _brand.withValues(alpha: .12), child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: _brand, fontWeight: FontWeight.bold))),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: _ink)),
        subtitle: Text('${data['email'] ?? 'No email'}  •  $reportCount report${reportCount == 1 ? '' : 's'}'),
        trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _statusChip(restricted ? 'Restricted' : (data['isDiscoverable'] == false ? 'Hidden' : 'Active'), restricted ? const Color(0xFFC62828) : _brand),
          IconButton(tooltip: restricted ? 'Restore account' : 'Restrict account', icon: Icon(restricted ? Icons.lock_open_outlined : Icons.lock_outline, color: restricted ? _brand : const Color(0xFFC62828)), onPressed: () => _confirmRestriction(user.id, name, !restricted)),
        ]),
      ),
    );
  }

  Widget _reports(List<QueryDocumentSnapshot<Map<String, dynamic>>> reports, Map<String, String> names) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Safety reports', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 28, color: _ink, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6), const Text('Every report records a reason and can be resolved or dismissed by a moderator.'),
    const SizedBox(height: 20),
    if (reports.isEmpty) _empty('The safety queue is clear.'),
    ...reports.map((report) => _reportCard(report, names)),
  ]);

  Widget _reportCard(QueryDocumentSnapshot<Map<String, dynamic>> report, Map<String, String> names, {bool compact = false}) {
    final data = report.data();
    final status = data['status'] as String? ?? 'pending';
    final reportedId = data['reportedUserId'] as String? ?? '';
    final reporterId = data['reporterId'] as String? ?? '';
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 10), color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _line)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${names[reportedId] ?? 'Unknown user'} was reported', style: const TextStyle(fontWeight: FontWeight.bold, color: _ink))), _statusChip(status[0].toUpperCase() + status.substring(1), status == 'pending' ? const Color(0xFFB45309) : _brand)]),
        const SizedBox(height: 6), Text('Reported by ${names[reporterId] ?? 'Unknown user'}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B5A52))),
        if (!compact) ...[const SizedBox(height: 12), Text(data['reason'] as String? ?? 'No reason supplied', style: const TextStyle(height: 1.35)), const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: Wrap(spacing: 8, children: [TextButton(onPressed: status == 'pending' ? () => ModerationService.instance.setReportStatus(report.id, 'dismissed') : null, child: const Text('Dismiss')), FilledButton(onPressed: status == 'pending' ? () => ModerationService.instance.setReportStatus(report.id, 'resolved') : null, style: FilledButton.styleFrom(backgroundColor: _brand), child: const Text('Resolve'))]))],
      ])),
    );
  }

  Widget _ads() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Advertisements', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 28, color: _ink, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text('Create, pause, and remove promotions shown in the hub.') ])), FilledButton.icon(onPressed: _showAddAdDialog, style: FilledButton.styleFrom(backgroundColor: _brand), icon: const Icon(Icons.add), label: const Text('Add ad'))]),
    const SizedBox(height: 20),
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: SponsorService().streamSponsors(), builder: (context, snapshot) {
      final ads = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      if (ads.isEmpty) return _empty('No advertisements yet.');
      return Column(
        children: ads.map((ad) {
          final data = ad.data();
          final active = data['isActive'] != false;
          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _line),
            ),
            child: ListTile(
              leading: const Icon(Icons.campaign_outlined, color: _brand),
              title: Text(
                data['brand'] ?? 'Unnamed advertiser',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _ink),
              ),
              subtitle: Text(data['title'] ?? ''),
              trailing: Wrap(
                spacing: 4,
                children: [
                  Switch(
                    value: active,
                    onChanged: (value) => SponsorService().setSponsorActive(ad.id, value),
                  ),
                  IconButton(
                    tooltip: 'Delete ad',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFC62828),
                    ),
                    onPressed: () => SponsorService().deleteSponsor(ad.id),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }),
  ]);

  Widget _statusChip(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)));
  Widget _empty(String message) => Container(width: double.infinity, padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B5A52))));

  Future<void> _confirmRestriction(String userId, String name, bool restrict) async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text('${restrict ? 'Restrict' : 'Restore'} $name?'), content: Text(restrict ? 'This immediately removes the account from discovery and stops access to the app.' : 'This restores discovery and app access.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: restrict ? const Color(0xFFC62828) : _brand), child: Text(restrict ? 'Restrict' : 'Restore'))]));
    if (ok == true) await ModerationService.instance.setUserRestriction(userId, restrict);
  }

  void _showAddAdDialog() {
    final brand = TextEditingController(); final title = TextEditingController(); final cta = TextEditingController(text: 'Learn more'); final url = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Add advertisement'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_field(brand, 'Advertiser / brand'), const SizedBox(height: 12), _field(title, 'Offer title'), const SizedBox(height: 12), _field(cta, 'Button label'), const SizedBox(height: 12), _field(url, 'Destination URL')])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { if (brand.text.trim().isEmpty || title.text.trim().isEmpty) return; await SponsorService().addSponsor(brand: brand.text.trim(), title: title.text.trim(), cta: cta.text.trim(), url: url.text.trim()); if (context.mounted) Navigator.pop(context); }, style: FilledButton.styleFrom(backgroundColor: _brand), child: const Text('Publish'))]));
  }
  Widget _field(TextEditingController controller, String label) => TextField(controller: controller, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
}
