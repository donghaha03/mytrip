import 'package:flutter/material.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool allAgree = false;
  bool serviceAgree = false;
  bool privacyAgree = false;
  bool marketingAgree = false;

  void _updateAllAgree() {
    setState(() {
      allAgree =
          serviceAgree && privacyAgree && marketingAgree;
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      allAgree = value;
      serviceAgree = value;
      privacyAgree = value;
      marketingAgree = value;
    });
  }

  void _next() {
    if (!serviceAgree || !privacyAgree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 약관에 동의해주세요.'),
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF16181D),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '약관 동의',
          style: TextStyle(
            color: Color(0xFF16181D),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRIPER 시작하기',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16181D),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                '서비스 이용을 위해 약관에 동의해주세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 32),

              // 전체 동의
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: allAgree,
                      activeColor: const Color(0xFF2F6FED),
                      onChanged: (value) {
                        _toggleAll(value ?? false);
                      },
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        '전체 약관에 동의합니다.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16181D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 서비스 이용약관
              _buildAgreement(
                title: '[필수] 서비스 이용약관',
                value: serviceAgree,
                onChanged: (value) {
                  setState(() {
                    serviceAgree = value ?? false;
                    _updateAllAgree();
                  });
                },
              ),

              const SizedBox(height: 10),

              // 개인정보
              _buildAgreement(
                title: '[필수] 개인정보 수집 및 이용',
                value: privacyAgree,
                onChanged: (value) {
                  setState(() {
                    privacyAgree = value ?? false;
                    _updateAllAgree();
                  });
                },
              ),

              const SizedBox(height: 10),

              // 마케팅
              _buildAgreement(
                title: '[선택] 마케팅 정보 수신 동의',
                value: marketingAgree,
                onChanged: (value) {
                  setState(() {
                    marketingAgree = value ?? false;
                    _updateAllAgree();
                  });
                },
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F6FED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '동의하고 계속하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgreement({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            activeColor: const Color(0xFF2F6FED),
            onChanged: onChanged,
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF16181D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF9EA6B3),
          ),
        ],
      ),
    );
  }
}