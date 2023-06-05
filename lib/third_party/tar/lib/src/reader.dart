import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:typed_data/typed_data.dart';

import 'charcodes.dart';
import 'constants.dart';
import 'entry.dart';
import 'exception.dart';
import 'format.dart';
import 'header.dart';
import 'sparse.dart';
import 'utils.dart';

/// [TarReader] provides sequential access to the TAR files in a TAR archive.
/// It is designed to read from a stream and to spit out substreams for
/// individual file contents in order to minimize the amount of memory needed
/// to read each archive where possible.
@sealed
class TarReader implements StreamIterator<TarEntry> {
  final BlockReader _reader;
  final PaxHeaders _paxHeaders = PaxHeaders();
  final int _maxSpecialFileSize;

  TarEntry? _current;
  _CurrentEntryStream? _currentStream;

  /// Whether we're in the process of reading tar headers.
  bool _isReadingHeaders = false;

  /// Whether this tar reader is terminally done.
  ///
  /// That is the case if:
  ///  - [cancel] was called
  ///  - [moveNext] completed to `false` once.
  ///  - [moveNext] completed to an error
  ///  - an error was emitted through a tar entry's content stream
  bool _isDone = false;

  /// Whether we should ensure that the stream emits no further data after the
  /// end of the tar file was reached.
  final bool _checkNoTrailingData;

  /// Creates a tar reader reading from the raw [tarStream].
  ///
  /// The [disallowTrailingData] parameter can be enabled to assert that the
  /// [tarStream] contains exactly one tar archive before ending.
  /// When [disallowTrailingData] is disabled (which is the default), the reader
  /// will automatically cancel its stream subscription when [moveNext] returns
  /// `false`.
  /// When it is enabled and a marker indicating the end of an archive is
  /// encountered, [moveNext] will wait for further events on the stream. If
  /// further data is received, a [TarException] will be thrown and the
  /// subscription will be cancelled. Otherwise, [moveNext] effectively waits
  /// for a done event, making a cancellation unecessary.
  /// Depending on the input stream, cancellations may cause unintended
  /// side-effects. In that case, [disallowTrailingData] can be used to ensure
  /// that the stream is only cancelled if it emits an invalid tar file.
  ///
  /// The [maxSpecialFileSize] parameter can be used to limit the maximum length
  /// of hidden entries in the tar stream. These entries include extended PAX
  /// headers or long names in GNU tar. The content of those entries has to be
  /// buffered in the parser to properly read the following tar entries. To
  /// avoid memory-based denial-of-service attacks, this library limits their
  /// maximum length. Changing the default of 2 KiB is rarely necessary.
  TarReader(Stream<List<int>> tarStream,
      {int maxSpecialFileSize = defaultSpecialLength,
      bool disallowTrailingData = false})
      : _reader = BlockReader(tarStream),
        _checkNoTrailingData = disallowTrailingData,
        _maxSpecialFileSize = maxSpecialFileSize;

  @override
  TarEntry get current {
    final current = _current;

    if (current == null) {
      throw StateError('Invalid call to TarReader.current. \n'
          'Did you call and await next() and checked that it returned true?');
    }

    return current;
  }

  /// Reads the tar stream up until the beginning of the next logical file.
  ///
  /// If such file exists, the returned future will complete with `true`. After
  /// the future completes, the next tar entry will be evailable in [current].
  ///
  /// If no such file exists, the future will complete with `false`.
  /// The future might complete with an [TarException] if the tar stream is
  /// malformed or ends unexpectedly.
  /// If the future completes with `false` or an exception, the reader will
  /// [cancel] itself and release associated resources. Thus, it is invalid to
  /// call [moveNext] again in that case.
  @override
  Future<bool> moveNext() async {
    await _prepareToReadHeaders();
    try {
      return await _moveNextInternal();
    } on Object {
      await cancel();
      rethrow;
    }
  }

