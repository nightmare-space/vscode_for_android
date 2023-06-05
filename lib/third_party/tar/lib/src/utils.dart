@internal
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'charcodes.dart';
import 'constants.dart';
import 'exception.dart';

const _checksumEnd = checksumOffset + checksumLength;
const _checksumPlaceholder = $space;

extension ByteBufferUtils on Uint8List {
  String readString(int offset, int maxLength) {
    return readStringOrNullIfEmpty(offset, maxLength) ?? '';
  }

  Uint8List sublistView(int start, [int? end]) {
    return Uint8List.sublistView(this, start, end);
  }

  String? readStringOrNullIfEmpty(int offset, int maxLength) {
    var data = sublistView(offset, offset + maxLength);
    var contentLength = data.indexOf(0);
    // If there's no \0, assume that the string fills the whole segment
    if (contentLength.isNegative) contentLength = maxLength;

    if (contentLength == 0) return null;

    data = data.sublistView(0, contentLength);
    try {
      return utf8.decode(data);
    } on FormatException {
      return String.fromCharCodes(data).trim();
    }
  }

  /// Parse an octal string encoded from index [offset] with the maximum length
  /// [length].
  int readOctal(int offset, int length) {
    var result = 0;
    var multiplier = 1;

    for (var i = length - 1; i >= 0; i--) {
      final charCode = this[offset + i];
      // Some tar implementations add a \0 or space at the end, ignore that
      if (charCode == 0 || charCode == $space) continue;
      if (charCode < $0 || charCode > $9) {
        throw TarException('Invalid octal value');
      }

      // Obtain the numerical value of this digit
      final digit = charCode - $0;
      result += digit * multiplier;
      multiplier <<= 3; // Multiply by the base, 8
    }

    return result;
  }

  /// Parses an encoded int, either as base-256 or octal.
  ///
  /// This function may return negative numbers.
  int readNumeric(int offset, int length) {
    if (length == 0) return 0;

    // Check for base-256 (binary) format first. If the first bit is set, then
    // all following bits constitute a two's complement encoded number in big-
    // endian byte order.
    final firstByte = this[offset];
    if (firstByte & 0x80 != 0) {
      // Handling negative numbers relies on the following identity:
      // -a-1 == ~a
      //
      // If the number is negative, we use an inversion mask to invert the
      // date bytes and treat the value as an unsigned number.
      final inverseMask = firstByte & 0x40 != 0 ? 0xff : 0x00;

      // Ignore signal bit in the first byte
      var x = (firstByte ^ inverseMask) & 0x7f;

      for (var i = 1; i < length; i++) {
        var byte = this[offset + i];
        byte ^= inverseMask;

        x = x << 8 | byte;
      }

      return inverseMask == 0xff ? ~x : x;
    }

    return readOctal(offset, length);
  }

  int computeUnsignedHeaderChecksum() {
    // Accessing the last element first helps the VM eliminate bounds checks in
    // the loops below.
    this[blockSize - 1]; // ignore: unnecessary_statements
    var result = checksumLength * _checksumPlaceholder;

    for (var i = 0; i < checksumOffset; i++) {
      result += this[i];
    }
    for (var i = _checksumEnd; i < blockSize; i++) {
      result += this[i];
    }

    return result;
  }

  int computeSignedHeaderChecksum() {
    this[blockSize - 1]; // ignore: unnecessary_statements
    // Note that _checksumPlaceholder.toSigned(8) == _checksumPlaceholder
    var result = checksumLength * _checksumPlaceholder;

    for (var i = 0; i < checksumOffset; i++) {
      result += this[i].toSigned(8);
    }
    for (var i = _checksumEnd; i < blockSize; i++) {
      result += this[i].toSigned(8);
    }

    return result;
  }

  bool matchesHeader(List<int> header, {int offset = magicOffset}) {
    for (var i = 0; i < header.length; i++) {
      if (this[offset + i] != header[i]) return false;
    }

    return true;
  }

  bool get isAllZeroes {
    for (var i = 0; i < length; i++) {
      if (this[i] != 0) return false;
    }

    return true;
  }
}

bool isNotAscii(int i) => i > 128;

/// Like [int.parse], but throwing a [TarException] instead of the more-general
/// [FormatException] when it fails.
int parseInt(String source) {
  return int.tryParse(source, radix: 10) ??
      (throw TarException('Not an int: $source'));
}

