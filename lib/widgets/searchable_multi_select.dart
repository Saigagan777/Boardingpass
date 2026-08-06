import 'package:flutter/material.dart';

const List<String> kInterestOptions = [
  'Networking',
  'Socializing',
  'Learning',
  'Investing',
  'Fundraising',
  'Hiring Talents',
  'Job Opportunity',
  'Other',
];

const List<String> kBusinessConnectOptions = [
  'BNI (Business Network International)',
  'Corporate Connections',
  "Entrepreneurs' Organization",
  'Young Presidents\' Organization',
  'Vistage Worldwide',
  'Chief Executives Organization',
  'The Indus Entrepreneurs',
  'Startup Grind',
  'Rotary International',
  'Lions Clubs International',
  'Others',
];

const List<String> kIndustryOptions = [
  'Academia',
  'Accounting',
  'Administration',
  'Advertising',
  'Aerospace',
  'Airlines',
  'Animation',
  'Apparel',
  'Architecture',
  'Arts / Crafts',
  'Automotive',
  'Aviation',
  'Banking',
  'Biotechnology',
  'Capital Markets',
  'Chemicals',
  'Civil Engineering',
  'Civil Services',
  'Construction',
  'Consulting',
  'Consumer Services',
  'Consumer Electronics',
  'Cosmetics',
  'Crypto',
  'Dairy',
  'Defense',
  'Design',
  'Diplomatic Services',
  'Dispute Resolution',
  'E-Commerce',
  'E-Learning',
  'Education',
  'Engineering',
  'Entertainment',
  'Environmental',
  'Events',
  'Facilities',
  'Farming',
  'Fashion',
  'Film & Music',
  'Finance',
  'Financial Services',
  'Fishery',
  'Food & Beverages',
  'Fundraising',
  'Furniture',
  'Gambling',
  'Gaming',
  'Government',
  'Government Administration',
  'Graphic Design',
  'Greentech',
  'HR',
  'Hardware',
  'Health / Fitness',
  'Healthcare',
  'Hedge Fund',
  'Hospital',
  'Hospitality',
  'IT',
  'Imports / Exports',
  'Industrial Engineering',
  'Information Security',
  'Infrastructure',
  'Insurance',
  'International Affairs',
  'Internet',
  'Investigation',
  'Investment',
  'Jewelry',
  'Journalism',
  'Judiciary',
  'Law Enforcement',
  'Law Practice',
  'Legal',
  'Logistics',
  'Luxury Goods',
  'Machinery',
  'Manufacturing',
  'Maritime',
  'Marketing',
  'Media',
  'Medical Equipment',
  'Medical Practice',
  'Military Industry',
  'Mining / Metals',
  'Mortgage',
  'Museums',
  'Nanotechnology',
  'Networking',
  'Non-Profit',
  'Offshoring',
  'Oil / Energy / Solar',
  'Outsourcing',
  'PR',
  'Package Delivery',
  'Packaging',
  'Performing Arts',
  'Pharma',
  'Philanthropy',
  'Photography',
  'Plastics',
  'Political Org',
  'Printing',
  'Private Equity',
  'Procurement',
  'Production',
  'Railroad',
  'Ranching',
  'Real Estate',
  'Religious Institutions',
  'Renewable Energy',
  'Research',
  'Restaurant',
  'Retail',
  'Sales',
  'Security',
  'Semiconductors',
  'Shipbuilding',
  'Software',
  'Sporting Goods',
  'Sports',
  'Staffing / Recruiting',
  'Taxes',
  'Technology',
  'Telecommunications',
  'Tourism',
  'Trade',
  'Training',
  'Transportation',
  'Utilities',
  'Ventures',
  'Volunteering',
  'Water',
  'Web Design',
  'Wholesale',
  'Other',
];