  /// Consumes the stream up to the contents of the next logical tar entry.
  /// Will cancel the underlying subscription when returning false, but not when
  /// it throws.
  Future<bool> _moveNextInternal() async {
    // We're reading a new logical file, so clear the local pax headers
    _paxHeaders.clearLocals();

    var gnuLongName = '';
    var gnuLongLink = '';
    var eofAcceptable = true;

    var format = TarFormat.ustar |
        TarFormat.pax |
        TarFormat.gnu |
        TarFormat.v7 |
        TarFormat.star;

    HeaderImpl? nextHeader;

    // Externally, [moveNext] iterates through the tar archive as if it is a
    // series of files. Internally, the tar format often uses fake "files" to
    // add meta data that describes the next file. These meta data "files"
    // should not normally be visible to the outside. As such, this loop
    // iterates through one or more "header files" until it finds a
    // "normal file".
    while (true) {
      final rawHeader = await _readFullBlock(allowEmpty: eofAcceptable);

      nextHeader = await _readHeader(rawHeader);
      if (nextHeader == null) {
        if (eofAcceptable) {
          await _handleExpectedEof();
          return false;
        } else {
          _unexpectedEof();
        }
      }

      // We're beginning to read a file, if the tar file ends now something is
      // wrong
      eofAcceptable = false;
      format = format.mayOnlyBe(nextHeader.format);

      // Check for PAX/GNU special headers and files.
      if (nextHeader.typeFlag == TypeFlag.xHeader ||
          nextHeader.typeFlag == TypeFlag.xGlobalHeader) {
        format = format.mayOnlyBe(TarFormat.pax);
        final paxHeaderSize = _checkSpecialSize(nextHeader.size);

        final rawPaxHeaders =
            (await _readFullBlock(amount: numBlocks(paxHeaderSize)))
                .sublistView(0, paxHeaderSize);

        _paxHeaders.readPaxHeaders(
            rawPaxHeaders, nextHeader.typeFlag == TypeFlag.xGlobalHeader);

        // This is a meta header affecting the next header.
        continue;
      } else if (nextHeader.typeFlag == TypeFlag.gnuLongLink ||
          nextHeader.typeFlag == TypeFlag.gnuLongName) {
        format = format.mayOnlyBe(TarFormat.gnu);
        final size = _checkSpecialSize(nextHeader.size);
        final realName = await _readFullBlock(amount: numBlocks(size));

        final readName = realName.readString(0, realName.length);
        if (nextHeader.typeFlag == TypeFlag.gnuLongName) {
          gnuLongName = readName;
        } else {
          gnuLongLink = readName;
        }

        // This is a meta header affecting the next header.
        continue;
      } else {
        // The old GNU sparse format is handled here since it is technically
        // just a regular file with additional attributes.

        if (gnuLongName.isNotEmpty) nextHeader.name = gnuLongName;
        if (gnuLongLink.isNotEmpty) nextHeader.linkName = gnuLongLink;

        if (nextHeader.internalTypeFlag == TypeFlag.regA) {
          /// Legacy archives use trailing slash for directories
          if (nextHeader.name.endsWith('/')) {
            nextHeader.internalTypeFlag = TypeFlag.dir;
          } else {
            nextHeader.internalTypeFlag = TypeFlag.reg;
          }
        }

        final content = await _handleFile(nextHeader, rawHeader);

        // Set the final guess at the format
        if (format.has(TarFormat.ustar) && format.has(TarFormat.pax)) {
          format = format.mayOnlyBe(TarFormat.ustar);
        }
        nextHeader.format = format;

        _current = TarEntry(nextHeader, content);
        final currentStreams = _currentStream;
        assert(currentStreams == null ||
            currentStreams.state == _EntryStreamState.preListen);
        _isReadingHeaders = false;
        return true;
      }
    }
  }

  @override
  Future<void> cancel() async {
    if (_isDone) return;

    _isDone = true;
    _current = null;
    _currentStream = null;
    _isReadingHeaders = false;

    // Note: Calling cancel is safe when the stream has already been completed.
    // It's a noop in that case, which is what we want.
    return _reader.close();
  }

  /// Utility function for quickly iterating through all entries in [tarStream].
  static Future<void> forEach(Stream<List<int>> tarStream,
      FutureOr<void> Function(TarEntry entry) action) async {
    final reader = TarReader(tarStream);
    try {
      while (await reader.moveNext()) {
        await action(reader.current);
      }
    } finally {
      await reader.cancel();
    }
  }

