import 'package:flutter/material.dart';
import '../widgets/screen_top_bar.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Column(children: [ScreenTopBar(title: '더보기')]),
    ),
  );
}
