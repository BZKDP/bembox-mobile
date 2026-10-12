// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  name: json['name'] as String?,
  phone: json['phone'] as String?,
  role: json['role'] as String? ?? 'user',
  telegramId: (json['telegramId'] as num?)?.toInt(),
  lastAddress: json['lastAddress'] as String?,
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'phone': instance.phone,
  'role': instance.role,
  'telegramId': instance.telegramId,
  'lastAddress': instance.lastAddress,
};
