import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/data/home_parcel_repository.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelsAsync = ref.watch(homeParcelsProvider);

    return parcelsAsync.when(
      data: (items) {
        final historyItems = items
            .where((item) => item.status == 'completed' || item.status == 'delivered')
            .toList(growable: false);
        if (historyItems.isEmpty) {
          return Center(
            child: Text(
              'history_empty'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: historyItems.length,
          itemBuilder: (context, index) {
            final item = historyItems[index];
            return ListTile(
              title: Text(item.title),
              subtitle: Text('${item.trackingNo} • ${item.dateLabel}'),
              trailing: Text(item.weightLabel),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(homeParcelsProvider),
          child: Text('history_retry_loading'.tr()),
        ),
      ),
    );
  }
}

