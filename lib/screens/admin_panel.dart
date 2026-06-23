import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../state_manager.dart';
import '../services/sponsor_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final AppStateManager _state = AppStateManager();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final logs = _state.adminLogs;
        final resolvedLogs = logs.where((l) => l.isResolved).toList();
        final pendingLogs = logs.where((l) => !l.isResolved).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF7F5),
            elevation: 0,
            title: Row(
              children: const [
                Icon(Icons.shield_outlined, color: Color(0xFF3E1F11)),
                SizedBox(width: 8),
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Color(0xFF3E1F11)),
                onPressed: () {
                  _state.logOut();
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System statistics, active flags, and moderator controls.',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Analytics Grids
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildStatCard('Active Users', count.toString(), Icons.people_outline, const Color(0xFF7A432D));
                        },
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('connections').snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildStatCard('Connections', count.toString(), Icons.handshake_outlined, const Color(0xFFB06F4D));
                        },
                      ),
                      _buildStatCard('Pending Flags', pendingLogs.length.toString(), Icons.flag_outlined, const Color(0xFF3E1F11)),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Pending Flags Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pending Flags (${pendingLogs.length})',
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      if (pendingLogs.isNotEmpty)
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Flags list
                  if (pendingLogs.isEmpty)
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E2DD)),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'All flags resolved!',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingLogs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final log = pendingLogs[index];
                        return _buildFlagCard(log);
                      },
                    ),

                  const SizedBox(height: 28),

                  // History Log Header
                  Text(
                    'Resolved Logs (${resolvedLogs.length})',
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (resolvedLogs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'No resolved logs in this session.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: Color(0xFF8C736B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: resolvedLogs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final log = resolvedLogs[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E2DD).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.title,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C736B),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    Text(
                                      'Reported by ${log.reporter}',
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check, color: Colors.green, size: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  const Divider(height: 40, thickness: 1.5, color: Color(0xFFE8E2DD)),

                  // Sponsors Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sponsor Banners',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7A432D),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(110, 32),
                        ),
                        onPressed: () => _showAddSponsorDialog(context),
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: const Text(
                          'Add Sponsor',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sponsors list using StreamBuilder
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: SponsorService().streamSponsors(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF7A432D)));
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8E2DD)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'No sponsor banners. Add one above!',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final id = doc.id;
                          final brand = data['brand'] ?? 'Brand';
                          final title = data['title'] ?? '';
                          final cta = data['cta'] ?? 'Learn';
                          final iconName = data['icon'] ?? 'star';

                          IconData iconData = Icons.star_outline_rounded;
                          if (iconName == 'coffee') iconData = Icons.coffee;
                          if (iconName == 'flight') iconData = Icons.flight_outlined;
                          if (iconName == 'percent') iconData = Icons.percent;
                          if (iconName == 'business') iconData = Icons.business_outlined;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE8E2DD)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFAF5F0),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(iconData, color: const Color(0xFF7A432D), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SPONSORED · $brand'.toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8C736B),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3E1F11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE8E2DD)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Text(
                                    cta,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7A432D),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    try {
                                      await SponsorService().deleteSponsor(id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Sponsor deleted successfully')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              color: Color(0xFF8C736B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagCard(AdminLog log) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2DD)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  log.title,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
              ),
              Text(
                log.timeAgo,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  color: Color(0xFF8C736B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reporter: ${log.reporter}',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB06F4D),
            ),
          ),
          const SizedBox(height: 8),

          // Details text
          Text(
            log.details,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: Color(0xFF5C473E),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Moderation actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Dismiss button
              TextButton(
                onPressed: () {
                  _state.resolveLog(log.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Warning dismissed.'),
                      backgroundColor: Color(0xFF7A432D),
                    ),
                  );
                },
                child: const Text(
                  'Dismiss',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8C736B),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Ban User button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A432D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  _state.banUser(log.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User / Event permanently banned.'),
                      backgroundColor: Color(0xFF3E1F11),
                    ),
                  );
                },
                child: const Text(
                  'Ban Item',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddSponsorDialog(BuildContext context) {
    final brandController = TextEditingController();
    final titleController = TextEditingController();
    final ctaController = TextEditingController(text: 'Learn');
    final urlController = TextEditingController();
    String selectedIcon = 'star';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8E2DD), width: 1.5),
              ),
              title: const Text(
                'Add Sponsor Banner',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E1F11),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BRAND NAME',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: brandController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Amex Platinum',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'BANNER TITLE / OFFER',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Free lounge access at 1,400+ airports',
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
                                'CTA LABEL',
                                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: ctaController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Learn',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
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
                                'ICON',
                                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedIcon,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'star', child: Text('Star')),
                                  DropdownMenuItem(value: 'coffee', child: Text('Coffee')),
                                  DropdownMenuItem(value: 'flight', child: Text('Flight')),
                                  DropdownMenuItem(value: 'percent', child: Text('Percent')),
                                  DropdownMenuItem(value: 'business', child: Text('Business')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedIcon = val;
                                    });
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
                      'REDIRECT URL',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        hintText: 'e.g. https://americanexpress.com',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C736B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
                  onPressed: () async {
                    if (brandController.text.trim().isNotEmpty && titleController.text.trim().isNotEmpty) {
                      try {
                        await SponsorService().addSponsor(
                          brand: brandController.text.trim(),
                          title: titleController.text.trim(),
                          cta: ctaController.text.trim(),
                          url: urlController.text.trim(),
                          icon: selectedIcon,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sponsor banner added successfully!'),
                              backgroundColor: Color(0xFF7A432D),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding sponsor: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
