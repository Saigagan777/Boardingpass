import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/moderation_service.dart';
import '../services/sponsor_service.dart';
import '../services/event_service.dart';
import '../state_manager.dart';
import '../utils/google_search_helper.dart';

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
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('events').snapshots(),
              builder: (context, eventsSnapshot) {
                final events = eventsSnapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
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
                      final content = _body(users, reports, events, userNames);
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
                      NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Events'),
                      NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Reports'),
                      NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Ads'),
                    ],
                  ) : null,
                );
              },
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
      NavigationRailDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: Text('Events')),
      NavigationRailDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: Text('Reports')),
      NavigationRailDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: Text('Ads')),
    ],
  );

  Widget _body(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
    Map<String, String> names,
  ) {
    final pending = reports.where((r) => r.data()['status'] == 'pending').length;
    final restricted = users.where((u) => u.data()['isLoginRestricted'] == true).length;
    final discoverable = users.where((u) => u.data()['isDiscoverable'] != false && u.data()['isLoginRestricted'] != true).length;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 850 ? 32 : 16, 16, MediaQuery.sizeOf(context).width >= 850 ? 32 : 16, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: switch (_section) {
          0 => _overview(users.length, discoverable, pending, restricted, reports, events, names),
          1 => _people(users),
          2 => _eventsManagement(),
          3 => _reports(reports, names),
          _ => _ads(),
        },
      ),
    );
  }

  Widget _overview(
    int usersCount,
    int discoverable,
    int pending,
    int restricted,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
    Map<String, String> names,
  ) {
    final adminEventsCount = events.where((e) => e.data()['createdByAdmin'] == true).length;
    final totalEventsCount = events.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HERO WELCOME BANNER ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7A432D), Color(0xFF4A2416)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7A432D).withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'System Operational',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Admin Portal',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome Back, Admin 👋',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Live system metrics, community health monitoring, safety queue, and events control.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showCreateAdminEventDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3E1F11),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF7A432D)),
                    label: const Text(
                      'Create Priority Event',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _section = 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.people_alt_outlined, size: 18, color: Colors.white),
                    label: const Text(
                      'People Directory',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _section = 3),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.shield_outlined, size: 18, color: Colors.white),
                    label: Text(
                      'Safety Queue ($pending)',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── METRICS GRID ──
        const Text(
          'Key System Metrics',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 36) / 4
                : (constraints.maxWidth >= 450 ? (constraints.maxWidth - 12) / 2 : double.infinity);

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metricCard(
                  width: cardWidth,
                  label: 'Total Registered Users',
                  value: '$usersCount',
                  badgeText: 'Active Platform',
                  icon: Icons.people_alt_rounded,
                  color: _brand,
                  bgColor: const Color(0xFFFAF0EB),
                ),
                _metricCard(
                  width: cardWidth,
                  label: 'In Discovery Feed',
                  value: '$discoverable',
                  badgeText: '${((discoverable / (usersCount > 0 ? usersCount : 1)) * 100).toStringAsFixed(0)}% visible',
                  icon: Icons.explore_rounded,
                  color: const Color(0xFF15803D),
                  bgColor: const Color(0xFFF0FDF4),
                ),
                _metricCard(
                  width: cardWidth,
                  label: 'Needs Review',
                  value: '$pending',
                  badgeText: pending > 0 ? '$pending Pending' : 'Queue Clear',
                  icon: Icons.security_rounded,
                  color: const Color(0xFFB45309),
                  bgColor: const Color(0xFFFFFBEB),
                ),
                _metricCard(
                  width: cardWidth,
                  label: 'Restricted Accounts',
                  value: '$restricted',
                  badgeText: restricted > 0 ? '$restricted Banned' : '0 Banned',
                  icon: Icons.lock_person_rounded,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 32),

        // ── DUAL SECTION: RECENT REPORTS & SYSTEM QUICK STATS ──
        LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth >= 800;

            final reportsSection = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Newest Safety Reports',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _section = 3),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: _brand),
                      label: const Text(
                        'Open Queue',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          color: _brand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (reports.isEmpty)
                  _empty('No reports submitted. Community is clear!')
                else
                  ...reports.take(4).map((report) => _reportCard(report, names, compact: true)),
              ],
            );

            final statsSection = Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF0EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.insert_chart_outlined_rounded, color: _brand, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Platform Summary',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _summaryRow(
                    label: 'Total Platform Events',
                    value: '$totalEventsCount Events',
                    icon: Icons.event_available_rounded,
                    accentColor: const Color(0xFF2563EB),
                  ),
                  const Divider(height: 20, color: _line),
                  _summaryRow(
                    label: 'Admin Priority Events',
                    value: '$adminEventsCount Published',
                    icon: Icons.star_rounded,
                    accentColor: const Color(0xFFD97706),
                  ),
                  const Divider(height: 20, color: _line),
                  _summaryRow(
                    label: 'Active Users Ratio',
                    value: '${usersCount > 0 ? ((discoverable / usersCount) * 100).toStringAsFixed(1) : '100'}%',
                    icon: Icons.pie_chart_outline_rounded,
                    accentColor: const Color(0xFF16A34A),
                  ),
                  const Divider(height: 20, color: _line),
                  _summaryRow(
                    label: 'Safety Response Rate',
                    value: pending == 0 ? '100% Clear' : '$pending Action Needed',
                    icon: Icons.verified_user_outlined,
                    accentColor: pending == 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ],
              ),
            );

            if (isWideScreen) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: reportsSection),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: statsSection),
                ],
              );
            } else {
              return Column(
                children: [
                  reportsSection,
                  const SizedBox(height: 24),
                  statsSection,
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _metricCard({
    required double width,
    required String label,
    required String value,
    required String badgeText,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Color(0xFF6B5A52),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: Color(0xFF5C473E),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
      ],
    );
  }



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

  Widget _eventsManagement() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Events Management',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 28,
                    color: _ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Create priority admin events and manage community listings.',
                  style: TextStyle(color: Color(0xFF6B5A52)),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _showCreateAdminEventDialog,
            style: FilledButton.styleFrom(backgroundColor: _brand),
            icon: const Icon(Icons.add),
            label: const Text('Create Admin Event'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (docs.isEmpty) return _empty('No events found.');

          // Sort Admin created events FIRST
          final sortedEvents = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
            ..sort((a, b) {
              final aAdmin = a.data()['createdByAdmin'] == true;
              final bAdmin = b.data()['createdByAdmin'] == true;
              if (aAdmin && !bAdmin) return -1;
              if (!aAdmin && bAdmin) return 1;
              return 0;
            });

          return Column(
            children: sortedEvents.map((eventDoc) {
              final data = eventDoc.data();
              final isAdminEvent = data['createdByAdmin'] == true;
              final title = data['title'] ?? 'Untitled Event';
              final location = data['location'] ?? 'Location TBA';
              final time = data['time'] ?? '';
              final month = data['month'] ?? '';
              final day = data['day'] ?? '';
              final category = data['category'] ?? 'Meetups';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                color: isAdminEvent ? const Color(0xFFFFF8F3) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isAdminEvent ? const Color(0xFFE5A475) : _line,
                    width: isAdminEvent ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAdminEvent ? _brand : const Color(0xFFE8E2DD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          month.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isAdminEvent ? Colors.white : _ink,
                          ),
                        ),
                        Text(
                          day,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isAdminEvent ? Colors.white : _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _ink),
                        ),
                      ),
                      if (isAdminEvent) ...[
                        const SizedBox(width: 8),
                        _statusChip('ADMIN CREATED', _brand),
                      ],
                    ],
                  ),
                  subtitle: Text('$location • $time • $category'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: isAdminEvent ? 'Remove Admin Priority' : 'Mark as Admin Created',
                        icon: Icon(
                          isAdminEvent ? Icons.star : Icons.star_border,
                          color: isAdminEvent ? const Color(0xFFB45309) : Colors.grey,
                        ),
                        onPressed: () => FirebaseFirestore.instance
                            .collection('events')
                            .doc(eventDoc.id)
                            .update({'createdByAdmin': !isAdminEvent}),
                      ),
                      IconButton(
                        tooltip: 'Delete Event',
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                        onPressed: () => _confirmDeleteEvent(eventDoc.id, title),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ],
  );

  void _showCreateAdminEventDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final locController = TextEditingController();
        final dateController = TextEditingController();
        final timeController = TextEditingController();
        final mapsController = TextEditingController();
        final priceController = TextEditingController(text: 'Free');
        final rawUrlController = TextEditingController();
        String selectedCat = 'Networking';

        bool isGeocoding = false;
        double? latitude;
        double? longitude;
        String geocodeStatus = '';
        List<Map<String, dynamic>> searchResults = [];
        Timer? debounceTimer;
        bool isSelectingVenue = false;
        Uint8List? selectedImageBytes;
        bool isUploadingImage = false;

        final categories = [
          'Networking',
          'Meetups',
          'Tech',
          'Seminars',
          'Social',
          'Workshops',
          'Co-Working',
          'Conferences',
          'Parties',
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFAF7F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8E2DD), width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFB45309), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Create Priority Admin Event',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EVENT FLYER / IMAGE',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            setDialogState(() {
                              selectedImageBytes = bytes;
                            });
                          }
                        },
                        child: Container(
                          height: 110,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E2DD).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE8E2DD)),
                          ),
                          child: selectedImageBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        selectedImageBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedImageBytes = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF7A432D), size: 32),
                                    SizedBox(height: 4),
                                    Text(
                                      'Upload Event Flyer Photo',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7A432D),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Tap to choose from gallery',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: rawUrlController,
                        decoration: InputDecoration(
                          hintText: 'Or paste image URL (optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'EVENT TITLE',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Executive Tech & AI Summit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CATEGORY',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCat,
                                  dropdownColor: Colors.white,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: categories.map((c) {
                                    return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedCat = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PRICE / TICKET',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: priceController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Free or \$10',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DATE',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: dateController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: 'Select Date',
                                    suffixIcon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF7A432D)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                    );
                                    if (picked != null) {
                                      final List<String> months = [
                                        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                                      ];
                                      dateController.text = '${picked.day} ${months[picked.month - 1]}';
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TIME',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: timeController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: 'Select Time',
                                    suffixIcon: const Icon(Icons.access_time, size: 16, color: Color(0xFF7A432D)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onTap: () async {
                                    final TimeOfDay? picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (picked != null && context.mounted) {
                                      final localizations = MaterialLocalizations.of(context);
                                      timeController.text = localizations.formatTimeOfDay(picked);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'VENUE / LOCATION NAME',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: locController,
                              decoration: InputDecoration(
                                hintText: 'e.g. Hitex Convention Hall',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (val) {
                                if (isSelectingVenue) return;
                                if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
                                debounceTimer = Timer(const Duration(milliseconds: 600), () async {
                                  final venue = val.trim();
                                  if (venue.isEmpty) {
                                    if (context.mounted) {
                                      setDialogState(() {
                                        searchResults = [];
                                        geocodeStatus = '';
                                      });
                                    }
                                    return;
                                  }
                                  if (context.mounted) {
                                    setDialogState(() {
                                      isGeocoding = true;
                                      geocodeStatus = 'Searching...';
                                      searchResults = [];
                                    });
                                  }
                                  final results = await searchGoogleGeocoding(venue);
                                  if (context.mounted) {
                                    setDialogState(() {
                                      isGeocoding = false;
                                      searchResults = results;
                                      if (results.isNotEmpty) {
                                        geocodeStatus = '✓ Select location below:';
                                      } else {
                                        geocodeStatus = '✗ Not found';
                                      }
                                    });
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A432D),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: isGeocoding
                                ? null
                                : () async {
                                    final venue = locController.text.trim();
                                    if (venue.isEmpty) return;
                                    setDialogState(() {
                                      isGeocoding = true;
                                      geocodeStatus = 'Searching...';
                                      searchResults = [];
                                    });
                                    final results = await searchGoogleGeocoding(venue);
                                    setDialogState(() {
                                      isGeocoding = false;
                                      searchResults = results;
                                      if (results.isNotEmpty) {
                                        geocodeStatus = '✓ Select location below:';
                                      } else {
                                        geocodeStatus = '✗ Not found';
                                      }
                                    });
                                  },
                            child: isGeocoding
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Search', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                      if (geocodeStatus.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          geocodeStatus.startsWith('✓')
                              ? '$geocodeStatus Coordinates: ${latitude?.toStringAsFixed(4)}, ${longitude?.toStringAsFixed(4)}'
                              : geocodeStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: geocodeStatus.startsWith('✓') ? Colors.green[800] : Colors.red[800],
                          ),
                        ),
                      ],
                      if (searchResults.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE8E2DD)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Material(
                            color: Colors.white,
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: searchResults.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE8E2DD)),
                              itemBuilder: (context, index) {
                                final item = searchResults[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  title: Text(
                                    item['display_name'],
                                    style: const TextStyle(fontSize: 12, fontFamily: 'PlusJakartaSans', color: Color(0xFF3E1F11)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    setDialogState(() {
                                      isSelectingVenue = true;
                                      locController.text = item['display_name'];
                                      latitude = item['lat'];
                                      longitude = item['lon'];
                                      mapsController.text = 'https://www.google.com/maps/search/?api=1&query=${item['lat']},${item['lon']}';
                                      geocodeStatus = '✓ Location selected!';
                                      searchResults = [];
                                    });
                                    isSelectingVenue = false;
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'GOOGLE MAPS LINK / LOCATION URL (OPTIONAL)',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: mapsController,
                        decoration: InputDecoration(
                          hintText: 'Paste location link here...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          final coords = _extractCoordinatesFromUrl(val);
                          if (coords != null) {
                            setDialogState(() {
                              latitude = coords['lat'];
                              longitude = coords['lon'];
                              geocodeStatus = '✓ Link parsed!';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploadingImage ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C736B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
                  onPressed: isUploadingImage
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) return;

                          setDialogState(() {
                            isUploadingImage = true;
                          });

                          try {
                            final eventId = DateTime.now().millisecondsSinceEpoch.toString();
                            String? uploadedUrl;

                            if (selectedImageBytes != null) {
                              uploadedUrl = await EventService().uploadEventImage(eventId, selectedImageBytes!);
                            } else if (rawUrlController.text.trim().isNotEmpty) {
                              uploadedUrl = rawUrlController.text.trim();
                            }

                            final dateVal = dateController.text.trim();
                            final timeVal = timeController.text.trim();

                            final finalMonth = dateVal.toUpperCase().contains(' ')
                                ? dateVal.split(' ').last
                                : 'JUL';
                            final finalDay = dateVal.isNotEmpty ? dateVal.split(' ').first : '25';

                            await EventService().createEvent(
                              title: titleController.text.trim(),
                              location: locController.text.trim().isNotEmpty ? locController.text.trim() : 'Convention Centre',
                              time: timeVal.isEmpty ? '7:00 PM' : timeVal,
                              month: finalMonth,
                              day: finalDay,
                              category: selectedCat,
                              price: priceController.text.trim().isEmpty ? 'Free' : priceController.text.trim(),
                              mapUrl: mapsController.text.trim().isNotEmpty ? mapsController.text.trim() : null,
                              latitude: latitude,
                              longitude: longitude,
                              imageUrl: uploadedUrl,
                              illustrationPath: _getCategoryImageUrl(selectedCat),
                              createdByAdmin: true,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Priority Admin Event published successfully!'),
                                  backgroundColor: Color(0xFF7A432D),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error creating admin event: $e'),
                                  backgroundColor: const Color(0xFFC62828),
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                isUploadingImage = false;
                              });
                            }
                          }
                        },
                  child: isUploadingImage
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Publish Admin Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getCategoryImageUrl(String cat) {
    switch (cat.toLowerCase()) {
      case 'networking':
        return 'https://images.unsplash.com/photo-1511578314322-379afb476865?w=600&q=80';
      case 'tech':
        return 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=600&q=80';
      case 'seminars':
        return 'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=600&q=80';
      case 'social':
        return 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=600&q=80';
      case 'workshops':
        return 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=600&q=80';
      case 'meetups':
        return 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=600&q=80';
      default:
        return 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=600&q=80';
    }
  }

  Map<String, double>? _extractCoordinatesFromUrl(String url) {
    final regex = RegExp(r'(?:place/|query=|@)(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lon = double.tryParse(match.group(2) ?? '');
      if (lat != null && lon != null) {
        return {'lat': lat, 'lon': lon};
      }
    }
    return null;
  }

  Future<void> _confirmDeleteEvent(String eventId, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $title?'),
        content: const Text('This will permanently delete this event.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await EventService().deleteEvent(eventId);
    }
  }

  Widget _field(TextEditingController controller, String label) => TextField(controller: controller, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
}
