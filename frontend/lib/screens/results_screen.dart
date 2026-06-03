import 'package:flutter/material.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Arguments passed from the search screen to the results screen.
class ResultsScreenArgs {
  final String query;
  final List<int> propertyIds;

  const ResultsScreenArgs({
    required this.query,
    required this.propertyIds,
  });
}

class ResultsScreen extends StatefulWidget {
  final ResultsScreenArgs args;

  const ResultsScreen({super.key, required this.args});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<Property> _allProperties = [];
  List<Property> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ── Filter State ──────────────────────────────────────────────
  String? _selectedListingType;
  String? _selectedStatus;
  String? _selectedPropertyType;
  RangeValues _priceRange = const RangeValues(0, 50000000);
  RangeValues _tokenRange = const RangeValues(0, 100000);

  final List<String> _listingTypes = ['All', 'Marketplace', 'Secondary', 'Primary'];
  final List<String> _statuses = ['All', 'Active', 'Upcoming', 'Sold Out', 'Funded'];
  final List<String> _propertyTypes = [
    'All', 'Residential', 'Commercial', 'Office', 'Retail',
    'Industrial', 'Mixed Use', 'Hotel', 'Land',
  ];

  static const double _maxPrice = 50000000;
  static const double _maxTokens = 100000;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final properties = await ApiService.getProperties(
        ids: widget.args.propertyIds.isNotEmpty ? widget.args.propertyIds : null,
      );