/// Takes a [paxTimeString] of the form %d.%d as described in the PAX
/// specification. Note that this implementation allows for negative timestamps,
/// which is allowed for by the PAX specification, but not always portable.
///
/// Note that Dart's [DateTime] class only allows us to give up to microsecond
/// precision, which implies that we cannot parse all the digits in since PAX
/// allows for nanosecond level encoding.
DateTime parsePaxTime(String paxTimeString) {
  const maxMicroSecondDigits = 6;

  /// Split [paxTimeString] into seconds and sub-seconds parts.
  var secondsString = paxTimeString;
  var microSecondsString = '';
  final position = paxTimeString.indexOf('.');
  if (position >= 0) {
    secondsString = paxTimeString.substring(0, position);
    microSecondsString = paxTimeString.substring(position + 1);
  }

  /// Parse the seconds.
  final seconds = int.tryParse(secondsString);
  if (seconds == null) {
    throw TarException.header('Invalid PAX time $paxTimeString detected!');
  }

  if (microSecondsString.replaceAll(RegExp('[0-9]'), '') != '') {
    throw TarException.header(
        'Invalid nanoseconds $microSecondsString detected');
  }

  microSecondsString = microSecondsString.padRight(maxMicroSecondDigits, '0');
  microSecondsString = microSecondsString.substring(0, maxMicroSecondDigits);

  var microSeconds =
      microSecondsString.isEmpty ? 0 : int.parse(microSecondsString);
  if (paxTimeString.startsWith('-')) microSeconds = -microSeconds;

  return microsecondsSinceEpoch(microSeconds + seconds * pow(10, 6).toInt());
}

DateTime secondsSinceEpoch(int timestamp) {
  return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
}

DateTime millisecondsSinceEpoch(int milliseconds) {
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

DateTime microsecondsSinceEpoch(int microseconds) {
  return DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);
}

int numBlocks(int fileSize) {
  if (fileSize % blockSize == 0) return fileSize ~/ blockSize;

  return fileSize ~/ blockSize + 1;
}

int nextBlockSize(int fileSize) => numBlocks(fileSize) * blockSize;

extension ToTyped on List<int> {
  Uint8List asUint8List() {
    // Flow analysis doesn't work on this.
    final $this = this;
    return $this is Uint8List ? $this : Uint8List.fromList(this);
  }
}

/// Generates a chunked stream of [length] zeroes.
Stream<List<int>> zeroes(int length) async* {
  // Emit data in chunks for efficiency
  const chunkSize = 4 * 1024;
  if (length < chunkSize) {
    yield Uint8List(length);
    return;
  }

  final chunk = Uint8List(chunkSize);
  for (var i = 0; i < length ~/ chunkSize; i++) {
    yield chunk;
  }

  final remainingBytes = length % chunkSize;
  if (remainingBytes != 0) {
    yield Uint8List(remainingBytes);
  }
}

/// An optimized reader reading 512-byte blocks from an input stream.
class BlockReader {
  final Stream<List<int>> _input;
  StreamSubscription<List<int>>? _subscription;
  bool _isClosed = false;

  /// If a request is active, returns the current stream that we're reporting.
  /// This controler is synchronous.
  StreamController<Uint8List>? _outgoing;

  /// The amount of (512-byte) blocks remaining before [_outgoing] should close.
  int _remainingBlocksInOutgoing = 0;

  /// A pending tar block that has not been emitted yet.
  ///
  /// This can happen if we receive small chunks of data in [_onData] that
  /// aren't enough to form a full block.
  final Uint8List _pendingBlock = Uint8List(blockSize);

  /// The offset in [_pendingBlock] at which new data should start.
  ///
  /// For instance, if this value is `502`, we're missing `10` additional bytes
  /// to complete the [_pendingBlock].
  /// When this value is `0`, there is no active pending block.
  int _offsetInPendingBlock = 0;

  /// Additional data that we received, but were unable to dispatch to a
  /// downstream listener yet.
  ///
  /// This can happen if a we receive a large chunk of data and a listener is
  /// only interested in a small chunk.
  ///
  /// We will never have trailing data and a pending block at the same time.
  /// When we haver fewer than 512 bytes of trailing data, it should be stored
  /// as a pending block instead.
  Uint8List? _trailingData;

