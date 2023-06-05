import 'dart:async';

import 'package:meta/meta.dart';

import 'header.dart';

/// An entry in a tar file.
///
/// Usually, tar entries are read from a stream, and they're bound to the stream
/// from which they've been read. This means that they can only be read once,
/// and that only one [TarEntry] is active at a time.
@sealed
class TarEntry {
  /// The parsed [TarHeader] of this tar entry.
  final TarHeader header;

  /// The content stream of the active tar entry.
  ///
  /// For tar entries read through the reader provided by this library,
  /// [contents] is a single-subscription streamed backed by the original stream
  /// used to create the reader.
  /// When listening on [contents], the stream needs to be fully drained before
  /// the next call to [StreamIterator.moveNext]. It's acceptable to not listen
  /// to [contents] at all before calling [StreamIterator.moveNext] again.
  /// In that case, this library will take care of draining the stream to get to
  /// the next entry.
  final Stream<List<int>> contents;

  /// The name of this entry, as indicated in the header or a previous pax
  /// entry.
  String get name => header.name;

  /// The type of tar entry (file, directory, etc.).
  TypeFlag get type => header.typeFlag;

  /// The content size of this entry, in bytes.
  int get size => header.size;

  /// Time of the last modification of this file, as indicated in the [header].
  DateTime get modified => header.modified;

  /// Creates a tar entry from a [header] and the [contents] stream.
  ///
  /// If the total length of [contents] is known, consider setting the
  /// [header]'s [TarHeader.size] property to the appropriate value.
  /// Otherwise, the tar writer needs to buffer contents to determine the right
  /// size.
  // factory so that this class can't be extended
  factory TarEntry(TarHeader header, Stream<List<int>> contents) = TarEntry._;

  TarEntry._(this.header, this.contents);

  /// Creates an in-memory tar entry from the [header] and the [data] to store.
  static SynchronousTarEntry data(TarHeader header, List<int> data) {
    (header as HeaderImpl).size = data.length;
    return SynchronousTarEntry._(header, data);
  }
}

/// A tar entry stored in memory.
class SynchronousTarEntry extends TarEntry {
  /// The contents of this tar entry as a byte array.
  final List<int> data;

  SynchronousTarEntry._(TarHeader header, this.data)
      : super._(header, Stream.value(data));
}