      if (mounted) {
        setState(() {
          _allProperties = properties;
          _isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load properties. Please try again.';
        });
      }
    }
  }

  void _applyFilters() {
    var result = List<Property>.from(_allProperties);

    // Listing type filter
    if (_selectedListingType != null && _selectedListingType != 'All') {
      result = result.where((p) =>
          p.listingType?.toLowerCase() == _selectedListingType!.toLowerCase()).toList();
    }

    // Status filter
    if (_selectedStatus != null && _selectedStatus != 'All') {
      result = result.where((p) =>
          p.status?.toLowerCase() == _selectedStatus!.toLowerCase()).toList();
    }

    // Property type filter
    if (_selectedPropertyType != null && _selectedPropertyType != 'All') {
      result = result.where((p) =>
          p.propertyType?.toLowerCase() == _selectedPropertyType!.toLowerCase()).toList();
    }

    // Price range filter
    if (_priceRange.start > 0 || _priceRange.end < _maxPrice) {
      result = result.where((p) {
        final val = p.totalValue ?? 0;
        return val >= _priceRange.start && val <= _priceRange.end;
      }).toList();
    }

    // Token range filter
    if (_tokenRange.start > 0 || _tokenRange.end < _maxTokens) {
      result = result.where((p) {
        final tokens = p.totalTokens ?? 0;
        return tokens >= _tokenRange.start && tokens <= _tokenRange.end;
      }).toList();
    }

    setState(() => _filtered = result);
  }

  void _resetFilters() {
    setState(() {
      _selectedListingType = null;
      _selectedStatus = null;
      _selectedPropertyType = null;
      _priceRange = const RangeValues(0, _maxPrice);
      _tokenRange = const RangeValues(0, _maxTokens);
      _applyFilters();
    });
  }

  bool get _hasActiveFilters =>
      _selectedListingType != null && _selectedListingType != 'All' ||
      _selectedStatus != null && _selectedStatus != 'All' ||
      _selectedPropertyType != null && _selectedPropertyType != 'All' ||
      _priceRange.start > 0 ||
      _priceRange.end < _maxPrice ||
      _tokenRange.start > 0 ||
      _tokenRange.end < _maxTokens;

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bgDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Back to search',
      ),
      title: Row(
        children: [
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Real',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                TextSpan(
                  text: 'Token',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                      ),
                      Expanded(
                        child: Text(
                          widget.args.query,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  // ── Wide (Desktop) Layout: sidebar + grid ─────────────────────
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter sidebar
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: AppTheme.bgCard.withOpacity(0.6),
            border: const Border(right: BorderSide(color: AppTheme.border)),
          ),
          child: _buildFilterPanel(),
        ),
        // Results area
        Expanded(child: _buildResultsArea()),
      ],
    );
  }

  // ── Narrow (Mobile) Layout: filter bar + list ─────────────────
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        // Compact filter bar
        _buildCompactFilters(),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(child: _buildResultsArea()),
      ],
    );
  }

  // ── Filter Panel (Desktop Sidebar) ────────────────────────────
  Widget _buildFilterPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          _filterSection('Listing Type', _listingTypes, _selectedListingType, (val) {
            setState(() {
              _selectedListingType = val;
              _applyFilters();
            });
          }),

          _filterSection('Status', _statuses, _selectedStatus, (val) {
            setState(() {
              _selectedStatus = val;
              _applyFilters();
            });
          }),

          _filterSection('Property Type', _propertyTypes, _selectedPropertyType, (val) {
            setState(() {
              _selectedPropertyType = val;
              _applyFilters();
            });
          }),

          const SizedBox(height: 20),
          _rangeSliderSection(
            'Price Range',
            _priceRange,
            0,
            _maxPrice,
            (range) {
              setState(() {
                _priceRange = range;
                _applyFilters();
              });
            },
            formatValue: _formatCurrency,
          ),

          const SizedBox(height: 20),
          _rangeSliderSection(
            'Token Size',
            _tokenRange,
            0,
            _maxTokens,
            (range) {
              setState(() {
                _tokenRange = range;
                _applyFilters();
              });
            },
            formatValue: _formatTokens,
          ),
        ],
      ),
    );
  }

  Widget _filterSection(
    String title,
    List<String> options,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((opt) {
              final isSelected = selected == opt || (selected == null && opt == 'All');
              return GestureDetector(
                onTap: () => onChanged(opt == 'All' ? null : opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.15)
                        : AppTheme.bgSurface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _rangeSliderSection(
    String title,
    RangeValues values,
    double min,
    double max,
    ValueChanged<RangeValues> onChanged, {
    required String Function(double) formatValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${formatValue(values.start)} – ${formatValue(values.end)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: AppTheme.bgSurface,
            thumbColor: AppTheme.primaryLight,
            overlayColor: AppTheme.primary.withOpacity(0.12),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: RangeSlider(
            values: values,
            min: min,
            max: max,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ── Compact Filters (Mobile) ──────────────────────────────────
  Widget _buildCompactFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withOpacity(0.6),
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _compactFilterChip('Type', _selectedPropertyType, _propertyTypes, (val) {
              setState(() { _selectedPropertyType = val; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            _compactFilterChip('Listing', _selectedListingType, _listingTypes, (val) {
              setState(() { _selectedListingType = val; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            _compactFilterChip('Status', _selectedStatus, _statuses, (val) {
              setState(() { _selectedStatus = val; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            if (_hasActiveFilters)
              ActionChip(
                avatar: const Icon(Icons.close, size: 14, color: AppTheme.error),
                label: const Text('Clear'),
                onPressed: _resetFilters,
                backgroundColor: AppTheme.bgSurface,
                labelStyle: const TextStyle(fontSize: 12, color: AppTheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: AppTheme.border),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _compactFilterChip(
    String label,
    String? selected,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return PopupMenuButton<String>(
      onSelected: (val) => onChanged(val == 'All' ? null : val),
      offset: const Offset(0, 40),
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      itemBuilder: (_) => options.map((opt) {
        final isActive = selected == opt || (selected == null && opt == 'All');
        return PopupMenuItem(
          value: opt,
          child: Text(
            opt,
            style: TextStyle(
              fontSize: 13,
              color: isActive ? AppTheme.primaryLight : AppTheme.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected != null ? AppTheme.primary.withOpacity(0.12) : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected != null ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected ?? label,
              style: TextStyle(
                fontSize: 12,
                color: selected != null ? AppTheme.primaryLight : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: selected != null ? AppTheme.primaryLight : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ── Results Area ──────────────────────────────────────────────
  Widget _buildResultsArea() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
            SizedBox(height: 16),
            Text(
              'Loading properties...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadProperties,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Inter'),
                  children: [
                    TextSpan(
                      text: '${_filtered.length}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' ${_filtered.length == 1 ? 'property' : 'properties'} found',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasActiveFilters)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_rounded, size: 14, color: AppTheme.primaryLight),
                      SizedBox(width: 4),
                      Text(
                        'Filtered',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Results list
        if (_filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: AppTheme.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No properties match your filters',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try adjusting your search or filter criteria',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset Filters'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: _filtered.length,
              itemBuilder: (context, index) => _buildPropertyCard(_filtered[index]),
            ),
          ),
      ],
    );
  }

  // ── Property Card ─────────────────────────────────────────────
  Widget _buildPropertyCard(Property property) {
    return _PropertyCardInteractive(property: property);
  }

  Widget _statChip(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppTheme.success;
      case 'upcoming':
        return AppTheme.accentWarm;
      case 'sold out':
        return AppTheme.error;
      case 'funded':
        return AppTheme.primary;
      default:
        return AppTheme.textMuted;
    }
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}K';
    return '\$${value.toStringAsFixed(0)}';
  }

  String _formatTokens(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

class _PropertyCardInteractive extends StatefulWidget {
  final Property property;
  const _PropertyCardInteractive({required this.property});

  @override
  State<_PropertyCardInteractive> createState() => _PropertyCardInteractiveState();
}

class _PropertyCardInteractiveState extends State<_PropertyCardInteractive> {
  double _tokensToBuy = 1.0;

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final maxTokens = (property.availableTokens ?? 100).toDouble().clamp(1.0, 1000.0);
    if (_tokensToBuy > maxTokens) {
      _tokensToBuy = maxTokens;
    }

    final tokenPrice = property.tokenPrice ?? 50.0;
    final yieldRate = property.projectedYield ?? 8.5; // Default to 8.5% if null
    final capitalRequired = _tokensToBuy * tokenPrice;
    final annualReturn = capitalRequired * (yieldRate / 100.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          hoverColor: AppTheme.bgCardHover,
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Property image thumbnail
                Container(
                  width: 120,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: const DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1512917774080-9991f1c4c750?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Property info & Interactive Slider
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              property.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (property.propertyType != null)
                            _badge(property.propertyType!, AppTheme.tagProperty),
                          if (property.status != null) ...[
                            const SizedBox(width: 8),
                            _badge(property.status!, _statusColor(property.status!)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (property.location != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                property.location!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      // Interactive Calculator Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calculate_outlined, size: 16, color: AppTheme.primaryLight),
                                const SizedBox(width: 8),
                                const Text(
                                  'Investment Calculator',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                _statChip(Icons.token_outlined, 'Price', property.formattedTokenPrice),
                                const SizedBox(width: 12),
                                _statChip(Icons.trending_up_rounded, 'Yield', '${yieldRate.toStringAsFixed(1)}%', valueColor: AppTheme.accent),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Tokens to Buy:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                          Text('${_tokensToBuy.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryLight)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      SliderTheme(
                                        data: SliderThemeData(
                                          activeTrackColor: AppTheme.primary,
                                          inactiveTrackColor: AppTheme.border,
                                          thumbColor: AppTheme.primaryLight,
                                          overlayColor: AppTheme.primary.withOpacity(0.2),
                                          trackHeight: 4.0,
                                        ),
                                        child: Slider(
                                          value: _tokensToBuy,
                                          min: 1.0,
                                          max: maxTokens,
                                          divisions: maxTokens > 1 ? maxTokens.toInt() - 1 : 1,
                                          onChanged: (val) {
                                            setState(() {
                                              _tokensToBuy = val;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgCard,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accent.withOpacity(0.05),
                                        blurRadius: 8,
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Expected Return', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '\$${annualReturn.toStringAsFixed(0)} / yr',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Req: \$${capitalRequired.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppTheme.success;
      case 'upcoming':
        return AppTheme.accentWarm;
      case 'sold out':
        return AppTheme.error;
      case 'funded':
        return AppTheme.primary;
      default:
        return AppTheme.textMuted;
    }
  }
}
