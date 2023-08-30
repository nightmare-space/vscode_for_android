// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Helper functionality to make working with IO easier.
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:vscode_for_android/third_party/tar/lib/tar.dart';

const _defaultMode = 420; // 644₈
const _executableMask = 0x49; // 001 001 001
String ensureDir(String dir) {
  Directory(dir).createSync(recursive: true);
  return dir;
}

void _chmod(int mode, String file) {
  Process.runSync('chmod', [mode.toRadixString(8), file]);
}

String _resolveLink(String link) {
  var seen = <String>{};
  while (linkExists(link) && seen.add(link)) {
    link = path.normalize(path.join(path.dirname(link), Link(link).targetSync()));
  }
  return link;
}

String canonicalize(String pathString) {
  var seen = <String>{};
  var components = Queue<String>.from(path.split(path.normalize(path.absolute(pathString))));

  // The canonical path, built incrementally as we iterate through [components].
  var newPath = components.removeFirst();

  // Move through the components of the path, resolving each one's symlinks as
  // necessary. A resolved component may also add new components that need to be
  // resolved in turn.
  while (components.isNotEmpty) {
    seen.add(path.join(newPath, path.joinAll(components)));
    var resolvedPath = _resolveLink(path.join(newPath, components.removeFirst()));
    var relative = path.relative(resolvedPath, from: newPath);

    // If the resolved path of the component relative to `newPath` is just ".",
    // that means component was a symlink pointing to its parent directory. We
    // can safely ignore such components.
    if (relative == '.') continue;

    var relativeComponents = Queue<String>.from(path.split(relative));

    // If the resolved path is absolute relative to `newPath`, that means it's
    // on a different drive. We need to canonicalize the entire target of that
    // symlink again.
    if (path.isAbsolute(relative)) {
      // If we've already tried to canonicalize the new path, we've encountered
      // a symlink loop. Avoid going infinite by treating the recursive symlink
      // as the canonical path.
      if (seen.contains(relative)) {
        newPath = relative;
      } else {
        newPath = relativeComponents.removeFirst();
        relativeComponents.addAll(components);
        components = relativeComponents;
      }
      continue;
    }

    // Pop directories off `newPath` if the component links upwards in the
    // directory hierarchy.
    while (relativeComponents.first == '..') {
      newPath = path.dirname(newPath);
      relativeComponents.removeFirst();
    }

    // If there's only one component left, [resolveLink] guarantees that it's
    // not a link (or is a broken link). We can just add it to `newPath` and
    // continue resolving the remaining components.
    if (relativeComponents.length == 1) {
      newPath = path.join(newPath, relativeComponents.single);
      continue;
    }

    // If we've already tried to canonicalize the new path, we've encountered a
    // symlink loop. Avoid going infinite by treating the recursive symlink as
    // the canonical path.
    var newSubPath = path.join(newPath, path.joinAll(relativeComponents));
    if (seen.contains(newSubPath)) {
      newPath = newSubPath;
      continue;
    }

    // If there are multiple new components to resolve, add them to the
    // beginning of the queue.
    relativeComponents.addAll(components);
    components = relativeComponents;
  }
  return newPath;
}

void createSymlink(String target, String symlink, {bool relative = false}) {
  if (relative) {
    // Relative junction points are not supported on Windows. Instead, just
    // make sure we have a clean absolute path because it will interpret a
    // relative path to be relative to the cwd, not the symlink, and will be
    // confused by forward slashes.
    if (Platform.isWindows) {
      target = path.normalize(path.absolute(target));
    } else {
      // If the directory where we're creating the symlink was itself reached
      // by traversing a symlink, we want the relative path to be relative to
      // it's actual location, not the one we went through to get to it.
      var symlinkDir = canonicalize(path.dirname(symlink));
      target = path.normalize(path.relative(target, from: symlinkDir));
    }
  }

  // print('Creating $symlink pointing to $target');
  Link(symlink).createSync(target);
}

bool linkExists(String link) => Link(link).existsSync();
void deleteIfLink(String file) {
  if (!linkExists(file)) return;
  print('Deleting symlink at $file.');
  Link(file).deleteSync();
}

Future<String> createFileFromStream(
  Stream<List<int>> stream,
  String file,
  void Function(String data) print,
) async {
  print('- ${path.basename(file)}.');
  deleteIfLink(file);
  await stream.pipe(File(file).openWrite());
  return file;
}

Stream<List<int>> readBinaryFileAsStream(String file) {
  print('Reading binary file $file.');
  var contents = File(file).openRead();
  return contents;
}

/// Extracts a `.tar.gz` file from [stream] to [destination].
Future extractTarGz(
  Stream<List<int>> stream,
  String destination,
  void Function(String data) print,
) async {
  // print('Extracting .tar.gz stream to $destination.');

  destination = path.absolute(destination);
  final reader = TarReader(stream.transform(gzip.decoder));
  final paths = <String>{};
  while (await reader.moveNext()) {
    final entry = reader.current;

    final filePath = path.joinAll([
      destination,
      // Tar file names always use forward slashes
      ...path.posix.split(entry.name),
    ]);
    if (!paths.add(filePath)) {
      // The tar file contained the same entry twice. Assume it is broken.
      await reader.cancel();
      throw FormatException('Tar file contained duplicate path ${entry.name}');
    }

    if (!path.isWithin(destination, filePath)) {
      // The tar contains entries that would be written outside of the
      // destination. That doesn't happen by accident, assume that the tar file
      // is malicious.
      await reader.cancel();
      throw FormatException('Invalid tar entry: ${entry.name}');
    }

    final parentDirectory = path.dirname(filePath);

    bool checkValidTarget(String linkTarget) {
      final isValid = path.isWithin(destination, linkTarget);
      if (!isValid) {
        print('Skipping ${entry.name}: Invalid link target');
      }

      return isValid;
    }

    switch (entry.type) {
      case TypeFlag.dir:
        ensureDir(filePath);
        break;
      case TypeFlag.reg:
      case TypeFlag.regA:
        // Regular file
        deleteIfLink(filePath);
        ensureDir(parentDirectory);
        await createFileFromStream(entry.contents, filePath, print);

        if (Platform.isLinux || Platform.isMacOS) {
          // Apply executable bits from tar header, but don't change r/w bits
          // from the default
          final mode = _defaultMode | (entry.header.mode & _executableMask);

          if (mode != _defaultMode) {
            _chmod(mode, filePath);
          }
        }
        break;
      case TypeFlag.symlink:
        // Link to another file in this tar, relative from this entry.
        final resolvedTarget = path.joinAll(
          [parentDirectory, ...path.posix.split(entry.header.linkName!)],
        );
        if (!checkValidTarget(resolvedTarget)) {
          // Don't allow links to files outside of this tar.
          break;
        }

        ensureDir(parentDirectory);
        createSymlink(
          path.relative(resolvedTarget, from: parentDirectory),
          filePath,
        );
        break;
      case TypeFlag.link:
        // We generate hardlinks as symlinks too, but their linkName is relative
        // to the root of the tar file (unlike symlink entries, whose linkName
        // is relative to the entry itself).
        final fromDestination = path.join(destination, entry.header.linkName);
        if (!checkValidTarget(fromDestination)) {
          break; // Link points outside of the tar file.
        }

        final fromFile = path.relative(fromDestination, from: parentDirectory);
        ensureDir(parentDirectory);
        createSymlink(fromFile, filePath);
        break;
      default:
        // Only extract files
        continue;
    }
  }

  print('Extracted .tar.gz to $destination.');
}
