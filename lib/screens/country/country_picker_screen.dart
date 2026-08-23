import 'package:flutter/material.dart';

class Country {
  final String name;
  final String code;
  final String flag;

  Country({required this.name, required this.code, required this.flag});
}

class CountryPickerScreen extends StatefulWidget {
  const CountryPickerScreen({super.key});

  @override
  State<CountryPickerScreen> createState() => _CountryPickerScreenState();
}

class _CountryPickerScreenState extends State<CountryPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedLetter;
  bool _showLetterPopup = false;

  static const List<String> _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  final List<Country> _allCountries = [
    Country(name: 'United States', code: 'US', flag: '🇺🇸'),
    Country(name: 'China', code: 'CN', flag: '🇨🇳'),
    Country(name: 'India', code: 'IN', flag: '🇮🇳'),
    Country(name: 'Indonesia', code: 'ID', flag: '🇮🇩'),
    Country(name: 'Brazil', code: 'BR', flag: '🇧🇷'),
    Country(name: 'Pakistan', code: 'PK', flag: '🇵🇰'),
    Country(name: 'Nigeria', code: 'NG', flag: '🇳🇬'),
    Country(name: 'Bangladesh', code: 'BD', flag: '🇧🇩'),
    Country(name: 'Russia', code: 'RU', flag: '🇷🇺'),
    Country(name: 'Mexico', code: 'MX', flag: '🇲🇽'),
  ];

  List<Country> _filteredCountries = [];

  @override
  void initState() {
    super.initState();
    _filteredCountries = _allCountries;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredCountries = _allCountries;
      } else {
        _filteredCountries = _allCountries
            .where((country) =>
                country.name.toLowerCase().contains(query) ||
                country.code.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _onSidebarLetterTap(String letter) {
    final index = _filteredCountries.indexWhere(
      (c) => c.name.toUpperCase().startsWith(letter),
    );
    if (index >= 0 && _scrollController.hasClients) {
      _scrollController.animateTo(
        index * 56.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    setState(() {
      _selectedLetter = letter;
      _showLetterPopup = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showLetterPopup = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Country')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.search,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _filteredCountries.length,
                  itemBuilder: (context, index) {
                    final country = _filteredCountries[index];
                    return ListTile(
                      leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                      title: Text(country.name),
                      trailing: Text('+${1 + index}000'),
                      onTap: () {
                        Navigator.pop(context, country);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 60,
            bottom: 0,
            child: _buildSidebar(),
          ),
          if (_showLetterPopup && _selectedLetter != null)
            Center(
              child: Container(
                width: 60,
                height: 60,
                color: const Color(0x80000000),
                alignment: Alignment.center,
                child: Text(
                  _selectedLetter!,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 20,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_letters.length, (i) {
          final letter = _letters[i];
          final isSelected = _selectedLetter == letter;
          return GestureDetector(
            onTap: () => _onSidebarLetterTap(letter),
            child: SizedBox(
              width: 20,
              height: 14,
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? const Color(0xFFCC3333) : const Color(0xFF888888),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