  /// Ensures that this reader can safely read headers now.
  ///
  /// This methods prevents:
  ///  * concurrent calls to [moveNext]
  ///  * a call to [moveNext] while a stream is active:
  ///    * if [contents] has never been listened to, we drain the stream
  ///    * otherwise, throws a [StateError]
  Future<void> _prepareToReadHeaders() async {
    if (_isDone) {
      throw StateError('Tried to call TarReader.moveNext() on a canceled '
          'reader. \n'
          'Note that a reader is canceled when moveNext() throws or returns '
          'false.');
    }

    if (_isReadingHeaders) {
      throw StateError('Concurrent call to TarReader.moveNext() detected. \n'
          'Please await all calls to Reader.moveNext().');
    }
    _isReadingHeaders = true;

    final underlyingStream = _currentStream;
    if (underlyingStream != null) {
      switch (underlyingStream.state) {
        case _EntryStreamState.preListen:
          await underlyingStream.drain<void>();
          // The stream should reset when drained (we do this in _publishStream)
          assert(_currentStream == null);

          break;
        case _EntryStreamState.subscriptionActive:
          throw StateError(
            'Illegal call to TarReader.moveNext() while a previous stream was '
            'active.\n'
            'When listening to tar contents, make sure the stream is '
            'complete or cancelled before calling TarReader.moveNext() again.',
          );
        case _EntryStreamState.cancelled:
          // ignore: cancel_subscriptions
          final subscription = underlyingStream._sourceSubscription!;

          // Re-purpose the existing subscription to drain the stream
          assert(subscription.isPaused);

          subscription
            ..onData(null)
            ..resume();

          try {
            await subscription.asFuture<void>();
          } on Object {
            await cancel();
            rethrow;
          } finally {
            // This also draines the stream
            _currentStream = null;
          }

          break;
        case _EntryStreamState.done:
          assert(
            false,
            'Unreachable: There should not be a currentStream in a done state, '
            'as the stream is no longer current at that point.',
          );
          break;
      }
    }
  }

  int _checkSpecialSize(int size) {
    if (size > _maxSpecialFileSize) {
      throw TarException(
          'TAR file contains hidden entry with an invalid size of $size.');
    }

    return size;
  }

  /// Ater we detected the end of a tar file, optionally check for trailing
  /// data.
  Future<void> _handleExpectedEof() async {
    if (_checkNoTrailingData) {
      // Trailing zeroes are okay, but don't allow any more data here.
      Uint8List block;

      do {
        block = await _reader.nextBlock();
        if (!block.isAllZeroes) {
          throw TarException(
              'Illegal content after the end of the tar archive.');
        }
      } while (block.length == blockSize);
      // The stream is done when we couldn't read the full block.
    }

    await cancel();
  }

  Never _unexpectedEof() {
    throw TarException.header('Unexpected end of file');
  }

  /// Reads [amount] blocks from the input stream, or throws an exception if
  /// the stream ends prematurely.
  Future<Uint8List> _readFullBlock({bool allowEmpty = false, int amount = 1}) {
    final blocks = Uint8List(amount * blockSize);
    var offset = 0;

    return _reader.nextBlocks(amount).forEach((chunk) {
      blocks.setAll(offset, chunk);
      offset += chunk.length;
    }).then((void _) {
      if (allowEmpty && offset == 0) {
        return Uint8List(0);
      } else if (offset < blocks.length) {
        _unexpectedEof();
      } else {
        return blocks;
      }
    });
  }

  /// Reads the next block header and assumes that the underlying reader
  /// is already aligned to a block boundary. It returns the raw block of the
  /// header in case further processing is required.
  ///
  /// EOF is hit when one of the following occurs:
  ///	* Exactly 0 bytes are read and EOF is hit.
  ///	* Exactly 1 block of zeros is read and EOF is hit.
  ///	* At least 2 blocks of zeros are read.
  Future<HeaderImpl?> _readHeader(Uint8List rawHeader) async {
    // Exactly 0 bytes are read and EOF is hit.
    if (rawHeader.isEmpty) return null;

    if (rawHeader.isAllZeroes) {
      rawHeader = await _reader.nextBlock();

      // Exactly 1 block of zeroes is read and EOF is hit.
      if (rawHeader.isEmpty) return null;

      if (rawHeader.isAllZeroes) {
        // Two blocks of zeros are read - Normal EOF.
        return null;
      }

      throw TarException('Encountered a non-zero block after a zero block');
    }

    return HeaderImpl.parseBlock(rawHeader, paxHeaders: _paxHeaders);
  }

