// dart
class PageItem {
  final String description;
  final String url;

  PageItem({required this.description, required this.url});

  factory PageItem.fromJson(Map<String, dynamic> json) {
    return PageItem(
      description: json['description']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PageItem && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'PageItem(description: $description, url: $url)';
}