  /// The offset in the [_trailingData] byte array.
  ///
  /// When a new listener attaches, we can start by emitting the sublist
  /// starting at this offset.
  int _offsetInTrailingData = 0;

  BlockReader(this._input);

  /// Emits full blocks.
  ///
  /// Returns `true` if the listener detached in response to emitting these
  /// blocks. In this case, remaining data must be saved in [_trailingData].
  bool _emitBlocks(Uint8List data, {int amount = 1}) {
    assert(_remainingBlocksInOutgoing >= amount);
    final outgoing = _outgoing!;

    if (!outgoing.isClosed) outgoing.add(data);

    final remainingNow = _remainingBlocksInOutgoing -= amount;
    if (remainingNow == 0) {
      _outgoing = null;
      _pause();

      scheduleMicrotask(() {
        outgoing.close();
      });
      return true;
    } else if (outgoing.isPaused || outgoing.isClosed) {
      _pause();
      return true;
    }

    return false;
  }

  void _onData(List<int> data) {
    assert(_outgoing != null && _trailingData == null);

    final typedData = data.asUint8List();
    var offsetInData = 0;

    /// Saves parts of the current chunks that couldn't be emitted.
    void saveTrailingState() {
      assert(_trailingData == null && _offsetInPendingBlock == 0);

      final remaining = typedData.length - offsetInData;

      if (remaining == 0) {
        return; // Nothing to save, the chunk has been consumed fully.
      } else if (remaining < blockSize) {
        // Store remaining data as a pending block.
        _pendingBlock.setAll(0, typedData.sublistView(offsetInData));
        _offsetInPendingBlock = remaining;
      } else {
        _trailingData = typedData;
        _offsetInTrailingData = offsetInData;
      }
    }

    // Try to complete a pending block first
    var offsetInPending = _offsetInPendingBlock;
    final canWriteIntoPending = min(blockSize - offsetInPending, data.length);

    if (offsetInPending != 0 && canWriteIntoPending > 0) {
      _pendingBlock.setAll(
          offsetInPending, typedData.sublistView(0, canWriteIntoPending));
      offsetInPending = _offsetInPendingBlock += canWriteIntoPending;
      offsetInData += canWriteIntoPending;

      // Did this finish the pending block?
      if (offsetInPending == blockSize) {
        _offsetInPendingBlock = 0;
        if (_emitBlocks(_pendingBlock)) {
          // Emitting the pending block completed all pending requests.
          saveTrailingState();
          return;
        }
      } else {
        // The chunk we received didn't fill up the pending block, so just stop
        // here.
        assert(offsetInData == data.length);
        return;
      }
    }

    // At this point, the pending block should have been served.
    assert(_offsetInPendingBlock == 0);

    final fullBlocksToEmit = min(_remainingBlocksInOutgoing,
        (typedData.length - offsetInData) ~/ blockSize);

    if (fullBlocksToEmit > 0) {
      _emitBlocks(
        typedData.sublistView(
            offsetInData, offsetInData += fullBlocksToEmit * blockSize),
        amount: fullBlocksToEmit,
      );
    }

    saveTrailingState();
  }

  void _onError(Object error, StackTrace trace) {
    assert(_outgoing != null && _trailingData == null);

    _outgoing!.addError(error, trace);
  }

  void _onDone() {
    assert(_outgoing != null && _trailingData == null);
    final outgoing = _outgoing!;

    // Add pending data, then close
    if (_offsetInPendingBlock != 0) {
      outgoing.add(_pendingBlock.sublistView(0, _offsetInPendingBlock));
    }

    _isClosed = true;
    _subscription?.cancel();
    outgoing.close();
  }

  void _subscribeOrResume() {
    // We should not resume the subscription if there is trailing data ready to
    // be emitted.
    assert(_trailingData == null);

    final sub = _subscription;
    if (sub == null) {
      _subscription = _input.listen(_onData,
          onError: _onError, onDone: _onDone, cancelOnError: true);
    } else {
      sub.resume();
    }
  }

  void _pause() {
    final sub = _subscription!; // ignore: cancel_subscriptions

    if (!sub.isPaused) sub.pause();
  }

  Future<Uint8List> nextBlock() {
    final result = Uint8List(blockSize);
    var offset = 0;

    return nextBlocks(1).forEach((chunk) {
      result.setAll(offset, chunk);
      offset += chunk.length;
    }).then((void _) => result.sublistView(0, offset));
  }

