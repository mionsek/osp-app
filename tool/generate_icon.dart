// Simple script to generate a placeholder PNG icon for the OSP app.
// Uses raw PNG encoding (no dependencies needed).
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

// Minimal PNG generation for a solid-color icon with a simple cross pattern
void main() {
  const size = 512;
  final pixels = Uint8List(size * size * 4); // RGBA

  // Background: dark red (#B71C1C)
  for (var i = 0; i < size * size; i++) {
    pixels[i * 4 + 0] = 0xB7; // R
    pixels[i * 4 + 1] = 0x1C; // G
    pixels[i * 4 + 2] = 0x1C; // B
    pixels[i * 4 + 3] = 0xFF; // A
  }

  // Draw a white firefighter cross (Maltese-style simplified)
  void fillRect(int x, int y, int w, int h, int r, int g, int b) {
    for (var dy = 0; dy < h; dy++) {
      for (var dx = 0; dx < w; dx++) {
        final px = x + dx;
        final py = y + dy;
        if (px >= 0 && px < size && py >= 0 && py < size) {
          final idx = (py * size + px) * 4;
          pixels[idx + 0] = r;
          pixels[idx + 1] = g;
          pixels[idx + 2] = b;
          pixels[idx + 3] = 0xFF;
        }
      }
    }
  }

  // Draw a simple fire/flame shape using rectangles
  // Vertical bar of cross
  fillRect(216, 80, 80, 352, 0xFF, 0xFF, 0xFF);
  // Horizontal bar of cross
  fillRect(80, 216, 352, 80, 0xFF, 0xFF, 0xFF);

  // Inner red cross to create Maltese cross effect
  fillRect(232, 96, 48, 48, 0xB7, 0x1C, 0x1C);
  fillRect(232, 368, 48, 48, 0xB7, 0x1C, 0x1C);
  fillRect(96, 232, 48, 48, 0xB7, 0x1C, 0x1C);
  fillRect(368, 232, 48, 48, 0xB7, 0x1C, 0x1C);

  // Diagonal elements for Maltese cross (simplified)
  // Top-left arm
  fillRect(176, 120, 40, 96, 0xFF, 0xFF, 0xFF);
  fillRect(120, 176, 96, 40, 0xFF, 0xFF, 0xFF);
  // Top-right arm
  fillRect(296, 120, 40, 96, 0xFF, 0xFF, 0xFF);
  fillRect(296, 176, 96, 40, 0xFF, 0xFF, 0xFF);
  // Bottom-left arm
  fillRect(176, 296, 40, 96, 0xFF, 0xFF, 0xFF);
  fillRect(120, 296, 96, 40, 0xFF, 0xFF, 0xFF);
  // Bottom-right arm
  fillRect(296, 296, 40, 96, 0xFF, 0xFF, 0xFF);
  fillRect(296, 296, 96, 40, 0xFF, 0xFF, 0xFF);

  // Center circle
  final cx = 256, cy = 256, radius = 48;
  for (var y = cy - radius; y <= cy + radius; y++) {
    for (var x = cx - radius; x <= cx + radius; x++) {
      if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius) {
        if (x >= 0 && x < size && y >= 0 && y < size) {
          final idx = (y * size + x) * 4;
          pixels[idx + 0] = 0xFF;
          pixels[idx + 1] = 0xD5;
          pixels[idx + 2] = 0x00;
          pixels[idx + 3] = 0xFF;
        }
      }
    }
  }

  // Inner flame shape (simplified triangle)
  for (var y = 230; y < 282; y++) {
    final progress = (y - 230) / 52.0;
    final halfWidth = (progress * 20).toInt();
    for (var x = 256 - halfWidth; x <= 256 + halfWidth; x++) {
      if (x >= 0 && x < size && y >= 0 && y < size) {
        final idx = (y * size + x) * 4;
        pixels[idx + 0] = 0xE6; // orange
        pixels[idx + 1] = 0x51;
        pixels[idx + 2] = 0x00;
        pixels[idx + 3] = 0xFF;
      }
    }
  }

  // Write as BMP (simpler than PNG, then convert)
  // Actually, let's write a proper PNG
  final png = encodePng(size, size, pixels);

  File('assets/icon/osp_icon.png').writeAsBytesSync(png);
  File('assets/icon/osp_icon_foreground.png').writeAsBytesSync(png);
  print('Icon generated: assets/icon/osp_icon.png');
}

// Minimal PNG encoder
Uint8List encodePng(int width, int height, Uint8List rgba) {
  final raw = BytesBuilder();

  // Filter rows (filter type 0 = None)
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter byte
    raw.add(rgba.sublist(y * width * 4, (y + 1) * width * 4));
  }

  final rawData = raw.toBytes();
  final compressed = zlib.encode(rawData);

  final png = BytesBuilder();

  // PNG Signature
  png.add([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR chunk
  final ihdr = BytesBuilder();
  ihdr.add(_uint32be(width));
  ihdr.add(_uint32be(height));
  ihdr.addByte(8); // bit depth
  ihdr.addByte(6); // color type (RGBA)
  ihdr.addByte(0); // compression
  ihdr.addByte(0); // filter
  ihdr.addByte(0); // interlace
  _writeChunk(png, 'IHDR', ihdr.toBytes());

  // IDAT chunk
  _writeChunk(png, 'IDAT', Uint8List.fromList(compressed));

  // IEND chunk
  _writeChunk(png, 'IEND', Uint8List(0));

  return png.toBytes();
}

void _writeChunk(BytesBuilder png, String type, Uint8List data) {
  png.add(_uint32be(data.length));
  final typeBytes = ascii.encode(type);
  png.add(typeBytes);
  png.add(data);

  // CRC32 of type + data
  final crcInput = BytesBuilder();
  crcInput.add(typeBytes);
  crcInput.add(data);
  png.add(_uint32be(_crc32(crcInput.toBytes())));
}

Uint8List _uint32be(int value) {
  return Uint8List(4)
    ..[0] = (value >> 24) & 0xFF
    ..[1] = (value >> 16) & 0xFF
    ..[2] = (value >> 8) & 0xFF
    ..[3] = value & 0xFF;
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (var j = 0; j < 8; j++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}
