/// Represents attribution requirements for Google Places Platform compliance.
///
/// Under Section 3.2.2 of the Google Maps Platform Terms of Service:
/// 1. "Powered by Google" logo/attribution must be displayed whenever Google
///    Places content or photos are shown outside an active Google Map.
/// 2. User-contributed photo author attributions must be displayed alongside photos.
class GoogleAttribution {
  final String displayName;
  final String? uri;
  final String? photoUri;

  const GoogleAttribution({required this.displayName, this.uri, this.photoUri});

  /// Factory from Google Places API (New) AuthorAttribution JSON.
  factory GoogleAttribution.fromJson(Map<String, dynamic> json) {
    return GoogleAttribution(
      displayName: json['displayName'] as String? ?? 'Google Maps Contributor',
      uri: json['uri'] as String?,
      photoUri: json['photoUri'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    if (uri != null) 'uri': uri,
    if (photoUri != null) 'photoUri': photoUri,
  };

  @override
  String toString() => 'GoogleAttribution($displayName, uri: $uri)';
}