  Stream<Uint8List> nextBlocks(int amount) {
    if (_isClosed || amount == 0) {
      return const Stream.empty();
    }
    if (_outgoing != null) {
      throw StateError(
          'Cannot call nextBlocks() before the previous stream completed.');
    }
    assert(_remainingBlocksInOutgoing == 0);

    // We're making this synchronous because we will mostly add events in
    // response to receiving chunks from the source stream. We manually ensure
    // that other emits are happening asynchronously.
    final controller = StreamController<Uint8List>(sync: true);
    _outgoing = controller;
    _remainingBlocksInOutgoing = amount;

    var state = _StreamState.initial;

    /// Sends trailing data to the stream. Returns true if the subscription
    /// should still be resumed afterwards.
    bool emitTrailing() {
      // Attempt to serve requests from pending data first.
      final trailing = _trailingData;
      if (trailing != null) {
        // There should never be trailing data and a pending block at the
        // same time
        assert(_offsetInPendingBlock == 0);

        var remaining = trailing.length - _offsetInTrailingData;
        // If there is trailing data, it should contain a full block
        // (otherwise we would have stored it as a pending block)
        assert(remaining >= blockSize);

        final blocks = min(_remainingBlocksInOutgoing, remaining ~/ blockSize);
        assert(blocks > 0);

        final done = _emitBlocks(
            trailing.sublistView(_offsetInTrailingData,
                _offsetInTrailingData + blocks * blockSize),
            amount: blocks);

        remaining -= blocks * blockSize;
        _offsetInTrailingData += blocks * blockSize;

        if (remaining == 0) {
          _trailingData = null;
          _offsetInTrailingData = 0;
        } else if (remaining < blockSize) {
          assert(_offsetInPendingBlock == 0);

          // Move trailing data into a pending block
          _pendingBlock.setAll(0, trailing.sublistView(_offsetInTrailingData));
          _offsetInPendingBlock = remaining;
          _trailingData = null;
          _offsetInTrailingData = 0;
        } else {
          // If there is still more than a full block of data waiting, we
          // should not listen. This implies that the stream is done already.
          assert(done);
        }

        // The listener detached in response to receiving the event.
        if (done) {
          if (_remainingBlocksInOutgoing == 0) state = _StreamState.done;
          return false;
        }
      }

      return true;
    }

    void scheduleInitialEmit() {
      scheduleMicrotask(() {
        if (state != _StreamState.initial) return;
        state = _StreamState.attached;

        if (emitTrailing()) {
          _subscribeOrResume();
        }
      });
    }

    controller
      ..onListen = scheduleInitialEmit
      ..onPause = () {
        assert(
            state == _StreamState.initial ||
                state == _StreamState.attached ||
                state == _StreamState.done,
            'Unexpected pause event in $state ($_remainingBlocksInOutgoing blocks remaining).');

        if (state == _StreamState.initial) {
          state = _StreamState.pausedAfterInitial;
        } else if (state == _StreamState.attached) {
          _pause();
          state = _StreamState.pausedAfterAttached;
        } else if (state == _StreamState.done) {
          // It may happen that onPause is called in a state where we believe
          // the stream to be done already. After the stream is done, we close
          // the controller in a new microtask. So if the subscription is paused
          // after the last event it emitted but before we close the controller,
          // we can get a pause event here.
          // There's nothing to do in that case.
          assert(_subscription?.isPaused != false);
        }
      }
      ..onResume = () {
        // We're done already
        if (_remainingBlocksInOutgoing == 0) return;

        assert(state == _StreamState.pausedAfterAttached ||
            state == _StreamState.pausedAfterInitial);

        if (state == _StreamState.pausedAfterInitial) {
          state = _StreamState.initial;
          scheduleInitialEmit();
        } else {
          state = _StreamState.attached;
          if (emitTrailing()) {
            _subscribeOrResume();
          }
        }
      }
      ..onCancel = () {
        state = _StreamState.done;
      };

    return controller.stream;
  }

  FutureOr<void> close() {
    _isClosed = true;
    return _subscription?.cancel();
  }
}

enum _StreamState {
  initial,
  attached,
  pausedAfterInitial,
  pausedAfterAttached,
  done,
}
