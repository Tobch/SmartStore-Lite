import 'package:uuid/uuid.dart';

class LocationModel {
  final String id;
  final String name;
  final String code;
  final bool isWarehouse;

  LocationModel({
    String? id,
    required this.name,
    required this.code,
    this.isWarehouse = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'is_warehouse': isWarehouse ? 1 : 0,
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      isWarehouse: (map['is_warehouse'] as int) == 1,
    );
  }
}