// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  _processDirectory(libDir);
}

void _processDirectory(Directory dir) {
  for (var entity in dir.listSync()) {
    if (entity is Directory) {
      _processDirectory(entity);
    } else if (entity is File && entity.path.endsWith('.dart')) {
      var content = entity.readAsStringSync();
      var newContent = content;
      newContent = newContent.replaceAll(RegExp(r'\b__+\b'), '_');
      if (newContent != content) {
        entity.writeAsStringSync(newContent);
        print('Fixed underscores in ${entity.path}');
      }
    }
  }
}
