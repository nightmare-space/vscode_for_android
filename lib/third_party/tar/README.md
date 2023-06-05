# tar

![Build status](https://github.com/simolus3/tar/workflows/build/badge.svg)

This package provides stream-based readers and writers for tar files.

When working with large tar files, this library consumes considerably less memory
than [package:archive](https://pub.dev/packages/archive), although it is slightly slower due to the async overhead.

## Reading

To read entries from a tar file, use a `TarReader` with a `Stream` emitting bytes (as `List<int>`):

```dart
import 'dart:convert';
import 'dart:io';
import 'package:tar/tar.dart';

Future<void> main() async {
  final reader = TarReader(File('file.tar').openRead());

  while (await reader.moveNext()) {
    final entry = reader.current;
    // Use reader.header to see the header of the current tar entry
    print(entry.header.name);
    // And reader.contents to read the content of the current entry as a stream
    print(await entry.contents.transform(utf8.decoder).first);
  }
  // Note that the reader will automatically close if moveNext() returns false or
  // throws. If you want to close a tar stream before that happens, use
  // reader.cancel();
}
```

To read `.tar.gz` files, transform the stream with `gzip.decoder` before
passing it to the `TarReader`.

To easily go through all entries in a tar file, use `TarReader.forEach`:

```dart
Future<void> main() async {
  final inputStream = File('file.tar').openRead();

  await TarReader.forEach(inputStream, (entry) {
    print(header.name);
    print(await entry.contents.transform(utf8.decoder).first);
  });
}
```

__Warning__: Since the reader is backed by a single stream, concurrent calls to
`read` are not allowed! Similarly, if you're reading from an entry's `contents`,
make sure to fully drain the stream before calling `read()` again.
_Not_ subscribing to `contents` before calling `moveNext()` is acceptable too.
In this case, the reader will implicitly drain the stream.
The reader detects concurrency misuses and will throw an error when they occur,
there's no risk of reading faulty data.

## Writing

When writing archives, `package:tar` expects a `Stream` of tar entries to include in
the archive.
This stream can then be converted into a stream of byte-array chunks forming the
encoded tar archive.

To write a tar stream into a `StreamSink<List<int>>`, such as an `IOSink` returned by
`File.openWrite`, use `tarWritingSink`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:tar/tar.dart';

Future<void> main() async {
  final output = File('test.tar').openWrite();
  final tarEntries = Stream<TarEntry>.value(
    TarEntry.data(
      TarHeader(
        name: 'hello.txt',
        mode: int.parse('644', radix: 8),
      ),
      utf8.encode('Hello world'),
    ),
  );

  await tarEntries.pipe(tarWritingSink(output));
}
```

For more complex stream transformations, `tarWriter` can be used as a stream
transformer converting a stream of tar entries into archive bytes.

Together with the `gzip.encoder` transformer from `dart:io`, this can be used
to write a `.tar.gz` file:

```dart
import 'dart:io';
import 'package:tar/tar.dart';

Future<void> write(Stream<TarEntry> entries) {
  return entries
      .transform(tarWriter) // convert entries into a .tar stream
      .transform(gzip.encoder) // convert the .tar stream into a .tar.gz stream
      .pipe(File('output.tar.gz').openWrite());
}
```

A more complex example for writing files can be found in [`example/archive_self.dart`](example/archive_self.dart).

### Encoding options

By default, tar files are  written in the pax format defined by the
POSIX.1-2001 specification (`--format=posix` in GNU tar).
When all entries have file names shorter than 100 chars and a size smaller
than 8 GB, this is equivalent to the `ustar` format. This library won't write
PAX headers when there is no reason to do so.
If you prefer writing GNU-style long filenames instead, you can use the
`format` option:

```dart
Future<void> write(Stream<TarEntry> entries) {
  return entries
      .pipe(
        tarWritingSink(
          File('output.tar').openWrite(),
          format: OutputFormat.gnuLongName,
      ));
}
```

To change the output format on the `tarWriter` transformer, use
`tarWriterWith`.

### Synchronous writing

As the content of tar entries is defined as an asynchronous stream, the tar encoder is asynchronous too.
The more specific `SynchronousTarEntry` class stores tar content as a list of bytes, meaning that it can be
written synchronously.

To synchronously write tar files, use `tarConverter` (or `tarConverterWith` for options):

```dart
List<int> createTarArchive(Iterable<SynchronousTarEntry> entries) {
  late List<int> result;
  final sink = ByteConversionSink.withCallback((data) => result = data);

  final output = tarConverter.startChunkedConversion(sink);
  entries.forEach(output.add);
  output.close();

  return result;
}
```

## Features

- Supports v7, ustar, pax, gnu and star archives
- Supports extended pax headers for long file or link names
- Supports long file and link names generated by GNU-tar
- Hardened against denial-of-service attacks with invalid tar files
- Supports being compiled to JavaScript, tested on Node.js

## Security considerations

Internally, this package contains checks to guard against some invalid tar files.
In particular,

- The reader doesn't allocate memory based on values in a tar file (so there's
  a guard against DoS attacks with tar files containing huge headers).
- When encountering malformed tar files, the reader will throw a `TarException`.
  Any other exception thrown indicates a bug in `package:tar` or how it's used.
  The reader should never crash.
- Reading a tar file can be cancelled mid-stream without leaking resources.

However, the tar reader __does not__ throw exceptions for wellformed archives
with suspicious contents, such as

- File names beginning with `../`, `/` or names pointing out of the archive by
  other means.
- Link references to files outside of the archive.
- Paths not using forward slashes.
- Gzip + tar bombs.
- Invalid permission bits in entries.
- ...

When reading or extracting untrusted tar files, it is your responsibility to
detect and handle these cases.
For instance, this naive extraction function is susceptible to invalid tar
files containing paths outside of the target directory:

```dart
Future<void> extractTarGz(File tarGz, Directory target) async {
  final input = tarGz.openRead().transform(gzip.decoder);

  await TarReader.forEach(input, (entry) async {
    final destination =
        // DON'T DO THIS! If `entry.name` contained `../`, this may escape the
        // target directory.
        path.joinAll([target.path, ...path.posix.split(entry.name)]);

    final f = File(destination);
    await f.create(recursive: true);
    await entry.contents.pipe(f.openWrite());
  });
}
```

For an idea on how to guard against this, see the [extraction logic](https://github.com/dart-lang/pub/blob/3082796f8ba9b3f509265ac3a223312fb5033988/lib/src/io.dart#L904-L991)
used by the pub client.

-----

Big thanks to [Garett Tok Ern Liang](https://github.com/walnutdust) for writing the initial
Dart tar reader that this library is based on.