  /// Creates a stream of the next entry's content
  Future<Stream<List<int>>> _handleFile(
      HeaderImpl header, Uint8List rawHeader) async {
    List<SparseEntry>? sparseData;
    if (header.typeFlag == TypeFlag.gnuSparse) {
      sparseData = await _readOldGNUSparseMap(header, rawHeader);
    } else {
      sparseData = await _readGNUSparsePAXHeaders(header);
    }

    if (sparseData != null) {
      if (header.hasContent &&
          !validateSparseEntries(sparseData, header.size)) {
        throw TarException.header('Invalid sparse file header.');
      }

      final sparseHoles = invertSparseEntries(sparseData, header.size);
      final sparseDataLength =
          sparseData.fold<int>(0, (value, element) => value + element.length);

      final streamBlockCount = numBlocks(sparseDataLength);
      final safeStream = _publishStream(
          _reader.nextBlocks(streamBlockCount), streamBlockCount * blockSize);
      return sparseStream(safeStream, sparseHoles, header.size);
    } else {
      var size = header.size;
      if (!header.hasContent) size = 0;

      if (size < 0) {
        throw TarException.header('Invalid size ($size) detected!');
      }

      if (size == 0) {
        return _publishStream(const Stream<Never>.empty(), 0);
      } else {
        final blockCount = numBlocks(header.size);
        return _publishStream(_reader.nextBlocks(blockCount), header.size);
      }
    }
  }

  /// Publishes an library-internal stream for users.
  ///
  /// This adds a check to ensure that the stream we're exposing has the
  /// expected length. It also sets the [_currentStream] field and resets it
  /// when it's done.
  Stream<List<int>> _publishStream(Stream<Uint8List> stream, int length) {
    // There can only be one content stream at a time. This precondition is
    // checked by _prepareToReadHeaders.
    assert(_currentStream == null);

    return _currentStream = _CurrentEntryStream(this, stream, length);
  }

  /// Checks the PAX headers for GNU sparse headers.
  /// If they are found, then this function reads the sparse map and returns it.
  /// This assumes that 0.0 headers have already been converted to 0.1 headers
  /// by the PAX header parsing logic.
  Future<List<SparseEntry>?> _readGNUSparsePAXHeaders(HeaderImpl header) async {
    /// Identify the version of GNU headers.
    var isVersion1 = false;
    final major = _paxHeaders[paxGNUSparseMajor];
    final minor = _paxHeaders[paxGNUSparseMinor];

    final sparseMapHeader = _paxHeaders[paxGNUSparseMap];
    if (major == '0' && (minor == '0' || minor == '1') ||
        // assume 0.0 or 0.1 if no version header is set
        sparseMapHeader != null && sparseMapHeader.isNotEmpty) {
      isVersion1 = false;
    } else if (major == '1' && minor == '0') {
      isVersion1 = true;
    } else {
      // Unknown version that we don't support
      return null;
    }

    header.format |= TarFormat.pax;

    /// Update [header] from GNU sparse PAX headers.
    final possibleName = _paxHeaders[paxGNUSparseName] ?? '';
    if (possibleName.isNotEmpty) {
      header.name = possibleName;
    }

    final possibleSize =
        _paxHeaders[paxGNUSparseSize] ?? _paxHeaders[paxGNUSparseRealSize];

    if (possibleSize != null && possibleSize.isNotEmpty) {
      final size = int.tryParse(possibleSize, radix: 10);
      if (size == null) {
        throw TarException.header('Invalid PAX size ($possibleSize) detected');
      }

      header.size = size;
    }

    // Read the sparse map according to the appropriate format.
    if (isVersion1) {
      return await _readGNUSparseMap1x0();
    }

    return _readGNUSparseMap0x1(header);
  }

