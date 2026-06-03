/// Model representing a single search result from the API.
class SearchResult {
  final String id;
  final int targetId;
  final String displayName;
  final String secondaryText;
  final String entityType;
  final String? listingType;

  const SearchResult({
    required this.id,
    required this.targetId,
    required this.displayName,
    required this.secondaryText,
    required this.entityType,
    this.listingType,
  });

  /// Safely parse a [SearchResult] from JSON.
  /// Returns `null` if required fields are missing or malformed.
  static SearchResult? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String?;
      final targetId = json['target_id'];
      final displayName = json['display_name'] as String?;
      final secondaryText = json['secondary_text'] as String?;
      final entityType = json['entity_type'] as String?;

      if (id == null ||
          targetId == null ||
          displayName == null ||
          secondaryText == null ||
          entityType == null) {
        return null;
      }

      return SearchResult(
        id: id,
        targetId: targetId is int ? targetId : int.tryParse(targetId.toString()) ?? 0,
        displayName: displayName,
        secondaryText: secondaryText,
        entityType: entityType,
        listingType: json['listing_type'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  bool get isProperty => entityType == 'Property';
  bool get isLocality => entityType == 'Locality' || entityType == 'City';
}

/// Model for a property returned from the /properties endpoint.
class Property {
  final int id;
  final String name;
  final String? location;
  final String? propertyType;
  final String? listingType;
  final String? status;
  final double? totalValue;
  final double? tokenPrice;
  final int? totalTokens;
  final int? availableTokens;
  final double? projectedYield;
  final String? imageUrl;
  final String? country;

  const Property({
    required this.id,
    required this.name,
    this.location,
    this.propertyType,
    this.listingType,
    this.status,
    this.totalValue,
    this.tokenPrice,
    this.totalTokens,
    this.availableTokens,
    this.projectedYield,
    this.imageUrl,
    this.country,
  });

  static Property? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'];
      final name = json['name'] as String? ??
          json['display_name'] as String? ??
          json['title'] as String? ??
          'Unnamed Property';

      if (id == null) return null;

      return Property(
        id: id is int ? id : int.tryParse(id.toString()) ?? 0,
        name: name,
        location: json['location'] as String? ?? json['secondary_text'] as String?,
        propertyType: json['property_type'] as String?,
        listingType: json['listing_type'] as String?,
        status: json['status'] as String?,
        totalValue: _toDouble(json['total_property_value'] ?? json['total_value'] ?? json['value']),
        tokenPrice: _toDouble(json['token_size'] ?? json['token_price']),
        totalTokens: _toInt(json['total_tokens']),
        availableTokens: _toInt(json['available_tokens']),
        projectedYield: _toDouble(json['projected_yield'] ?? json['yield']),
        imageUrl: json['image_url'] as String? ?? json['image'] as String?,
        country: json['country'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String get formattedValue {
    if (totalValue == null) return 'N/A';
    if (totalValue! >= 1000000) {
      return '\$${(totalValue! / 1000000).toStringAsFixed(2)}M';
    } else if (totalValue! >= 1000) {
      return '\$${(totalValue! / 1000).toStringAsFixed(1)}K';
    }
    return '\$${totalValue!.toStringAsFixed(0)}';
  }

  String get formattedTokenPrice {
    if (tokenPrice == null) return 'N/A';
    return '\$${tokenPrice!.toStringAsFixed(2)}';
  }

  String get formattedYield {
    if (projectedYield == null) return 'N/A';
    return '${projectedYield!.toStringAsFixed(1)}%';
  }
}
