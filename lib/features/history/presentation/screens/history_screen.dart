import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/data/home_parcel_repository.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelsAsync = ref.watch(homeParcelsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(homeParcelsProvider.future),
      child: parcelsAsync.when(
        data: (items) {
          final historyItems = items
              .where(
                (item) =>
                    item.status == 'completed' || item.status == 'delivered',
              )
              .toList(growable: false);
          if (historyItems.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
                Center(
                  child: Text(
                    'history_empty'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
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
            separatorBuilder: (context, index) => const Divider(height: 1),
          );
        },
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 240),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 240),
            Center(
              child: TextButton(
                onPressed: () => ref.invalidate(homeParcelsProvider),
                child: Text('history_retry_loading'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
