// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Linux keychain adapter backed by libsecret.
///
/// R35 requires secrets to live in the operating system keychain and R37
/// forbids a plaintext file. The adapter passes the secret directly from the
/// caller to libsecret and never places it in an argument, environment value
/// or log line.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'secret_store.dart';

/// Stores secrets in the Linux keyring through libsecret.
final class LibsecretStore implements SecretStore {
  /// Opens libsecret and the GLib allocator.
  LibsecretStore() : _bindings = _SecretBindings.open();

  static const String _label = 'Litzy account credential';
  static const String _attribute = 'litzy.key';

  final _SecretBindings _bindings;

  @override
  Future<void> put(String key, String secret) async {
    final secretUtf8 = secret.toNativeUtf8();
    final labelUtf8 = _label.toNativeUtf8();
    final attributes = _attributeTable(key);
    final error = calloc<Pointer<Void>>();
    try {
      final stored = _bindings.storeValue(
        nullptr,
        attributes.table,
        nullptr,
        labelUtf8,
        secretUtf8,
        nullptr,
        error,
      );
      if (stored == 0) throw SecretStoreException(_message(error));
    } finally {
      _releaseError(error);
      _releaseAttributes(attributes);
      calloc.free(error);
      calloc.free(secretUtf8);
      calloc.free(labelUtf8);
    }
  }

  @override
  Future<String?> get(String key) async {
    final attributes = _attributeTable(key);
    final error = calloc<Pointer<Void>>();
    try {
      final secret = _bindings.lookupValue(
        nullptr,
        attributes.table,
        nullptr,
        error,
      );
      if (secret == nullptr) {
        if (error.value != nullptr) throw SecretStoreException(_message(error));
        return null;
      }
      try {
        return secret.toDartString();
      } finally {
        _bindings.freeString(secret.cast<Void>());
      }
    } finally {
      _releaseError(error);
      _releaseAttributes(attributes);
      calloc.free(error);
    }
  }

  @override
  Future<void> remove(String key) async {
    final attributes = _attributeTable(key);
    final error = calloc<Pointer<Void>>();
    try {
      final cleared = _bindings.clearValue(
        nullptr,
        attributes.table,
        nullptr,
        error,
      );
      if (cleared == 0 && error.value != nullptr) {
        throw SecretStoreException(_message(error));
      }
    } finally {
      _releaseError(error);
      _releaseAttributes(attributes);
      calloc.free(error);
    }
  }

  ({Pointer<Void> table, Pointer<Utf8> name, Pointer<Utf8> value})
  _attributeTable(String key) {
    final name = _attribute.toNativeUtf8();
    final value = key.toNativeUtf8();
    final table = _bindings.newHashTable();
    _bindings.insert(table, name.cast<Void>(), value.cast<Void>());
    return (table: table, name: name, value: value);
  }

  void _releaseAttributes(
    ({Pointer<Void> table, Pointer<Utf8> name, Pointer<Utf8> value}) attributes,
  ) {
    _bindings.unrefHashTable(attributes.table);
    calloc.free(attributes.name);
    calloc.free(attributes.value);
  }

  String _message(Pointer<Pointer<Void>> error) {
    final pointer = error.value;
    if (pointer == nullptr) return 'libsecret rejected the operation';
    final message = pointer.cast<_GError>().ref.message;
    return message == nullptr
        ? 'libsecret rejected the operation'
        : message.toDartString();
  }

  void _releaseError(Pointer<Pointer<Void>> error) {
    if (error.value == nullptr) return;
    _bindings.freeError(error.value);
    error.value = nullptr;
  }
}

final class _GError extends Struct {
  @Uint32()
  external int domain;

  @Int32()
  external int code;

  external Pointer<Utf8> message;
}

