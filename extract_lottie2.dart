import 'dart:io';
import 'dart:convert';

void main() async {
  final transcriptPath = r'C:\Users\SAI GAGAN\.gemini\antigravity\brain\31eade12-4f3b-455d-be4c-7655deebe98a\.system_generated\logs\transcript_full.jsonl';
  final file = File(transcriptPath);
  final lines = await file.readAsLines();

  String lastUserInput = '';
  for (final line in lines.reversed) {
    try {
      final data = jsonDecode(line);
      if (data['type'] == 'USER_INPUT') {
        lastUserInput = data['content'] ?? '';
        break;
      }
    } catch (e) {
      // ignore
    }
  }

  // Find Lotties by simple string parsing since regex might fail on huge files
  int startIndex1 = lastUserInput.indexOf('{"v":"5.5.7"');
  int startIndex2 = lastUserInput.indexOf('{"v":"5.6.2"');
  
  if (startIndex1 != -1) {
    // Find the end of this JSON object. For simplicity we assume it goes until the next start or end of string.
    int endIndex1 = startIndex2 != -1 && startIndex2 > startIndex1 ? startIndex2 : lastUserInput.length;
    String lottie1 = lastUserInput.substring(startIndex1, endIndex1).trim();
    if (lottie1.endsWith(',')) lottie1 = lottie1.substring(0, lottie1.length - 1); // sometimes they are comma separated
    await File('assets/lottie/animation_1.json').writeAsString(lottie1);
    print('Saved animation_1.json');
  }

  if (startIndex2 != -1) {
    String lottie2 = lastUserInput.substring(startIndex2).trim();
    if (lottie2.endsWith(']')) lottie2 = lottie2.substring(0, lottie2.length - 1); // remove array bracket if any
    if (lottie2.endsWith('}')) lottie2 = lottie2.substring(0, lottie2.lastIndexOf('}') + 1);
    await File('assets/lottie/study_discussion.json').writeAsString(lottie2);
    print('Saved study_discussion.json');
  }
}
