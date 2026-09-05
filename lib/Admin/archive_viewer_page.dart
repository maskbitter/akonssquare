import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:akons_square/Common/ui_helper.dart';

class ArchiveViewerPage extends StatefulWidget {
  const ArchiveViewerPage({super.key});

  @override
  State<ArchiveViewerPage> createState() => _ArchiveViewerPageState();
}

class _ArchiveViewerPageState extends State<ArchiveViewerPage> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedCollection = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final Map<String, String> _collectionLabels = {
    'all': 'All Items',
    'categories': 'Categories',
    'sub_items': 'Units / Rooms',
    'services': 'Global Services',
    'main_meters': 'Main Meters',
    'sub_meters': 'Sub Meters',
    'users': 'Administrative Users',
    'billing_history': 'Billing Records',
  };

  @override
  Widget build(BuildContext context) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Archive & Audit Logs"),
        centerTitle: true,
        elevation: isOutline ? 0 : 2,
      ),
      body: Column(
        children: [
          _buildFilters(isOutline),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getArchiveStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var docs = snapshot.data!.docs;
                
                // Client-side search filtering
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String content = data.toString().toLowerCase();
                    return content.contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text("No archived records found", style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildArchiveTile(docs[index], isOutline, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isOutline) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search in archive...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ""; })) 
                : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _collectionLabels.entries.map((entry) {
                bool isSelected = _selectedCollection == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedCollection = entry.key),
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      fontWeight: isSelected ? FontWeight.bold : null
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getArchiveStream() {
    Query query = FirebaseFirestore.instance.collection('removed_history').orderBy('removedAt', descending: true);
    if (_selectedCollection != 'all') {
      query = query.where('collection', isEqualTo: _selectedCollection);
    }
    return query.snapshots();
  }

  Widget _buildArchiveTile(DocumentSnapshot doc, bool isOutline, int index) {
    var data = doc.data() as Map<String, dynamic>;
    String collection = data['collection'] ?? 'unknown';
    Map<String, dynamic> originalData = data['originalData'] ?? {};
    String removedBy = data['removedBy'] ?? 'Unknown';
    Timestamp? removedAt = data['removedAt'] as Timestamp?;
    String reason = data['reason'] ?? 'No reason provided';

    // Try to find a name for the item
    String itemName = originalData['subItemName'] ?? 
                      originalData['categoryName'] ?? 
                      originalData['username'] ?? 
                      originalData['meterNo'] ?? 
                      originalData['serviceName'] ?? 
                      "Document ID: ${data['originalDocId'] ?? 'N/A'}";

    Color color = _getCollectionColor(collection);

    return Card(
      elevation: isOutline ? 0 : 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOutline ? BorderSide(color: color, width: 1.5) : BorderSide.none,
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(_getCollectionIcon(collection), color: color, size: 20),
        ),
        title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("From: ${_collectionLabels[collection] ?? collection}"),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow("Removed By", removedBy, Icons.person_outline),
                _buildInfoRow("Date & Time", DatabaseService.formatFullDateTime(removedAt), Icons.calendar_today_outlined),
                _buildInfoRow("Reason", reason, Icons.info_outline),
                const Divider(height: 24),
                const Text("Original Data (Raw View):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    originalData.entries.map((e) => "${e.key}: ${e.value}").join("\n"),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Color _getCollectionColor(String collection) {
    switch (collection) {
      case 'categories': return Colors.blue;
      case 'sub_items': return Colors.teal;
      case 'billing_history': return Colors.green;
      case 'users': return Colors.orange;
      case 'main_meters':
      case 'sub_meters': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getCollectionIcon(String collection) {
    switch (collection) {
      case 'categories': return Icons.category_outlined;
      case 'sub_items': return Icons.meeting_room_outlined;
      case 'billing_history': return Icons.receipt_long_outlined;
      case 'users': return Icons.person_outline;
      case 'main_meters': return Icons.speed_outlined;
      case 'sub_meters': return Icons.av_timer_outlined;
      default: return Icons.delete_outline;
    }
  }
}
