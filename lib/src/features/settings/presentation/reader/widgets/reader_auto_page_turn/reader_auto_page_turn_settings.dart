// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../../constants/db_keys.dart';
import '../../../../../../constants/enum.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/mixin/shared_preferences_client_mixin.dart';
import '../../../../../../widgets/popup_widgets/radio_list_popup.dart';
import '../../../../widgets/slider_setting_tile/slider_setting_tile.dart';

part 'reader_auto_page_turn_settings.g.dart';

@riverpod
class ReaderAutoPageTurnInterval extends _$ReaderAutoPageTurnInterval
    with SharedPreferenceClientMixin<double> {
  @override
  double? build() => initialize(DBKeys.autoPageTurnInterval);
}

@riverpod
class ReaderAutoPageTurnTransition extends _$ReaderAutoPageTurnTransition
    with SharedPreferenceEnumClientMixin<AutoPageTurnTransition> {
  @override
  AutoPageTurnTransition? build() => initialize(
        DBKeys.autoPageTurnTransition,
        enumList: AutoPageTurnTransition.values,
      );
}

class ReaderAutoPageTurnIntervalSlider extends ConsumerWidget {
  const ReaderAutoPageTurnIntervalSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(readerAutoPageTurnIntervalProvider) ??
        DBKeys.autoPageTurnInterval.initial as double;

    return SliderSettingTile(
      icon: Icons.timer_outlined,
      title: context.l10n.autoPageTurnInterval,
      value: interval,
      defaultValue: DBKeys.autoPageTurnInterval.initial,
      min: 0.5,
      max: 60,
      getSliderLabel: (value) {
        final seconds = value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(1);
        return context.l10n.autoPageTurnIntervalValue(seconds);
      },
      onChanged: (value) => ref
          .read(readerAutoPageTurnIntervalProvider.notifier)
          .update((value * 2).round() / 2),
    );
  }
}

class ReaderAutoPageTurnTransitionTile extends ConsumerWidget {
  const ReaderAutoPageTurnTransitionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transition = ref.watch(readerAutoPageTurnTransitionProvider) ??
        DBKeys.autoPageTurnTransition.initial as AutoPageTurnTransition;

    return ListTile(
      leading: const Icon(Icons.animation_rounded),
      title: Text(context.l10n.autoPageTurnTransition),
      subtitle: Text(transition.toLocale(context)),
      onTap: () => showDialog(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => RadioListPopup<AutoPageTurnTransition>(
          title: dialogContext.l10n.autoPageTurnTransition,
          optionList: AutoPageTurnTransition.values,
          value: transition,
          getOptionTitle: (value) => value.toLocale(dialogContext),
          onChange: (value) {
            ref
                .read(readerAutoPageTurnTransitionProvider.notifier)
                .update(value);
            Navigator.pop(dialogContext);
          },
        ),
      ),
    );
  }
}
