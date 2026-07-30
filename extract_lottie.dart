import 'dart:io';
import 'dart:convert';

void main() async {
  final transcriptPath = r'C:\Users\SAI GAGAN\.gemini\antigravity\brain\31eade12-4f3b-455d-be4c-7655deebe98a\.system_generated\logs\transcript.jsonl';
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

  // Find Lotties
  final lotties = <String>[];
  final regex = RegExp(r'\{"v":"5\.[^"]+",.*?"assets":\[.*?\]\}', dotAll: true);
  final matches = regex.allMatches(lastUserInput);
  
  for (final match in matches) {
    lotties.add(match.group(0)!);
  }

  print('Found ${lotties.length} lotties');

  for (var i = 0; i < lotties.length; i++) {
    var name = 'animation_${i + 1}';
    try {
      final parsed = jsonDecode(lotties[i]);
      if (parsed['nm'] != null) {
        name = parsed['nm'].toString().replaceAll(' ', '_').toLowerCase();
        name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '');
      }
    } catch (e) {
      // ignore
    }
    final outPath = 'assets/lottie/$name.json';
    await File(outPath).writeAsString(lotties[i]);
    print('Saved $outPath');
  }
}
