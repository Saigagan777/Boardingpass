import 'package:flutter/material.dart';
import '../state_manager.dart';

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

    return ListenableBuilder(
      listenable: _state,
      builder: (context, child) {
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
                      _buildStatCard('Active Users', '42', Icons.people_outline, const Color(0xFF7A432D)),
                      _buildStatCard('Matches', '18', Icons.favorite_border, const Color(0xFFB06F4D)),
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
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
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
}
