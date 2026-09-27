import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({Key? key}) : super(key: key);
  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  String searchQuery = '';

  void _showReportDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24, right: 24, top: 24
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Report Found Item', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Help return a lost item to its owner by providing details below.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: titleController, 
                decoration: InputDecoration(
                  labelText: 'Item Name', hintText: 'e.g. Blue Umbrella',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Theme.of(context).cardColor,
                )
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locController, 
                decoration: InputDecoration(
                  labelText: 'Found At', hintText: 'Station or Location',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Theme.of(context).cardColor,
                )
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController, 
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description / Details',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Theme.of(context).cardColor,
                )
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController, keyboardType: TextInputType.phone, 
                decoration: InputDecoration(
                  labelText: 'Your Contact Number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Theme.of(context).cardColor,
                )
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1b775f),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  onPressed: isSubmitting ? null : () async {
                    if (titleController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                      setModalState(() => isSubmitting = true);
                      await FirebaseFirestore.instance.collection('lost_items').add({
                        'title': titleController.text,
                        'description': descController.text,
                        'location': locController.text,
                        'contactPhone': phoneController.text,
                        'owner_id': authHandler.currentUser?.id ?? 'anonymous',
                        'date': DateTime.now().toIso8601String(),
                      });
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item successfully hosted on the Cloud!')));
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
                    }
                  },
                  child: isSubmitting 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
     }
    );
   },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Lost & Found (Cloud)'), backgroundColor: const Color(0xFF1b775f), foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Search live items...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('lost_items').snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error loading data: ${snapshot.error}\n(This could be due to Firebase security rules preventing reads without authentication)', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No active lost items on the cloud.'));
                }
                
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final location = (data['location'] ?? '').toString().toLowerCase();
                  final query = searchQuery.toLowerCase();
                  return title.contains(query) || location.contains(query);
                }).toList();

                docs.sort((a, b) {
                  final da = (a.data() as Map<String, dynamic>)['date']?.toString();
                  final db = (b.data() as Map<String, dynamic>)['date']?.toString();
                  if (da == null && db == null) return 0;
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return db.compareTo(da);
                });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: const Color(0xFF1b775f).withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.inventory_2, color: Color(0xFF1b775f)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['title'] ?? 'Unknown Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(data['location'] ?? 'Unknown Location', style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(data['description'] ?? '', style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (data['owner_id'] != null && data['owner_id'] == authHandler.currentUser?.id)
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance.collection('lost_items').doc(docs[i].id).delete();
                                    },
                                  ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  icon: const Icon(Icons.call, size: 18),
                                  label: const Text('Contact Finder'),
                                  onPressed: () => launchUrl(Uri.parse('tel:${data['contactPhone'] ?? ''}')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportDialog,
        icon: const Icon(Icons.add), label: const Text('Host Found Item'),
        backgroundColor: const Color(0xFF1b775f), foregroundColor: Colors.white,
      ),
    );
  }
}
