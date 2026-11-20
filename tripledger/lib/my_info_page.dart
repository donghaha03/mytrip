import 'package:flutter/material.dart';

import 'api/api.dart';

class MyInfoPage extends StatelessWidget {
  const MyInfoPage({super.key});

  static const Color primary = Color(0xFF3478EF);
  static const Color background = Color(0xFFF7F9FD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          '내 정보',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFE7EEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: primary, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              AuthApi.displayName,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20242D),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              AuthApi.email ?? '이메일 정보 없음',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8791A3)),
            ),
          ),
          const SizedBox(height: 35),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9EDF5)),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  title: '이름',
                  value: AuthApi.displayName,
                ),
                const Divider(height: 25),
                _InfoRow(
                  icon: Icons.email_outlined,
                  title: '이메일',
                  value: AuthApi.email ?? '정보 없음',
                ),
                const Divider(height: 25),
                _InfoRow(
                  icon: Icons.login_rounded,
                  title: '로그인 방식',
                  value: AuthApi.loginMethodLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '현재 임시 내 정보 페이지입니다. '
                    '추후 프로필 관리 기능으로 교체할 예정입니다.',
                    style: TextStyle(
                      color: Color(0xFF4268A8),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8791A3), size: 21),
        const SizedBox(width: 13),
        SizedBox(
          width: 85,
          child: Text(
            title,
            style: const TextStyle(color: Color(0xFF8791A3), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF20242D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
