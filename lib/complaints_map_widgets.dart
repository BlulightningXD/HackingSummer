import 'dart:ui';
import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final List<dynamic> searchResults;
  final Function(dynamic) onSelectResult;

  const SearchBarWidget({
    Key? key,
    required this.controller,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
    required this.searchResults,
    required this.onSelectResult,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withOpacity(0.85),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white54, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Search destination...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onChanged: onChanged,
                    ),
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                      ),
                    ),
                  if (controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: onClear,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withOpacity(0.85),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: searchResults.length,
                    separatorBuilder: (c, i) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, index) {
                      final item = searchResults[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.place, color: Colors.white54, size: 20)
                        ),
                        title: Text(
                          item['display_name'] ?? '', 
                          style: const TextStyle(color: Colors.white, fontSize: 15), 
                          maxLines: 2, 
                          overflow: TextOverflow.ellipsis
                        ),
                        onTap: () => onSelectResult(item),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RoutingPanelWidget extends StatelessWidget {
  final TextEditingController originController;
  final TextEditingController destController;
  final VoidCallback onSwap;
  final VoidCallback onBack;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestChanged;
  final VoidCallback onOriginTap;
  final VoidCallback onDestTap;
  final List<dynamic> searchResults;
  final Function(dynamic) onSelectResult;
  final bool isSearching;

  const RoutingPanelWidget({
    Key? key,
    required this.originController,
    required this.destController,
    required this.onSwap,
    required this.onBack,
    required this.onOriginChanged,
    required this.onDestChanged,
    required this.onOriginTap,
    required this.onDestTap,
    required this.searchResults,
    required this.onSelectResult,
    required this.isSearching,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withOpacity(0.85),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildInputField(originController, 'Choose starting point', onOriginChanged, onTap: onOriginTap),
                        const SizedBox(height: 8),
                        _buildInputField(destController, 'Choose destination', onDestChanged, onTap: onDestTap),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_vert, color: Colors.white),
                    onPressed: onSwap,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withOpacity(0.85),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: searchResults.length,
                    separatorBuilder: (c, i) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, index) {
                      final item = searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.place, color: Colors.white54),
                        title: Text(item['display_name'] ?? '', style: const TextStyle(color: Colors.white), maxLines: 1),
                        onTap: () => onSelectResult(item),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, ValueChanged<String> onChanged, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onTap: onTap,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
