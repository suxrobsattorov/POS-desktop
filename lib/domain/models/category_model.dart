class CategoryModel {
  final int id;
  final String name;
  final int? parentId;
  final String? color;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;
  final List<CategoryModel> children;

  const CategoryModel({
    required this.id,
    required this.name,
    this.parentId,
    this.color,
    this.imageUrl,
    this.isActive = true,
    this.sortOrder = 0,
    this.children = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      parentId: json['parentId'] as int?,
      color: json['color'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'color': color,
    'imageUrl': imageUrl,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };
}
