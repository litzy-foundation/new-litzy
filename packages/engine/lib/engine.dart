// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The embedded engine and the client that starts it on a separate isolate.
///
/// R14 requires the engine to live inside the client process, and ADR-0003
/// requires every exchange with it to use typed LMLP messages.
library;

export 'src/engine_client.dart';
export 'src/engine_isolate.dart';
export 'src/ingestion/catalog.dart';
export 'src/ingestion/mailbox_action.dart';
export 'src/ingestion/mailbox_port.dart';
export 'src/ingestion/nntp_client.dart';
export 'src/ingestion/purge_coordinator.dart';
export 'src/storage/local_blob_store.dart';
export 'src/storage/local_database.dart';
export 'src/storage/message_record.dart';