  /// Reads the sparse map as stored in GNU's PAX sparse format version 1.0.
  /// The format of the sparse map consists of a series of newline-terminated
  /// numeric fields. The first field is the number of entries and is always
  /// present. Following this are the entries, consisting of two fields
  /// (offset, length). This function must stop reading at the end boundary of
  /// the block containing the last newline.
  ///
  /// Note that the GNU manual says that numeric values should be encoded in
  /// octal format. However, the GNU tar utility itself outputs these values in
  /// decimal. As such, this library treats values as being encoded in decimal.
  Future<List<SparseEntry>> _readGNUSparseMap1x0() async {
    var newLineCount = 0;
    final block = Uint8Queue();

    /// Ensures that [block] h as at least [n] tokens.
    Future<void> feedTokens(int n) async {
      while (newLineCount < n) {
        final newBlock = await _readFullBlock();
        if (newBlock.length < blockSize) {
          throw TarException.header(
              'GNU Sparse Map does not have enough lines!');
        }

        block.addAll(newBlock);
        newLineCount += newBlock.where((byte) => byte == $lf).length;
      }
    }

    /// Get the next token delimited by a newline. This assumes that
    /// at least one newline exists in the buffer.
    String nextToken() {
      newLineCount--;
      final nextNewLineIndex = block.indexOf($lf);
      final result = block.sublist(0, nextNewLineIndex);
      block.removeRange(0, nextNewLineIndex + 1);
      return result.readString(0, nextNewLineIndex);
    }

    await feedTokens(1);

    // Parse for the number of entries.
    // Use integer overflow resistant math to check this.
    final numEntriesString = nextToken();
    final numEntries = int.tryParse(numEntriesString);
    if (numEntries == null || numEntries < 0 || 2 * numEntries < numEntries) {
      throw TarException.header(
          'Invalid sparse map number of entries: $numEntriesString!');
    }

    // Parse for all member entries.
    // [numEntries] is trusted after this since a potential attacker must have
    // committed resources proportional to what this library used.
    await feedTokens(2 * numEntries);

    final sparseData = <SparseEntry>[];

    for (var i = 0; i < numEntries; i++) {
      final offsetToken = nextToken();
      final lengthToken = nextToken();

      final offset = int.tryParse(offsetToken);
      final length = int.tryParse(lengthToken);

      if (offset == null || length == null) {
        throw TarException.header(
            'Failed to read a GNU sparse map entry. Encountered '
            'offset: $offsetToken, length: $lengthToken');
      }

      sparseData.add(SparseEntry(offset, length));
    }
    return sparseData;
  }

  /// Reads the sparse map as stored in GNU's PAX sparse format version 0.1.
  /// The sparse map is stored in the PAX headers and is stored like this:
  /// `offset₀,size₀,offset₁,size₁...`
  List<SparseEntry> _readGNUSparseMap0x1(TarHeader header) {
    // Get number of entries, check for integer overflows
    final numEntriesString = _paxHeaders[paxGNUSparseNumBlocks];
    final numEntries =
        numEntriesString != null ? int.tryParse(numEntriesString) : null;

    if (numEntries == null || numEntries < 0 || 2 * numEntries < numEntries) {
      throw TarException.header('Invalid GNU version 0.1 map');
    }

    // There should be two numbers in [sparseMap] for each entry.
    final sparseMap = _paxHeaders[paxGNUSparseMap]?.split(',');
    if (sparseMap == null) {
      throw TarException.header('Invalid GNU version 0.1 map');
    }

    if (sparseMap.length != 2 * numEntries) {
      throw TarException.header(
          'Detected sparse map length ${sparseMap.length} '
          'that is not twice the number of entries $numEntries');
    }

    /// Loop through sparse map entries.
    /// [numEntries] is now trusted.
    final sparseData = <SparseEntry>[];
    for (var i = 0; i < sparseMap.length; i += 2) {
      final offset = int.tryParse(sparseMap[i]);
      final length = int.tryParse(sparseMap[i + 1]);

      if (offset == null || length == null) {
        throw TarException.header(
            'Failed to read a GNU sparse map entry. Encountered '
            'offset: $offset, length: $length');
      }

      sparseData.add(SparseEntry(offset, length));
    }

    return sparseData;
  }

