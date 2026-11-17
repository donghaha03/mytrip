import 'package:flutter/material.dart';

/// 지원 통화 (주요 여행지 화폐)
const currencies = ['USD', 'JPY', 'EUR', 'CNY', 'VND', 'THB', 'PHP', 'TWD'];

/// 카테고리별 대표 아이콘 (키 = 카테고리 이름)
const categoryIcons = <String, IconData>{
  '식비': Icons.restaurant,
  '교통': Icons.directions_transit,
  '숙박': Icons.hotel,
  '쇼핑': Icons.shopping_bag,
  '관광': Icons.photo_camera,
  '기타': Icons.more_horiz,
};

IconData iconOfCategory(String category) =>
    categoryIcons[category] ?? Icons.more_horiz;