final class _SecretBindings {
  _SecretBindings(DynamicLibrary secret, DynamicLibrary glib)
    : _strHash = glib.lookup<NativeFunction<_HashNative>>('g_str_hash'),
      _strEqual = glib.lookup<NativeFunction<_EqualNative>>('g_str_equal'),
      _newHashTable = glib.lookupFunction<_TableNewNative, _TableNewDart>(
        'g_hash_table_new',
      ),
      _insert = glib.lookupFunction<_InsertNative, _InsertDart>(
        'g_hash_table_insert',
      ),
      _unrefHashTable = glib.lookupFunction<_FreeNative, _FreeDart>(
        'g_hash_table_unref',
      ),
      _store = secret.lookupFunction<_StoreNative, _StoreDart>(
        'secret_password_storev_sync',
      ),
      _lookup = secret.lookupFunction<_LookupNative, _LookupDart>(
        'secret_password_lookupv_sync',
      ),
      _clear = secret.lookupFunction<_ClearNative, _ClearDart>(
        'secret_password_clearv_sync',
      ),
      _freeError = glib.lookupFunction<_FreeNative, _FreeDart>('g_error_free'),
      _freeString = glib.lookupFunction<_FreeNative, _FreeDart>('g_free');

  factory _SecretBindings.open() {
    if (!Platform.isLinux) {
      throw const SecretStoreException(
        'the native keychain adapter is available only on Linux',
      );
    }
    try {
      return _SecretBindings(
        DynamicLibrary.open('libsecret-1.so.0'),
        DynamicLibrary.open('libglib-2.0.so.0'),
      );
    } on Object {
      throw const SecretStoreException('libsecret is not available');
    }
  }

  final Pointer<NativeFunction<_HashNative>> _strHash;
  final Pointer<NativeFunction<_EqualNative>> _strEqual;
  final _TableNewDart _newHashTable;
  final _InsertDart _insert;
  final _FreeDart _unrefHashTable;
  final _StoreDart _store;
  final _LookupDart _lookup;
  final _ClearDart _clear;
  final _FreeDart _freeError;
  final _FreeDart _freeString;

  Pointer<Void> newHashTable() => _newHashTable(_strHash, _strEqual);

  void insert(Pointer<Void> table, Pointer<Void> name, Pointer<Void> value) =>
      _insert(table, name, value);

  void unrefHashTable(Pointer<Void> table) => _unrefHashTable(table);

  int storeValue(
    Pointer<Void> schema,
    Pointer<Void> attributes,
    Pointer<Utf8> collection,
    Pointer<Utf8> label,
    Pointer<Utf8> password,
    Pointer<Void> cancellable,
    Pointer<Pointer<Void>> error,
  ) => _store(
    schema,
    attributes,
    collection,
    label,
    password,
    cancellable,
    error,
  );

  Pointer<Utf8> lookupValue(
    Pointer<Void> schema,
    Pointer<Void> attributes,
    Pointer<Void> cancellable,
    Pointer<Pointer<Void>> error,
  ) => _lookup(schema, attributes, cancellable, error);

  int clearValue(
    Pointer<Void> schema,
    Pointer<Void> attributes,
    Pointer<Void> cancellable,
    Pointer<Pointer<Void>> error,
  ) => _clear(schema, attributes, cancellable, error);

  void freeError(Pointer<Void> pointer) => _freeError(pointer);

  void freeString(Pointer<Void> pointer) => _freeString(pointer);
}

typedef _HashNative = Uint32 Function(Pointer<Void>);
typedef _EqualNative = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef _TableNewNative = Pointer<Void> Function(
  Pointer<NativeFunction<_HashNative>>,
  Pointer<NativeFunction<_EqualNative>>,
);
typedef _TableNewDart = Pointer<Void> Function(
  Pointer<NativeFunction<_HashNative>>,
  Pointer<NativeFunction<_EqualNative>>,
);
typedef _InsertNative = Int32 Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _InsertDart = int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>);
typedef _StoreNative = Int32 Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Void>,
  Pointer<Pointer<Void>>,
);
typedef _StoreDart = int Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Void>,
  Pointer<Pointer<Void>>,
);
typedef _LookupNative = Pointer<Utf8> Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Pointer<Void>>,
);
typedef _LookupDart = Pointer<Utf8> Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Pointer<Void>>,
);
typedef _ClearNative = Int32 Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Pointer<Void>>,
);
typedef _ClearDart = int Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Pointer<Void>>,
);
typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);