  /// Reads the sparse map from the old GNU sparse format.
  /// The sparse map is stored in the tar header if it's small enough.
  /// If it's larger than four entries, then one or more extension headers are
  /// used to store the rest of the sparse map.
  ///
  /// [TarHeader.size] does not reflect the size of any extended headers used.
  /// Thus, this function will read from the chunked stream iterator to fetch
  /// extra headers.
  ///
  /// See also: https://www.gnu.org/software/tar/manual/html_section/tar_94.html#SEC191
  Future<List<SparseEntry>> _readOldGNUSparseMap(
      HeaderImpl header, Uint8List rawHeader) async {
    // Make sure that the input format is GNU.
    // Unfortunately, the STAR format also has a sparse header format that uses
    // the same type flag but has a completely different layout.
    if (header.format != TarFormat.gnu) {
      throw TarException.header('Tried to read sparse map of non-GNU header');
    }

    // Read the real size of the file when sparse holes are expanded.
    header.size = rawHeader.readNumeric(483, 12);
    final sparseEntries = <SparseEntry>[];

    bool readEntry(Uint8List source, int offset) {
      // If a sparse header starts with a null byte, it marks the end of the
      // sparse structures.
      if (rawHeader[offset] == 0) return false;

      final fileOffset = source.readNumeric(offset, 12);
      final length = source.readNumeric(offset + 12, 12);

      sparseEntries.add(SparseEntry(fileOffset, length));
      return true;
    }

    // The first four sparse headers are stored in the tar header itself
    for (var i = 0; i < 4; i++) {
      final offset = 386 + 24 * i;
      if (!readEntry(rawHeader, offset)) break;
    }

    var isExtended = rawHeader[482] != 0;

    while (isExtended) {
      // Ok, we have a new block of sparse headers to process
      final block = await _readFullBlock();

      // A full block of sparse data contains up to 21 entries
      for (var i = 0; i < 21; i++) {
        if (!readEntry(block, i * 24)) break;
      }

      // The last bytes indicates whether another sparse header block follows.
      isExtended = block[504] != 0;
    }

    return sparseEntries;
  }
}

@internal
class PaxHeaders extends UnmodifiableMapBase<String, String> {
  final Map<String, String> _globalHeaders = {};
  Map<String, String> _localHeaders = {};

  /// Applies new global PAX-headers from the map.
  ///
  /// The [headers] will replace global headers with the same key, but leave
  /// others intact.
  void newGlobals(Map<String, String> headers) {
    _globalHeaders.addAll(headers);
  }

  /// Applies new local PAX-headers from the map.
  ///
  /// This replaces all currently active local headers.
  void newLocals(Map<String, String> headers) {
    _localHeaders = headers;
  }

  /// Clears local headers.
  ///
  /// This is used by the reader after a file has ended, as local headers only
  /// apply to the next entry.
  void clearLocals() {
    _localHeaders = {};
  }

  @override
  String? operator [](Object? key) {
    return _localHeaders[key] ?? _globalHeaders[key];
  }

  @override
  Iterable<String> get keys => {..._globalHeaders.keys, ..._localHeaders.keys};

