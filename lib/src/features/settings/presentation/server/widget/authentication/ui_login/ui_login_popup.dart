// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../../global_providers/global_providers.dart';
import '../../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../../utils/misc/toast/toast.dart';
import '../../../../../controller/server_controller.dart';

class UiLoginPopup extends HookConsumerWidget {
  const UiLoginPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final username = useTextEditingController();
    final password = useTextEditingController();
    final obscurePassword = useState(true);
    final isLoading = ref.watch(
      authSessionProvider.select((session) => session.isLoading),
    );

    Future<void> submit() async {
      if (!(formKey.currentState?.validate()).ifNull() || isLoading) return;

      final result = await AsyncValue.guard(
        () => ref.read(authSessionProvider).login(
              username: username.text,
              password: password.text,
            ),
      );
      if (!context.mounted) return;
      result.showToastOnError(ref.read(toastProvider));
      if (!result.hasError) {
        ref.invalidate(settingsProvider);
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted) Navigator.pop(context);
      }
    }

    return PopScope(
      canPop: !isLoading,
      child: AlertDialog(
        title: Text(context.l10n.login),
        content: AutofillGroup(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  controller: username,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      value.isBlank ? context.l10n.errorUserName : null,
                  decoration: InputDecoration(
                    labelText: context.l10n.userName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const Gap(12),
                TextFormField(
                  autofillHints: const [AutofillHints.password],
                  autocorrect: false,
                  controller: password,
                  enabled: !isLoading,
                  enableSuggestions: false,
                  obscureText: obscurePassword.value,
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      value.isBlank ? context.l10n.errorPassword : null,
                  onFieldSubmitted: (_) {
                    if (!isLoading) unawaited(submit());
                  },
                  decoration: InputDecoration(
                    labelText: context.l10n.password,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword.value
                          ? context.l10n.showPassword
                          : context.l10n.hidePassword,
                      onPressed: () =>
                          obscurePassword.value = !obscurePassword.value,
                      icon: Icon(
                        obscurePassword.value
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: isLoading ? null : () => unawaited(submit()),
            child: isLoading
                ? Semantics(
                    label: context.l10n.login,
                    child: const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Text(context.l10n.login),
          ),
        ],
      ),
    );
  }
}
