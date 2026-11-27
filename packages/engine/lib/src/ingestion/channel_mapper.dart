// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import '../storage/channel_record.dart';
import 'catalog.dart';

/// Turns a declarative catalogue entry into a runtime channel.
///
/// The catalogue is immutable data under `data/`, while the selected channel
/// is local state in SQLite, as required by ADR-0004. NNTP is preferred when
/// the source publishes a newsgroup; public-inbox is the fallback.
final class ChannelMapper {
  /// Maps [source] to a channel with a usable protocol and endpoint.
  static ChannelRecord fromSource(ListSource source) {
    final hasNntp = source.nntpHost.isNotEmpty && source.newsgroup.isNotEmpty;
    final hasInbox = source.inboxBaseUrl.isNotEmpty;
    if (!hasNntp && !hasInbox) {
      throw CatalogException('source ${source.id} has no usable protocol');
    }
    return ChannelRecord(
      id: source.id,
      listId: source.listId,
      label: source.label,
      protocol: hasNntp ? 'nntp' : 'public_inbox',
      endpoint: hasNntp
          ? '${source.nntpHost}:${source.nntpPort}/${source.newsgroup}'
          : source.inboxBaseUrl,
    );
  }
}