  /// Decodes the content of an extended pax header entry.
  ///
  /// Semantically, a [PAX Header][posix pax] is a map with string keys and
  /// values, where both keys and values are encodes with utf8.
  ///
  /// However, [old GNU Versions][gnu sparse00] used to repeat keys to store
  /// sparse file information in sparse headers. This method will transparently
  /// rewrite the PAX format of version 0.0 to version 0.1.
  ///
  /// [posix pax]: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html#tag_20_92_13_03
  /// [gnu sparse00]: https://www.gnu.org/software/tar/manual/html_section/tar_94.html#SEC192
  void readPaxHeaders(List<int> data, bool isGlobal,
      {bool ignoreUnknown = true}) {
    var offset = 0;
    final map = <String, String>{};
    final sparseMap = <String>[];

    Never error() => throw TarException.header('Invalid PAX record');

    while (offset < data.length) {
      // At the start of an entry, expect its length which is terminated by a
      // space char.
      final space = data.indexOf($space, offset);
      if (space == -1) break;

      var length = 0;
      var currentChar = data[offset];
      var charsInLength = 0;
      while (currentChar >= $0 && currentChar <= $9) {
        length = length * 10 + currentChar - $0;
        charsInLength++;
        currentChar = data[++offset];
      }

      if (length == 0) {
        error();
      }

      // Skip the whitespace
      if (currentChar != $space) {
        error();
      }
      offset++;

      // Length also includes the length description and a space we just read
      final endOfEntry = offset + length - 1 - charsInLength;
      // checking against endOfEntry - 1 because the trailing whitespace is
      // optional for the last entry
      if (endOfEntry < offset || endOfEntry - 1 > data.length) {
        error();
      }

      // Read the key
      final nextEquals = data.indexOf($equal, offset);
      if (nextEquals == -1 || nextEquals >= endOfEntry) {
        error();
      }

      final key = utf8.decoder.convert(data, offset, nextEquals);
      // Skip over the equals sign
      offset = nextEquals + 1;

      // Subtract one for trailing newline for value
      final endOfValue = endOfEntry - 1;

      if (!_isValidPaxKey(key)) {
        error();
      }

      // If we're seeing weird PAX Version 0.0 sparse keys, expect alternating
      // GNU.sparse.offset and GNU.sparse.numbytes headers.
      if (key == paxGNUSparseNumBytes || key == paxGNUSparseOffset) {
        final value = utf8.decoder.convert(data, offset, endOfValue);

        if (!_isValidPaxRecord(key, value) ||
            (sparseMap.length.isEven && key != paxGNUSparseOffset) ||
            (sparseMap.length.isOdd && key != paxGNUSparseNumBytes) ||
            value.contains(',')) {
          error();
        }

        sparseMap.add(value);
      } else if (!ignoreUnknown || supportedPaxHeaders.contains(key)) {
        // Ignore unrecognized headers to avoid unbounded growth of the global
        // header map.
        final value = unsafeUtf8Decoder.convert(data, offset, endOfValue);

        if (!_isValidPaxRecord(key, value)) {
          error();
        }

        map[key] = value;
      }

      // Skip over value
      offset = endOfValue;
      // and the trailing newline
      final hasNewline = offset < data.length;
      if (hasNewline && data[offset] != $lf) {
        throw TarException('Invalid PAX Record (missing trailing newline)');
      }
      offset++;
    }

    if (sparseMap.isNotEmpty) {
      map[paxGNUSparseMap] = sparseMap.join(',');
    }

    if (isGlobal) {
      newGlobals(map);
    } else {
      newLocals(map);
    }
  }

  // NB: Some Tar files have malformed UTF-8 data in the headers, we should
  // decode them anyways even if they're broken
  static const unsafeUtf8Decoder = Utf8Decoder(allowMalformed: true);

  static bool _isValidPaxKey(String key) {
    // These limitations are documented in the PAX standard.
    return key.isNotEmpty && !key.contains('=') & !key.codeUnits.contains(0);
  }

  /// Checks whether [key], [value] is a valid entry in a pax header.
  ///
  /// This is adopted from the Golang tar reader (`validPAXRecord`), which says
  /// that "Keys and values should be UTF-8, but the number of bad writers out
  /// there forces us to be a more liberal."
  static bool _isValidPaxRecord(String key, String value) {
    // These aren't documented in any standard, but Golangs's tar has them and
    // got away with it.
    switch (key) {
      case paxPath:
      case paxLinkpath:
      case paxUname:
      case paxGname:
        return !value.codeUnits.contains(0);
      default:
        return true;
    }
  }
}

enum _EntryStreamState {
  preListen,
  subscriptionActive,
  cancelled,
  done,
}

/// The underlying content stream for the [TarReader._current] entry. Draining
/// this stream will move the tar reader to the beginning of the next file.
///
/// This is not the same as `_current.stream` for sparse files, which are
/// reported as expanded through [TarEntry.contents].
/// For that reason, we prefer to drain this stream when skipping a tar entry.
/// When we know we're skipping data, there's no point expanding sparse holes.
///
/// Draining this stream will set the [TarReader._currentStream] field back to
/// null. There can only be one content stream at the time.
class _CurrentEntryStream extends Stream<List<int>> {
  _EntryStreamState state = _EntryStreamState.preListen;