const List<String> kExpertiseOptions = [
  'React',
  'Flutter',
  'Spring Boot',
  'Node.js',
  'Python',
  'Java',
  'C++',
  'AI/ML',
  'Data Science',
  'Cloud Architecture',
  'Cybersecurity',
  'DevOps',
  'Blockchain',
  'Mobile Development',
  'Web Development',
  'UI/UX Design',
  'Product Management',
  'Product Strategy',
  'Leadership',
  'Project Management',
  'Agile / Scrum',
  'Marketing',
  'Digital Marketing',
  'SEO / SEM',
  'Content Strategy',
  'Sales',
  'Business Development',
  'Financial Analysis',
  'Investing',
  'Stock Market',
  'Accounting',
  'Legal & Compliance',
  'Human Resources',
  'Public Speaking',
  'Copywriting',
  'Graphic Design',
  'Data Analysis',
  'Other',
];

/// A searchable multi-select dropdown field widget with chip display,
/// instant search filter, and custom "Other" entry support.
class SearchableMultiSelectField extends StatelessWidget {
  final String label;
  final String placeholder;
  final List<String> options;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;
  final bool isRequired;
  final Map<String, String>? prioritiesMap;

  const SearchableMultiSelectField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.isRequired = false,
    this.prioritiesMap,
  });

  void _openPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchablePickerSheet(
        title: label,
        options: options,
        initialSelected: List<String>.from(selectedValues),
        onConfirmed: (newList) {
          onChanged(newList);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openPickerModal(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: selectedValues.isEmpty
                      ? Text(
                          placeholder,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            color: Color(0xFF8C736B),
                          ),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: selectedValues.map((val) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7A432D).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF7A432D).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    val,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF7A432D),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      final updated = List<String>.from(selectedValues)..remove(val);
                                      onChanged(updated);
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Color(0xFF7A432D),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF7A432D),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchablePickerSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String> initialSelected;
  final ValueChanged<List<String>> onConfirmed;

  const _SearchablePickerSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.onConfirmed,
  });

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  late List<String> _tempSelected;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  String _searchQuery = '';
  bool _showOtherInput = false;

  @override
  void initState() {
    super.initState();
    _tempSelected = List<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _addCustomOtherItem() {
    final customVal = _otherController.text.trim();
    if (customVal.isNotEmpty && !_tempSelected.contains(customVal)) {
      setState(() {
        _tempSelected.add(customVal);
        _otherController.clear();
        _showOtherInput = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredOptions = widget.options.where((opt) {
      if (_searchQuery.isEmpty) return true;
      return opt.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Sheet Handle ──
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E2DD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_tempSelected.length} selected',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _tempSelected.clear());
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Color(0xFF8C736B),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7A432D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: () {
                    widget.onConfirmed(_tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Search Input Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search ${widget.title.toLowerCase()}...',
                hintStyle: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: Color(0xFF8C736B),
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7A432D)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Selected Chips Preview Header ──
          if (_tempSelected.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: const Color(0xFFFAF0EB),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tempSelected.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(
                          item,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7A432D),
                          ),
                        ),
                        backgroundColor: Colors.white,
                        deleteIcon: const Icon(Icons.close, size: 12, color: Color(0xFF7A432D)),
                        onDeleted: () {
                          setState(() => _tempSelected.remove(item));
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF7A432D), width: 0.8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // ── Custom "Other" Entry Section ──
          if (_showOtherInput)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _otherController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Type custom entry...',
                        hintStyle: const TextStyle(fontSize: 12, fontFamily: 'PlusJakartaSans'),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7A432D)),
                        ),
                      ),
                      onSubmitted: (_) => _addCustomOtherItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
                    onPressed: _addCustomOtherItem,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),

          // ── Options List ──
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: filteredOptions.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE8E2DD)),
              itemBuilder: (ctx, idx) {
                final opt = filteredOptions[idx];
                final isOther = (opt == 'Other' || opt == 'Others');
                final isSelected = _tempSelected.contains(opt);

                return CheckboxListTile(
                  title: Text(
                    opt,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: isOther || isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isOther ? const Color(0xFF7A432D) : const Color(0xFF3E1F11),
                    ),
                  ),
                  value: isSelected,
                  activeColor: const Color(0xFF7A432D),
                  checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (val) {
                    setState(() {
                      if (isOther) {
                        _showOtherInput = !_showOtherInput;
                      } else {
                        if (val == true) {
                          if (!_tempSelected.contains(opt)) _tempSelected.add(opt);
                        } else {
                          _tempSelected.remove(opt);
                        }
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
