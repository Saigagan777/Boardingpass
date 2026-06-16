import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Service for picking, extracting text from, and parsing resume files.
///
/// Supports PDF (basic text layer extraction) and plain-text / DOCX-like files.
/// Uses rule-based pattern matching to extract career timeline, education,
/// skills, and professional interests from the raw text.
class ResumeParserService {
  static final ResumeParserService _instance = ResumeParserService._internal();
  factory ResumeParserService() => _instance;
  ResumeParserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // File Picking
  // ---------------------------------------------------------------------------

  /// Opens a file picker filtered for PDF and common document types.
  /// Returns the selected file's bytes and name, or null if cancelled.
  Future<PlatformFile?> pickResumeFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        withData: true, // Load bytes into memory (needed for web)
      );
      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
    } catch (e) {
      debugPrint('ResumeParserService.pickResumeFile error: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Text Extraction
  // ---------------------------------------------------------------------------

  /// Extracts readable text from file bytes.
  ///
  /// For PDFs, attempts to pull text from the binary stream using a lightweight
  /// heuristic (no heavy native PDF library required). Falls back to
  /// UTF-8 decoding for .txt / .docx (XML-based) files.
  String extractText(Uint8List bytes, String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return _extractTextFromPdf(bytes);
    }
    // For .txt and .docx (raw XML), decode as UTF-8 and strip XML tags
    final raw = String.fromCharCodes(bytes);
    return raw.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Lightweight PDF text extraction.
  ///
  /// Scans the raw PDF byte stream for text-rendering operators (Tj, TJ, ').
  /// This works for PDFs with an embedded text layer but will NOT work for
  /// scanned/image-only PDFs. For production, consider a server-side solution.
  String _extractTextFromPdf(Uint8List bytes) {
    final raw = String.fromCharCodes(bytes);
    final buffer = StringBuffer();

    // Match parenthesised strings used by Tj / ' operators
    final tjPattern = RegExp(r'\(([^)]*?)\)\s*Tj', multiLine: true);
    for (final match in tjPattern.allMatches(raw)) {
      buffer.write(match.group(1));
      buffer.write(' ');
    }

    // Match TJ arrays: [(text) 123 (more text)] TJ
    final tjArrayPattern = RegExp(r'\[([^\]]*?)\]\s*TJ', multiLine: true);
    for (final match in tjArrayPattern.allMatches(raw)) {
      final inner = match.group(1) ?? '';
      final parts = RegExp(r'\(([^)]*?)\)').allMatches(inner);
      for (final p in parts) {
        buffer.write(p.group(1));
      }
      buffer.write(' ');
    }

    // Decode common PDF escape sequences
    String text = buffer.toString();
    text = text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\t', ' ')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', '\\');

    // Clean up excessive whitespace
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

    return text;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Parses extracted resume text and returns structured profile data.
  Map<String, dynamic> parseResumeText(String text) {
    return {
      'skills': _extractSkills(text),
      'careerTimeline': _extractCareerTimeline(text),
      'educationTimeline': _extractEducationTimeline(text),
      'interests': _extractInterests(text),
      'professionalInterests': _extractProfessionalInterests(text),
    };
  }

  /// Common technical and business skills to match against.
  static const List<String> _knownSkills = [
    // Programming Languages
    'Java', 'Python', 'JavaScript', 'TypeScript', 'Dart', 'Kotlin', 'Swift',
    'C++', 'C#', 'Go', 'Rust', 'Ruby', 'PHP', 'Scala', 'R',
    // Frameworks & Libraries
    'Flutter', 'React', 'Angular', 'Vue', 'Node.js', 'Django', 'Flask',
    'Spring Boot', 'Express', 'Next.js', 'TensorFlow', 'PyTorch',
    // Cloud & DevOps
    'AWS', 'Azure', 'GCP', 'Docker', 'Kubernetes', 'CI/CD', 'Terraform',
    'Jenkins', 'GitHub Actions',
    // Databases
    'SQL', 'PostgreSQL', 'MySQL', 'MongoDB', 'Redis', 'Firebase', 'Firestore',
    'DynamoDB', 'Elasticsearch',
    // Data & AI
    'Machine Learning', 'Deep Learning', 'NLP', 'Computer Vision',
    'Data Science', 'Data Engineering', 'Big Data', 'Spark', 'Hadoop',
    // Design & Product
    'Figma', 'UI/UX', 'Product Management', 'Agile', 'Scrum',
    // Business
    'Strategy', 'Consulting', 'Marketing', 'Sales', 'Finance',
    'Business Development', 'Project Management', 'Leadership',
    'Public Speaking', 'Negotiation',
  ];

  List<String> _extractSkills(String text) {
    final found = <String>{};
    for (final skill in _knownSkills) {
      // Case-insensitive whole-word match
      final pattern = RegExp(
        r'(?:^|[\s,;|/])' + RegExp.escape(skill) + r'(?:[\s,;|/.]|$)',
        caseSensitive: false,
      );
      if (pattern.hasMatch(text)) {
        found.add(skill);
      }
    }
    return found.toList();
  }

  /// Extracts career timeline entries.
  ///
  /// Looks for patterns like:
  /// - "Software Engineer at Google, Jan 2020 - Present"
  /// - "Google | Software Engineer | 2020 - 2023"
  /// - Section headers like "EXPERIENCE" / "WORK HISTORY"
  List<Map<String, dynamic>> _extractCareerTimeline(String text) {
    final entries = <Map<String, dynamic>>[];

    // Pattern: "Role at Company, Duration" or "Role, Company (Duration)"
    final pattern = RegExp(
      r'([A-Z][a-zA-Z\s]+?)'
      r'\s+(?:at|@|,|\|)\s+'
      r'([A-Z][a-zA-Z\s&.,]+?)'
      r'[,|\s]+'
      r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{4}'
      r'\s*[-–]\s*'
      r'(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{4}|Present|Current))',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(text)) {
      entries.add({
        'role': match.group(1)?.trim() ?? '',
        'company': match.group(2)?.trim() ?? '',
        'duration': match.group(3)?.trim() ?? '',
        'description': '',
      });
    }

    // Fallback: look for year-range patterns near title-case words
    if (entries.isEmpty) {
      final yearPattern = RegExp(
        r'([A-Z][a-zA-Z\s]+?)\s*[-–|,]\s*([A-Z][a-zA-Z\s&.]+?)\s*[-–|,]\s*(\d{4}\s*[-–]\s*(?:\d{4}|Present|Current))',
        caseSensitive: false,
      );
      for (final match in yearPattern.allMatches(text)) {
        entries.add({
          'role': match.group(1)?.trim() ?? '',
          'company': match.group(2)?.trim() ?? '',
          'duration': match.group(3)?.trim() ?? '',
          'description': '',
        });
      }
    }

    return entries;
  }

  /// Extracts education entries.
  ///
  /// Looks for degree keywords (B.Tech, MBA, M.Sc, Bachelor, Master, PhD, etc.)
  /// followed by institution names and year ranges.
  List<Map<String, dynamic>> _extractEducationTimeline(String text) {
    final entries = <Map<String, dynamic>>[];

    final pattern = RegExp(
      r'((?:B\.?\s*Tech|B\.?\s*E|B\.?\s*Sc|B\.?\s*A|B\.?\s*Com|'
      r'M\.?\s*Tech|M\.?\s*E|M\.?\s*Sc|M\.?\s*A|M\.?\s*B\.?\s*A|'
      r'Ph\.?\s*D|Bachelor|Master|Diploma|Associate)[a-zA-Z\s.,]*?)'
      r'\s*(?:from|at|,|[-–|])\s*'
      r'([A-Z][a-zA-Z\s,&.]+?)'
      r'[,|\s]*'
      r'(\d{4}\s*[-–]\s*(?:\d{4}|Present|Current|\d{4}))',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(text)) {
      entries.add({
        'degree': match.group(1)?.trim() ?? '',
        'school': match.group(2)?.trim() ?? '',
        'duration': match.group(3)?.trim() ?? '',
      });
    }

    return entries;
  }

  /// Extracts general interests from resume text.
  static const List<String> _interestKeywords = [
    'Tech Startups', 'AI', 'Machine Learning', 'Venture Capital',
    'Blockchain', 'Web3', 'Sustainability', 'Open Source',
    'Aviation', 'Travel', 'Photography', 'Music', 'Sports',
    'Reading', 'Writing', 'Public Speaking', 'Volunteering',
    'Mentoring', 'Teaching', 'Gaming', 'Fitness', 'Cooking',
    'Design', 'Art', 'Film', 'Podcasts', 'Investing',
  ];

  List<String> _extractInterests(String text) {
    final found = <String>{};
    for (final interest in _interestKeywords) {
      if (text.toLowerCase().contains(interest.toLowerCase())) {
        found.add(interest);
      }
    }
    return found.toList();
  }

  /// Extracts professional interest keywords.
  static const List<String> _professionalInterestKeywords = [
    'B2B Partnerships', 'Co-Founder', 'Developer Relations',
    'Product Management', 'Growth Hacking', 'Fundraising',
    'Angel Investing', 'Advisory', 'Board Member', 'Consulting',
    'Freelance', 'Contract', 'Remote Work', 'Team Building',
    'Talent Acquisition', 'Sales', 'Marketing',
  ];

  List<String> _extractProfessionalInterests(String text) {
    final found = <String>{};
    for (final interest in _professionalInterestKeywords) {
      if (text.toLowerCase().contains(interest.toLowerCase())) {
        found.add(interest);
      }
    }
    return found.toList();
  }

  // ---------------------------------------------------------------------------
  // Firestore Persistence
  // ---------------------------------------------------------------------------

  /// Saves parsed resume data to the user's Firestore profile.
  Future<void> saveResumeDataToProfile(
    String userId,
    Map<String, dynamic> parsedData,
  ) async {
    try {
      final updates = <String, dynamic>{
        'resumeParsed': true,
        'resumeParsedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      };

      // Only update fields that have non-empty data
      final skills = parsedData['skills'] as List<String>? ?? [];
      if (skills.isNotEmpty) updates['skills'] = skills;

      final career = parsedData['careerTimeline'] as List<Map<String, dynamic>>? ?? [];
      if (career.isNotEmpty) updates['careerTimeline'] = career;

      final education = parsedData['educationTimeline'] as List<Map<String, dynamic>>? ?? [];
      if (education.isNotEmpty) updates['educationTimeline'] = education;

      final interests = parsedData['interests'] as List<String>? ?? [];
      if (interests.isNotEmpty) updates['interests'] = interests;

      final profInterests = parsedData['professionalInterests'] as List<String>? ?? [];
      if (profInterests.isNotEmpty) updates['professionalInterests'] = profInterests;

      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to save resume data: $e');
    }
  }
}