  final TarReader _reader;
  final Stream<Uint8List> _source;

  final StreamController<List<int>> _listener = StreamController(sync: true);
  // ignore: cancel_subscriptions
  StreamSubscription<List<int>>? _sourceSubscription;

  int _remainingContentSize;
  int _remainingPaddingSize;
  bool _hadError = false;
  bool _isInContent = true;

  _CurrentEntryStream(this._reader, this._source, this._remainingContentSize)
      : _remainingPaddingSize = _paddingFor(_remainingContentSize);

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    // Make sure that this entry is still the current one: If users store the
    // contents of a tar entry, then read more tar entries, and finally try to
    // read the stream of the old contents, they'd get an exception about the
    // stream already being listened to.
    // This can be a bit confusing, so this check enables a better error UX.
    if (_reader._currentStream != this) {
      throw StateError(
        'Tried listening to an outdated tar entry. \n'
        'As all tar entries found by a reader are backed by a single source '
        'stream, only the latest tar entry can be read. It looks like you '
        'stored the results of `tarEntry.contents` somewhere, called '
        '`reader.moveNext()` and then read the contents of the previous '
        'entry.\n'
        'For more details, including a discussion of workarounds, see '
        'https://github.com/simolus3/tar/issues/18',
      );
    } else if (state != _EntryStreamState.preListen) {
      throw StateError(
        'A tar entry has been listened to multiple times. \n'
        'As all tar entries are read from what\'s likely a single-'
        'subscription stream, this is unsupported. If you didn\'t read a tar '
        'entry multiple times yourself, perhaps you\'ve called `moveNext()` '
        'before reading contents?',
      );
    }

    // Now we have a listener, so
    state = _EntryStreamState.subscriptionActive;
    // ignore: cancel_subscriptions
    final sub = _sourceSubscription = _source.listen(
      _forwardData,
      onError: _forwardError,
      onDone: _forwardDone,
    );

    _listener
      ..onPause = sub.pause
      ..onResume = sub.resume
      ..onCancel = () {
        // Pause the source subscription. When reading the next entry, the tar
        // reader will drain the remaining source stream.
        sub.pause();
        state = _EntryStreamState.cancelled;
      };

    return _listener.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  static int _paddingFor(int contentSize) {
    final offsetInLastBlock = contentSize.toUnsigned(blockSizeLog2);
    if (offsetInLastBlock != 0) {
      return blockSize - offsetInLastBlock;
    }
    return 0;
  }

  void _assertInStateForForwarding() {
    assert(state == _EntryStreamState.subscriptionActive &&
        _listener.hasListener &&
        !_listener.isPaused);
  }

  void _forwardData(Uint8List event) {
    _assertInStateForForwarding();

    if (_isInContent) {
      if (event.length <= _remainingContentSize) {
        // We can fully add this chunk as it consists entirely of data
        _listener.add(event);
        _remainingContentSize -= event.length;
      } else {
        // We can add the first bytes as content, the others are padding that we
        // shouldn't emit
        _listener.add(event.sublistView(0, _remainingContentSize));
        _isInContent = false;
        _remainingPaddingSize -= event.length - _remainingContentSize;
        _remainingContentSize = 0;
      }
    } else {
      // Ok, the entire event is padding
      _remainingPaddingSize -= event.length;
    }

    // The underlying stream comes from pkg:tar, so if we get too many bytes
    // that's a bug in this package.
    assert(_remainingPaddingSize >= 0, 'Stream emitted to many bytes');
  }

  void _forwardError(Object error, StackTrace trace) {
    _assertInStateForForwarding();

    _hadError = true;
    _listener.addError(error, trace);
  }

  void _forwardDone() {
    _assertInStateForForwarding();

    // Now that the source stream is done, reset the stream state on the reader.
    state = _EntryStreamState.done;
    _sourceSubscription = null;
    _reader._currentStream = null;

    // If the stream stopped after an error, the user is already aware that
    // something is wrong.
    if (_remainingContentSize > 0 && !_hadError) {
      _listener.addError(
          TarException('Unexpected end of tar file'), StackTrace.current);
    }
    _listener.close();
  }
}
