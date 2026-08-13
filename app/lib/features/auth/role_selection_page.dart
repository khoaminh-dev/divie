import 'package:flutter/material.dart';

import '../../core/roles/app_role.dart';
import '../../main.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key, required this.onSelected});

  final ValueChanged<AppRole> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18157680),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/branding/divie_logo.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bạn đang dùng DiVie với vai trò nào?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: DivieColors.navy,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Một tài khoản có thể dùng trên hai thiết bị. Chọn vai trò phù hợp cho thiết bị này.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: DivieColors.muted,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _RoleCard(
                    role: AppRole.family,
                    icon: Icons.family_restroom_rounded,
                    onTap: () => onSelected(AppRole.family),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    role: AppRole.elder,
                    icon: Icons.elderly_rounded,
                    onTap: () => onSelected(AppRole.elder),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Bạn có thể đổi vai trò trong phần Cài đặt bất cứ lúc nào.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DivieColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.onTap,
  });

  final AppRole role;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x180E7680)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFDDF8F8),
                child: Icon(icon, color: DivieColors.teal, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: const TextStyle(
                        color: DivieColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      role.description,
                      style: const TextStyle(
                        color: DivieColors.muted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: DivieColors.muted,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
