import 'package:flutter/material.dart';

enum _AthleteHomeAccountAction { theme, signOut }

class AthleteHomeAccountMenu extends StatelessWidget {
  final VoidCallback onChangeTheme;
  final VoidCallback onSignOut;

  const AthleteHomeAccountMenu({
    super.key,
    required this.onChangeTheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AthleteHomeAccountAction>(
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) {
        switch (action) {
          case _AthleteHomeAccountAction.theme:
            onChangeTheme();
            break;
          case _AthleteHomeAccountAction.signOut:
            onSignOut();
            break;
        }
      },
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: _AthleteHomeAccountAction.theme,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.brightness_6_outlined),
                title: Text('Tema'),
              ),
            ),
            PopupMenuItem(
              value: _AthleteHomeAccountAction.signOut,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded),
                title: Text('Sair'),
              ),
            ),
          ],
    );
  }
}

class AthleteMinimalHeader extends StatelessWidget {
  final VoidCallback onChangeTheme;
  final VoidCallback onSignOut;

  const AthleteMinimalHeader({
    super.key,
    required this.onChangeTheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TITANS BJJ',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Início',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        AthleteHomeAccountMenu(
          onChangeTheme: onChangeTheme,
          onSignOut: onSignOut,
        ),
      ],
    );
  }
}
