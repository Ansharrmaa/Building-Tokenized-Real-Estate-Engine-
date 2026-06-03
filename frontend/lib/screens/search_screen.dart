import 'dart:async';
import 'package:flutter/material.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final LayerLink _layerLink = LayerLink();

  Timer? _debounce;
  List<SearchResult> _results = [];
  bool _isLoading = false;
  bool _showDropdown = false;
  OverlayEntry? _overlayEntry;
  String? _selectedCountry;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        // Delay hiding so tap on dropdown item registers
        Future.delayed(const Duration(milliseconds: 200), () {
          _removeOverlay();
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _fadeController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty && (_selectedCountry == null || _selectedCountry!.isEmpty)) {
      setState(() {
        _results = [];
        _isLoading = false;
        _showDropdown = false;
      });
      _removeOverlay();
      return;
    }

    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await ApiService.search(query, country: _selectedCountry);
      if (mounted && _searchController.text == query) {
        setState(() {
          _results = results;
          _isLoading = false;
          _showDropdown = true;
        });
        if (_showDropdown) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    });
  }

  void _onSubmit(String query) {
    if (query.trim().isEmpty && (_selectedCountry == null || _selectedCountry!.isEmpty)) return;
    _removeOverlay();
    
    // If they hit enter, and we have results from the dropdown, just pass those IDs
    final ids = _results.where((r) => r.isProperty).map((r) => r.targetId).toList();
    
    Navigator.pushNamed(
      context,
      '/results',
      arguments: ResultsScreenArgs(
        query: query.trim().isEmpty ? 'Browsing Country' : query.trim(),
        propertyIds: ids,
      ),
    );
  }

  void _onSuggestionTap(SearchResult result) {
    _removeOverlay();
    if (result.isProperty) {
      Navigator.pushNamed(
        context,
        '/results',
        arguments: ResultsScreenArgs(
          query: result.displayName,
          propertyIds: [result.targetId],
        ),
      );
    } else {
      // Locality/City — search for all matching properties
      Navigator.pushNamed(
        context,
        '/results',
        arguments: ResultsScreenArgs(
          query: result.displayName,
          propertyIds: _results.where((r) => r.isProperty).map((r) => r.targetId).toList(),
        ),
      );
    }
  }

  // ── Overlay Management ────────────────────────────────────────
  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _showDropdown = false);
    }
  }

  OverlayEntry _buildOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final screenWidth = MediaQuery.of(context).size.width;
    final searchBarWidth = screenWidth > 720 ? 640.0 : screenWidth - 48;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: searchBarWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 64),
          child: Material(
            color: Colors.transparent,
            child: _buildDropdown(searchBarWidth),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(double width) {
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgCard.withOpacity(0.95),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.dropdownShadow,
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
              SizedBox(height: 12),
              Text(
                'No locations or properties found',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Currently unavailable in our tokenized market',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final properties = _results.where((r) => r.isProperty).toList();
    final localities = _results.where((r) => !r.isProperty).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withOpacity(0.95),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.dropdownShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (localities.isNotEmpty) ...[
                _sectionHeader('Locations', Icons.location_on_outlined, AppTheme.tagLocality),
                ...localities.map((r) => _suggestionTile(r)),
              ],
              if (localities.isNotEmpty && properties.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: AppTheme.border.withOpacity(0.5), height: 1),
                ),
              if (properties.isNotEmpty) ...[
                _sectionHeader('Properties', Icons.apartment_outlined, AppTheme.tagProperty),
                ...properties.map((r) => _suggestionTile(r)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionTile(SearchResult result) {
    final isProperty = result.isProperty;
    return InkWell(
      onTap: () => _onSuggestionTap(result),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isProperty ? AppTheme.tagProperty : AppTheme.tagLocality)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isProperty ? Icons.apartment : Icons.place,
                size: 18,
                color: isProperty ? AppTheme.tagProperty : AppTheme.tagLocality,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.secondaryText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (result.listingType != null) ...[
              const SizedBox(width: 8),
              _listingBadge(result.listingType!),
            ],
            const SizedBox(width: 8),
            _entityBadge(result.entityType),
          ],
        ),
      ),
    );
  }

  Widget _entityBadge(String type) {
    final color = type == 'Property' ? AppTheme.tagProperty : AppTheme.tagLocality;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        type,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _listingBadge(String type) {
    final color = type == 'Marketplace' ? AppTheme.tagMarketplace : AppTheme.tagSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        type,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 720;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // ── Logo & Brand ──
                  _buildLogo(),
                  const SizedBox(height: 16),
                  _buildSubtitle(),
                  const SizedBox(height: 48),
                  // ── Search Bar ──
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: SizedBox(
                      width: isWide ? 640 : double.infinity,
                      child: _buildSearchBar(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCountryFilter(),
                  const SizedBox(height: 24),
                  _buildQuickTags(),
                  const SizedBox(height: 80),
                  _buildFeatureCards(isWide),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          fontFamily: 'Inter',
        ),
        children: [
          TextSpan(
            text: 'Real',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          TextSpan(
            text: 'Token',
            style: TextStyle(color: AppTheme.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Discover tokenized real estate investment opportunities worldwide',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 17,
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.glowShadow,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        onSubmitted: _onSubmit,
        style: const TextStyle(
          fontSize: 16,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Search properties, cities, or locations...',
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(Icons.search_rounded, size: 22, color: AppTheme.textMuted),
          ),
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                )
              : _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20, color: AppTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
          filled: true,
          fillColor: AppTheme.bgCard.withOpacity(0.9),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryFilter() {
    final Map<String, String> countries = {
      'IN': 'India',
      'US': 'United States',
      'GB': 'United Kingdom',
      'AE': 'UAE',
      'SG': 'Singapore'
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.public, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        const Text('Browse by Country:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(width: 8),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCountry,
              hint: const Text('Global (All)', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              dropdownColor: AppTheme.bgCard,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.textMuted),
              style: const TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.w600),
              items: [
                const DropdownMenuItem(value: null, child: Text('Global (All)')),
                ...countries.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    )),
              ],
              onChanged: (val) {
                setState(() => _selectedCountry = val);
                // Trigger a search immediately if a country is selected
                _onSearchChanged(_searchController.text);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTags() {
    final tags = ['Dubai Marina', 'Manhattan', 'London', 'Singapore', 'Tokyo'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: tags.map((tag) {
        return ActionChip(
          label: Text(tag),
          avatar: const Icon(Icons.trending_up, size: 14, color: AppTheme.primaryLight),
          backgroundColor: AppTheme.bgCard,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.border),
          ),
          onPressed: () {
            _searchController.text = tag;
            _onSearchChanged(tag);
          },
        );
      }).toList(),
    );
  }

  Widget _buildFeatureCards(bool isWide) {
    final features = [
      _FeatureInfo(
        icon: Icons.token_outlined,
        title: 'Tokenized Assets',
        desc: 'Fractional ownership of premium real estate worldwide',
        color: AppTheme.primary,
      ),
      _FeatureInfo(
        icon: Icons.analytics_outlined,
        title: 'Smart Filters',
        desc: 'Filter by price, token size, property type, and more',
        color: AppTheme.accent,
      ),
      _FeatureInfo(
        icon: Icons.public_outlined,
        title: 'Global Coverage',
        desc: 'Properties from 50+ countries across every continent',
        color: AppTheme.accentWarm,
      ),
    ];

    if (isWide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: features
            .map((f) => Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _featureCard(f),
                  ),
                ))
            .toList(),
      );
    }

    return Column(
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _featureCard(f),
              ))
          .toList(),
    );
  }

  Widget _featureCard(_FeatureInfo info) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info.icon, color: info.color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            info.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureInfo {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _FeatureInfo({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
}
