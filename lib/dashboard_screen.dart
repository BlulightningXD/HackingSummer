import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'metro_map_screen.dart';
import 'complaints_map_screen.dart';
import 'lost_found_screen.dart';
import 'profile_screen.dart';
import 'main.dart';
import 'deadzone_engine.dart';

final Set<String> _dismissedAlerts = {};

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isDark = themeNotifier.themeMode == ThemeMode.dark;
        final bgColor = isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF3F4F6);
        final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
        final glassColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7);
        final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.white;
        final perfMode = themeNotifier.performanceMode;

        return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          if (!perfMode) ...[
            // Ambient Glows
            Positioned(
              top: -100, left: -100,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(color: isDark ? Colors.pinkAccent.withOpacity(0.3) : Colors.blue.withOpacity(0.15), shape: BoxShape.circle),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
              ),
            ),
            Positioned(
              bottom: -50, right: -50,
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(color: isDark ? Colors.blueAccent.withOpacity(0.25) : Colors.green.withOpacity(0.15), shape: BoxShape.circle),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
              ),
            ),
            Positioned(
              top: 300, right: -150,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(color: isDark ? Colors.greenAccent.withOpacity(0.2) : Colors.orange.withOpacity(0.15), shape: BoxShape.circle),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
              ),
            ),
          ],
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Custom AppBar / Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Disha', style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        ],
                      ),
                      Row(
                        children: [
                          _buildGlassIcon(Icons.info_outline, () => _showCrowdInfo(context, perfMode), glassColor, borderColor, textColor, perfMode),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: glassColor,
                                border: Border.all(color: borderColor),
                                image: authHandler.currentUser?.photoUrl != null
                                    ? DecorationImage(image: NetworkImage(authHandler.currentUser!.photoUrl!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: authHandler.currentUser?.photoUrl == null
                                  ? Icon(Icons.person, color: isDark ? Colors.white54 : Colors.black54)
                                  : null,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Bento Grid
                  _buildGlassCard(
                    context,
                    title: 'Live Metro',
                    subtitle: 'Real-time train tracking',
                    icon: Icons.subway_rounded,
                    color: Colors.pinkAccent,
                    height: 180,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MetroMapScreen(showLiveTrains: true))),
                    glassColor: glassColor, borderColor: borderColor, textColor: textColor, isDark: isDark, perfMode: perfMode,
                  ),
                  const SizedBox(height: 16),
                  
                  Column(
                    children: [
                      _buildGlassCard(
                        context,
                        title: 'City Navigation',
                        subtitle: 'Live traffic & hazards',
                        icon: Icons.navigation_rounded,
                        color: Colors.orangeAccent,
                        height: 120,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintsMapScreen())),
                        glassColor: glassColor, borderColor: borderColor, textColor: textColor, isDark: isDark, perfMode: perfMode,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGlassCard(
                              context,
                              title: 'Lost & Found',
                              subtitle: 'Report items',
                              icon: Icons.support_agent_rounded,
                              color: Colors.blueAccent,
                              height: 120,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LostFoundScreen())),
                              glassColor: glassColor, borderColor: borderColor, textColor: textColor, isDark: isDark, perfMode: perfMode,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildGlassCard(
                              context,
                              title: 'My Reports',
                              subtitle: 'View history',
                              icon: Icons.history_rounded,
                              color: Colors.redAccent,
                              height: 120,
                              onTap: () => _showMyReports(context, perfMode),
                              glassColor: glassColor, borderColor: borderColor, textColor: textColor, isDark: isDark, perfMode: perfMode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  if (themeNotifier.proximityActive) ...[
                    Text('Live Updates', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    StreamBuilder<CongestionRecord>(
                      stream: deadzoneEngine.onCongestionBuffered,
                      builder: (context, snapshot) {
                        String title = 'Scanning crowd density...';
                        String subtitle = 'Listening for nearby Bluetooth devices.';
                        
                        final allRecords = deadzoneEngine.getAllStationCongestion();
                        String? latestStationId;
                        int? latestScore;
                        
                        if (snapshot.hasData) {
                          latestStationId = snapshot.data!.stationId;
                          latestScore = snapshot.data!.score;
                        } else if (allRecords.isNotEmpty) {
                          final latestSnapshot = allRecords.values.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
                          latestStationId = latestSnapshot.stationId;
                          latestScore = latestSnapshot.score;
                        }

                        if (latestStationId != null && latestScore != null) {
                          final station = deadzoneEngine.activeGraph.getStation(latestStationId);
                          title = station != null ? 'Platform - ${station.name}' : 'Platform Update';
                          subtitle = latestScore > 40 
                              ? 'High crowd density ($latestScore% capacity). Expect 5-10 min delays.' 
                              : 'Crowd density is normal ($latestScore% capacity).';
                        }

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: glassColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.campaign_rounded, color: Colors.orangeAccent),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.4)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
      }
    );
  }

  Widget _buildGlassIcon(IconData icon, VoidCallback onTap, Color glassColor, Color borderColor, Color iconColor, bool perfMode) {
    final content = Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: perfMode ? glassColor.withOpacity(0.2) : glassColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: perfMode ? content : BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: content),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required double height, required VoidCallback onTap, required Color glassColor, required Color borderColor, required Color textColor, required bool isDark, required bool perfMode}) {
    final content = Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: perfMode ? glassColor.withOpacity(0.15) : glassColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title, 
                  style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle, 
                  style: TextStyle(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5), fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: perfMode ? content : BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: content),
      ),
    );
  }

  void _showCrowdInfo(BuildContext context, bool perfMode) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final content = Container(
          padding: const EdgeInsets.all(24),
          color: perfMode ? const Color(0xFF1C1C1E) : const Color(0xFF1C1C1E).withOpacity(0.9),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Crowdedness AI Logic', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('We use anonymous, low-energy Bluetooth (BLE) signals from nearby devices to securely estimate the crowd density inside metro stations and trains, completely offline and without tracking personal data.\n\nThe congestion score you see is dynamically generated by counting the unique set of active devices surrounding you.', style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
              const SizedBox(height: 40),
            ],
          ),
        );

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: perfMode ? content : BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: content),
        );
      },
    );
  }

  void _showMyReports(BuildContext context, bool perfMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final content = Container(
          padding: const EdgeInsets.all(24),
          color: perfMode ? const Color(0xFF1C1C1E) : const Color(0xFF1C1C1E).withOpacity(0.9),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('My Hazard Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('hazards').where('owner_id', isEqualTo: authHandler.currentUser?.id ?? 'anonymous').snapshots(),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) return const Center(child: Text('You have not submitted any active reports.', style: TextStyle(color: Colors.white54)));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (ctx, index) {
                         final doc = docs[index];
                         final data = doc.data() as Map<String, dynamic>;
                         return Container(
                           margin: const EdgeInsets.only(bottom: 12),
                           decoration: BoxDecoration(
                             color: Colors.white.withOpacity(0.05),
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: Colors.white.withOpacity(0.1)),
                           ),
                           child: ListTile(
                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             leading: Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), shape: BoxShape.circle),
                               child: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                             ),
                             title: Text(data['hazard_type'] ?? 'Hazard Reported', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                             subtitle: Text(data['description'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                             trailing: IconButton(
                               icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                               onPressed: () async {
                                 await FirebaseFirestore.instance.collection('hazards').doc(doc.id).delete();
                               },
                             ),
                           ),
                         );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: perfMode ? content : BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: content),
        );
      },
    );
  }
}
