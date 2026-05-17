import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class FileService {
  FileService._();

  static Future<String> extractText({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();

    switch (ext) {
      case 'txt':
      case 'md':
      case 'csv':
        return String.fromCharCodes(bytes);

      case 'pdf':
        return _extractPdf(bytes);

      case 'docx':
        final text = _extractDocx(bytes);
        return text;

      case 'pptx':
        return _extractPptx(bytes);

      default:
        throw UnsupportedFileException(
          'File type ".$ext" is not supported.\nSupported: TXT, MD, CSV, PDF, DOCX, PPTX',
        );
    }
  }

  // ── PDF ──────────────────────────────────────────────────────

  static String _extractPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();

    for (int i = 0; i < document.pages.count; i++) {
      final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
      if (pageText.trim().isNotEmpty) {
        buffer.writeln(pageText);
      }
    }

    document.dispose();

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw UnsupportedFileException(
        'This PDF appears to be scanned or image-based.\nPlease use a text-based PDF.',
      );
    }
    return text;
  }

  // ── DOCX ─────────────────────────────────────────────────────

  static String _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? docXml;
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        docXml = file;
        break;
      }
    }

    if (docXml == null) {
      throw UnsupportedFileException('Could not read this Word document.');
    }

    final xmlString = String.fromCharCodes(docXml.content as Uint8List);
    final document = XmlDocument.parse(xmlString);
    final buffer = StringBuffer();

    for (final para in document.findAllElements('w:p')) {
      final paraText = StringBuffer();
      for (final run in para.findAllElements('w:t')) {
        paraText.write(run.innerText);
      }
      final text = paraText.toString().trim();
      if (text.isNotEmpty) buffer.writeln(text);
    }

    final result = buffer.toString().trim();
    if (result.isEmpty) {
      throw UnsupportedFileException('Could not extract text from this Word document.');
    }
    return result;
  }

  // ── PPTX ─────────────────────────────────────────────────────

  static String _extractPptx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // Collect all slide XML files sorted by slide number
    final slideFiles = <int, ArchiveFile>{};
    for (final file in archive) {
      final match = RegExp(r'ppt/slides/slide(\d+)\.xml').firstMatch(file.name);
      if (match != null) {
        final slideNumber = int.parse(match.group(1)!);
        slideFiles[slideNumber] = file;
      }
    }

    if (slideFiles.isEmpty) {
      throw UnsupportedFileException('Could not find any slides in this PowerPoint file.');
    }

    final buffer = StringBuffer();
    final sortedKeys = slideFiles.keys.toList()..sort();

    for (final key in sortedKeys) {
      final file = slideFiles[key]!;
      final xmlString = String.fromCharCodes(file.content as Uint8List);
      final document = XmlDocument.parse(xmlString);

      final slideText = StringBuffer();

      // Extract text from <a:t> tags (PowerPoint text runs)
      for (final para in document.findAllElements('a:p')) {
        final paraText = StringBuffer();
        for (final run in para.findAllElements('a:t')) {
          paraText.write(run.innerText);
        }
        final text = paraText.toString().trim();
        if (text.isNotEmpty) slideText.writeln(text);
      }

      final slide = slideText.toString().trim();
      if (slide.isNotEmpty) {
        buffer.writeln('--- Slide $key ---');
        buffer.writeln(slide);
        buffer.writeln();
      }
    }

    final result = buffer.toString().trim();
    if (result.isEmpty) {
      throw UnsupportedFileException(
        'No text found in this presentation.\nSlides may contain only images.',
      );
    }
    return result;
  }
}

class UnsupportedFileException implements Exception {
  final String message;
  const UnsupportedFileException(this.message);

  @override
  String toString() => message;
}