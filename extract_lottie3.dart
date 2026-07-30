import 'dart:io';

void main() async {
  final transcriptPath = r'C:\Users\SAI GAGAN\.gemini\antigravity\brain\31eade12-4f3b-455d-be4c-7655deebe98a\.system_generated\logs\transcript_full.jsonl';
  final file = File(transcriptPath);
  final lines = await file.readAsLines();

  String lastLine = '';
  for (final line in lines.reversed) {
    if (line.contains('"type":"USER_INPUT"')) {
      lastLine = line;
      break;
    }
  }

  // The content field is encoded JSON string.
  // We can unescape the JSON string by parsing the outer JSON.
  String content = '';
  try {
    // Basic unescaping
    int contentStart = lastLine.indexOf('"content":"');
    if (contentStart != -1) {
      String sub = lastLine.substring(contentStart + 11);
      int contentEnd = sub.lastIndexOf('","tool_calls"');
      if (contentEnd != -1) {
        content = sub.substring(0, contentEnd).replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
      }
    }
  } catch (e) {
    print(e);
  }

  int idx1 = content.indexOf('{"v":"5.5.7"');
  int idx2 = content.indexOf('{"v":"5.6.2"');

  print('idx1: $idx1, idx2: $idx2');

  if (idx1 != -1) {
    int end1 = idx2 != -1 ? idx2 : content.length;
    String lottie1 = content.substring(idx1, end1).trim();
    await File('assets/lottie/animation_1.json').writeAsString(lottie1);
    print('Saved animation_1.json');
  }

  if (idx2 != -1) {
    String lottie2 = content.substring(idx2).trim();
    if (lottie2.endsWith(']')) lottie2 = lottie2.substring(0, lottie2.length - 1);
    if (lottie2.endsWith('}')) lottie2 = lottie2.substring(0, lottie2.lastIndexOf('}') + 1);
    await File('assets/lottie/animation_2.json').writeAsString(lottie2);
    print('Saved animation_2.json');
  }
}
