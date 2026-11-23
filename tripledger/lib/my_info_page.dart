import 'package:flutter/material.dart';

import 'api/api.dart';

class MyInfoPage extends StatefulWidget {
  const MyInfoPage({super.key});

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  static const Color primary = Color(0xFF3478EF);
  static const Color background = Color(0xFFF7F9FD);
  static const Color textColor = Color(0xFF20242D);
  static const Color mutedColor = Color(0xFF8791A3);
  static const Color cardBorder = Color(0xFFE9EDF5);
  static const Color dangerColor = Color(0xFFE05252);

  bool _busy = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _editDisplayName() async {
    if (_busy) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => _EditNameSheet(initialName: AuthApi.displayName),
    );

    if (updated == true && mounted) {
      setState(() {});
      _showMessage('이름이 변경되었습니다.');
    }
  }

  Future<void> _changePassword() async {
    if (_busy) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => const _ChangePasswordSheet(),
    );

    if (changed == true && mounted) {
      _showMessage('비밀번호가 변경되었습니다.');
    }
  }

  Future<void> _logout() async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '로그아웃 하시겠습니까?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            '다시 로그인하면 저장된 여행 기록을 계속 확인할 수 있습니다.',
            style: TextStyle(
              color: mutedColor,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                '취소',
                style: TextStyle(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                '로그아웃',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AuthApi.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;

    final result = await showDialog<_DeleteConfirmResult>(
      context: context,
      builder: (_) =>
          _DeleteAccountDialog(requirePassword: AuthApi.isPasswordUser),
    );

    if (result == null || !result.confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await AccountApi.deleteAccount(password: result.password);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object?>(
      stream: AuthApi.userChanges,
      builder: (context, _) {
        final displayName = AuthApi.displayName;
        final email = AuthApi.email;
        final isPasswordUser = AuthApi.isPasswordUser;

        return Stack(
          children: [
            Scaffold(
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
                      child: const Icon(
                        Icons.person_rounded,
                        color: primary,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      email ?? '이메일 정보 없음',
                      style: const TextStyle(fontSize: 13, color: mutedColor),
                    ),
                  ),
                  const SizedBox(height: 35),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.person_outline_rounded,
                          title: '이름',
                          value: displayName,
                          onTap: _editDisplayName,
                        ),
                        const Divider(height: 25),
                        _InfoRow(
                          icon: Icons.email_outlined,
                          title: '이메일',
                          value: email ?? '정보 없음',
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
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: [
                        _ActionRow(
                          icon: Icons.badge_outlined,
                          title: '이름 변경',
                          onTap: _editDisplayName,
                        ),
                        if (isPasswordUser) ...[
                          const Divider(height: 1),
                          _ActionRow(
                            icon: Icons.lock_outline_rounded,
                            title: '비밀번호 변경',
                            onTap: _changePassword,
                          ),
                        ],
                        const Divider(height: 1),
                        _ActionRow(
                          icon: Icons.logout_rounded,
                          title: '로그아웃',
                          onTap: _logout,
                        ),
                        const Divider(height: 1),
                        _ActionRow(
                          icon: Icons.person_off_outlined,
                          title: '회원 탈퇴',
                          color: dangerColor,
                          onTap: _deleteAccount,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            if (_busy)
              Container(
                color: Colors.black.withValues(alpha: 0.18),
                child: const Center(
                  child: CircularProgressIndicator(color: primary),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
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
        if (onTap != null) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF8791A3),
            size: 18,
          ),
        ],
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = const Color(0xFF20242D),
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(
              icon,
              color: color == const Color(0xFF20242D)
                  ? const Color(0xFF8791A3)
                  : color,
              size: 21,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8791A3),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// 이름 변경 바텀시트 (AddTripSheet / EditTripSheet 동일 스타일)
// ==================================================

class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({required this.initialName});

  final String initialName;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final nextName = _nameController.text.trim();
    if (nextName == widget.initialName) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthApi.updateDisplayName(nextName);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '이름 변경',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '새로운 이름을 입력해 주세요.',
                style: TextStyle(color: Color(0xFF8791A3), fontSize: 13),
              ),
              const SizedBox(height: 25),
              const Padding(
                padding: EdgeInsets.only(bottom: 9),
                child: Text(
                  '이름',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              TextFormField(
                controller: _nameController,
                maxLength: 20,
                autofocus: true,
                validator: AuthApi.validateName,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: '이름을 입력해주세요',
                  filled: true,
                  fillColor: const Color(0xFFF7F9FC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '변경사항 저장',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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
}

// ==================================================
// 비밀번호 변경 바텀시트
// ==================================================

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      await AuthApi.changePassword(
        _currentPwController.text,
        _newPwController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF8791A3),
          size: 20,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '비밀번호 변경',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '영문과 숫자를 포함해 8자 이상으로 설정해 주세요.',
                style: TextStyle(color: Color(0xFF8791A3), fontSize: 13),
              ),
              const SizedBox(height: 25),
              const Padding(
                padding: EdgeInsets.only(bottom: 9),
                child: Text(
                  '현재 비밀번호',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              TextFormField(
                controller: _currentPwController,
                obscureText: _obscureCurrent,
                textInputAction: TextInputAction.next,
                validator: AuthApi.validatePassword,
                decoration: _inputDecoration(
                  hint: '현재 비밀번호 입력',
                  obscure: _obscureCurrent,
                  onToggle: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(bottom: 9),
                child: Text(
                  '새 비밀번호',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              TextFormField(
                controller: _newPwController,
                obscureText: _obscureNew,
                textInputAction: TextInputAction.next,
                validator: AuthApi.validateNewPassword,
                decoration: _inputDecoration(
                  hint: '새 비밀번호 입력 (8자 이상, 영문+숫자)',
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(bottom: 9),
                child: Text(
                  '새 비밀번호 확인',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              TextFormField(
                controller: _confirmPwController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                validator:
                    AuthApi.validatePasswordMatch(() => _newPwController.text),
                onFieldSubmitted: (_) => _submit(),
                decoration: _inputDecoration(
                  hint: '새 비밀번호 다시 입력',
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '비밀번호 변경',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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
}

// ==================================================
// 회원 탈퇴 확인 다이얼로그
// ==================================================

class _DeleteConfirmResult {
  const _DeleteConfirmResult({required this.confirmed, this.password});
  final bool confirmed;
  final String? password;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.requirePassword});

  final bool requirePassword;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (widget.requirePassword && !_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      _DeleteConfirmResult(
        confirmed: true,
        password: widget.requirePassword ? _passwordController.text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '회원 탈퇴를 진행하겠습니까?',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '탈퇴 시 모든 여행 일정과 지출 기록이 삭제됩니다.\n'
              '삭제한 데이터는 복구할 수 없습니다.',
              style: TextStyle(
                color: Color(0xFF8791A3),
                fontSize: 13,
                height: 1.6,
              ),
            ),
            if (widget.requirePassword) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                autofocus: true,
                validator: AuthApi.validatePassword,
                onFieldSubmitted: (_) => _confirm(),
                decoration: InputDecoration(
                  hintText: '비밀번호 입력',
                  filled: true,
                  fillColor: const Color(0xFFF7F9FC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF8791A3),
                      size: 20,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '탈퇴하기를 누르면 ${AuthApi.loginMethodLabel} 본인 확인 창이 열립니다.',
                style: const TextStyle(
                  color: Color(0xFF4268A8),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '취소',
            style: TextStyle(
              color: Color(0xFF8791A3),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _confirm,
          child: const Text(
            '탈퇴하기',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
