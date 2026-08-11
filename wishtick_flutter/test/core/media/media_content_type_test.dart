import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wishtick_flutter/core/media/media_repository.dart';

/// Regression: `file_picker` gives no mime type on Android for anything it did
/// not open through the gallery, so the filename guess is what the server is
/// told. A `.m4a` fell through to `image/jpeg`, uploaded happily, got a `.jpg`
/// storage key — and then would not play. Found on a phone.
void main() {
  /// The guesser only runs when the picker supplied no type, which is what an
  /// `XFile.fromData` with no `mimeType` reproduces.
  ///
  /// The name goes through `fileName:`, not the constructor: `XFile.fromData`
  /// documents its own `name` as ignored on io. That is exactly the bug this
  /// file guards.
  String guessFor(String name) =>
      MediaRepository.contentTypeFor(XFile.fromData(_bytes), fileName: name);

  group('the upload content type', () {
    test('names every audio extension the wish flow offers', () {
      expect(guessFor('note.m4a'), 'audio/mp4');
      expect(guessFor('note.mp3'), 'audio/mpeg');
      expect(guessFor('note.aac'), 'audio/aac');
      expect(guessFor('note.wav'), 'audio/wav');
    });

    test('names every video extension the wish flow offers', () {
      expect(guessFor('clip.mp4'), 'video/mp4');
      expect(guessFor('clip.mov'), 'video/quicktime');
    });

    test('still names the image and document types', () {
      expect(guessFor('a.png'), 'image/png');
      expect(guessFor('a.webp'), 'image/webp');
      expect(guessFor('a.heic'), 'image/heic');
      expect(guessFor('a.gif'), 'image/gif');
      expect(guessFor('a.jpg'), 'image/jpeg');
      expect(guessFor('invite.pdf'), 'application/pdf');
    });

    test('is case-insensitive, as a file off a camera roll often is not', () {
      expect(guessFor('NOTE.M4A'), 'audio/mp4');
      expect(guessFor('CLIP.MP4'), 'video/mp4');
    });

    test("the picker's own mime type wins over the filename", () {
      final file = XFile.fromData(_bytes, mimeType: 'audio/mpeg');
      expect(
        MediaRepository.contentTypeFor(file, fileName: 'weird.png'),
        'audio/mpeg',
      );
    });
  });
}

final _bytes = Uint8List.fromList(const [1, 2, 3]);
