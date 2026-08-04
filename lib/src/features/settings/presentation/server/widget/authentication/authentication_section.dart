import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../constants/enum.dart';
import '../../../../../../global_providers/global_providers.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../widgets/section_title.dart';
import '../credential_popup/credentials_popup.dart';
import 'auth_type/auth_type_tile.dart';
import 'ui_login/ui_login_popup.dart';

class AuthenticationSection extends ConsumerWidget {
  const AuthenticationSection({super.key});

  @override
  Widget build(context, ref) {
    final authType = ref.watch(authTypeKeyProvider);
    final isUiLoggedIn = authType == AuthType.uiLogin &&
        ref.watch(
          authSessionProvider.select((session) => session.isLoggedIn),
        );
    final isUiLoginLoading = authType == AuthType.uiLogin &&
        ref.watch(
          authSessionProvider.select((session) => session.isLoading),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: context.l10n.authentication),
        const AuthTypeTile(),
        if (authType == AuthType.basic)
          ListTile(
            leading: const Icon(Icons.password_rounded),
            title: Text(context.l10n.credentials),
            onTap: () {
              showDialog(
                context: context,
                useRootNavigator: false,
                builder: (context) => const CredentialsPopup(),
              );
            },
          ),
        if (authType == AuthType.uiLogin)
          ListTile(
            leading: const Icon(Icons.login_rounded),
            title: Text(context.l10n.login),
            subtitle: Text(
              isUiLoggedIn
                  ? context.l10n.loggedIn
                  : context.l10n.notLoggedIn,
            ),
            trailing: isUiLoggedIn
                ? IconButton(
                    tooltip: context.l10n.logout,
                    onPressed: isUiLoginLoading
                        ? null
                        : () => unawaited(
                              ref.read(authSessionProvider).logout(),
                            ),
                    icon: const Icon(Icons.logout_rounded),
                  )
                : null,
            onTap: isUiLoginLoading
                ? null
                : () {
                    showDialog(
                      context: context,
                      useRootNavigator: false,
                      builder: (context) => const UiLoginPopup(),
                    );
                  },
          ),
      ],
    );
  }
}
