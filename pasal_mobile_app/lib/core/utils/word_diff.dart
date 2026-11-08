import 'dart:typed_data';

enum DiffOp { equal, inserted, removed }

class DiffSegment {
  final DiffOp op;
  final String text;

  const DiffSegment(this.op, this.text);

  @override
  bool operator ==(Object other) =>
      other is DiffSegment && other.op == op && other.text == text;

  @override
  int get hashCode => Object.hash(op, text);

  @override
  String toString() => '${op.name}("$text")';
}

/// Word-level diff antara dua versi teks pasal.
///
/// Teks dipecah menjadi token kata, spasi, dan tanda baca. Awalan dan akhiran
/// yang sama dipangkas, lalu LCS dihitung hanya pada bagian tengah. Jika bagian
/// tengah terlalu besar ([maxMiddleTokens] / [maxCells]), hasilnya satu blok
/// "dihapus" dan satu blok "disisipkan" tanpa LCS.
class WordDiff {
  WordDiff._();

  /// Batas token per sisi pada bagian tengah (setelah pemangkasan).
  static const int maxMiddleTokens = 4000;

  /// Batas ukuran tabel LCS (n * m). 4 juta sel Uint16 = 8 MB.
  static const int maxCells = 4000000;

  static final RegExp _tokenPattern = RegExp(
    r'\s+|[\p{L}\p{N}_]+|[^\s\p{L}\p{N}_]',
    unicode: true,
  );

  static List<String> tokenize(String text) {
    return [for (final m in _tokenPattern.allMatches(text)) m.group(0)!];
  }

  /// Segmen berurutan dari [oldText] ke [newText]. Menggabungkan [equal],
  /// [removed], dan [inserted] dalam urutan segmen menghasilkan teks gabungan;
  /// hanya equal + inserted yang menghasilkan [newText], dan hanya
  /// equal + removed yang menghasilkan [oldText].
  static List<DiffSegment> compute(String oldText, String newText) {
    if (oldText == newText) {
      return oldText.isEmpty ? const [] : [DiffSegment(DiffOp.equal, oldText)];
    }

    final a = tokenize(oldText);
    final b = tokenize(newText);

    var prefix = 0;
    final minLen = a.length < b.length ? a.length : b.length;
    while (prefix < minLen && a[prefix] == b[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < minLen - prefix &&
        a[a.length - 1 - suffix] == b[b.length - 1 - suffix]) {
      suffix++;
    }

    final midA = a.sublist(prefix, a.length - suffix);
    final midB = b.sublist(prefix, b.length - suffix);

    final runs = <_Run>[];
    if (prefix > 0) runs.add(_Run.equal(a.sublist(0, prefix).join()));

    if (midA.isEmpty || midB.isEmpty) {
      _addChange(runs, midA.join(), midB.join());
    } else if (midA.length > maxMiddleTokens ||
        midB.length > maxMiddleTokens ||
        midA.length * midB.length > maxCells) {
      _addChange(runs, midA.join(), midB.join());
    } else {
      _lcsRuns(midA, midB, runs);
    }

    if (suffix > 0) {
      runs.add(_Run.equal(a.sublist(a.length - suffix).join()));
    }

    return _toSegments(_absorbSpaces(runs));
  }

  static void _addChange(List<_Run> runs, String removed, String inserted) {
    if (removed.isEmpty && inserted.isEmpty) return;
    if (runs.isNotEmpty && !runs.last.isEqual) {
      final last = runs.last;
      last.removed += removed;
      last.inserted += inserted;
    } else {
      runs.add(_Run.change(removed, inserted));
    }
  }

  static void _addEqual(List<_Run> runs, String text) {
    if (runs.isNotEmpty && runs.last.isEqual) {
      runs.last.removed += text;
      runs.last.inserted += text;
    } else {
      runs.add(_Run.equal(text));
    }
  }

  static void _lcsRuns(List<String> a, List<String> b, List<_Run> runs) {
    final n = a.length;
    final m = b.length;
    final width = m + 1;
    // table[i * width + j] = panjang LCS dari a[i..] dan b[j..].
    final table = Uint16List((n + 1) * width);
    for (var i = n - 1; i >= 0; i--) {
      final row = i * width;
      final next = (i + 1) * width;
      for (var j = m - 1; j >= 0; j--) {
        if (a[i] == b[j]) {
          table[row + j] = table[next + j + 1] + 1;
        } else {
          final down = table[next + j];
          final right = table[row + j + 1];
          table[row + j] = down >= right ? down : right;
        }
      }
    }

    var i = 0;
    var j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        _addEqual(runs, a[i]);
        i++;
        j++;
      } else if (table[(i + 1) * width + j] >= table[i * width + j + 1]) {
        _addChange(runs, a[i], '');
        i++;
      } else {
        _addChange(runs, '', b[j]);
        j++;
      }
    }
    while (i < n) {
      _addChange(runs, a[i++], '');
    }
    while (j < m) {
      _addChange(runs, '', b[j++]);
    }
  }

  /// Spasi (tanpa baris baru) yang diapit dua perubahan ikut dimasukkan ke
  /// perubahan, supaya "a b" -> "x y" tampil sebagai satu blok, bukan
  /// "a"->"x", spasi, "b"->"y".
  static List<_Run> _absorbSpaces(List<_Run> runs) {
    final out = <_Run>[];
    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      final isGap =
          run.isEqual &&
          i > 0 &&
          i < runs.length - 1 &&
          !runs[i - 1].isEqual &&
          !runs[i + 1].isEqual &&
          run.removed.trim().isEmpty &&
          !run.removed.contains('\n');
      if (isGap) {
        final prev = out.removeLast();
        final next = runs[++i];
        out.add(
          _Run.change(
            '${prev.removed}${run.removed}${next.removed}',
            '${prev.inserted}${run.inserted}${next.inserted}',
          ),
        );
      } else {
        out.add(run);
      }
    }
    return out;
  }

  static List<DiffSegment> _toSegments(List<_Run> runs) {
    final segments = <DiffSegment>[];
    for (final run in runs) {
      if (run.isEqual) {
        segments.add(DiffSegment(DiffOp.equal, run.removed));
      } else {
        if (run.removed.isNotEmpty) {
          segments.add(DiffSegment(DiffOp.removed, run.removed));
        }
        if (run.inserted.isNotEmpty) {
          segments.add(DiffSegment(DiffOp.inserted, run.inserted));
        }
      }
    }
    return segments;
  }
}

class _Run {
  final bool isEqual;
  String removed;
  String inserted;

  _Run.equal(String text) : isEqual = true, removed = text, inserted = text;
  _Run.change(this.removed, this.inserted) : isEqual = false;
}
