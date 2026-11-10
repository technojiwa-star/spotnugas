import 'dart:io';

import 'package:image/image.dart' as img;

/// Run from the project root: dart run tool/generate_app_icons.dart
Future<void> main() async {
  final logo = img.decodePng(
    File('assets/images/Logo apps in introduction.png').readAsBytesSync(),
  );
  if (logo == null) {
    throw StateError('Unable to decode the introduction logo.');
  }

  const size = 1024;
  // Preserve the original logo's proportions and leave room for launcher masks.
  final resized = img.copyResize(
    logo,
    height: 800,
    interpolation: img.Interpolation.average,
  );
  final foreground = img.Image(width: size, height: size, numChannels: 4);
  img.compositeImage(
    foreground,
    resized,
    dstX: (size - resized.width) ~/ 2,
    dstY: (size - resized.height) ~/ 2,
  );

  // Matches AppColors.lightCream and flutter_launcher_icons.yaml.
  final icon = img.Image(width: size, height: size, numChannels: 3);
  img.fill(icon, color: img.ColorRgb8(0xEC, 0xEB, 0xD8));
  img.compositeImage(icon, foreground);

  final output = Directory('assets/icons')..createSync(recursive: true);
  File('${output.path}/app_icon.png').writeAsBytesSync(img.encodePng(icon));
  File('${output.path}/app_icon_foreground.png').writeAsBytesSync(
    img.encodePng(foreground),
  );

  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    'flutter_launcher_icons',
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}
