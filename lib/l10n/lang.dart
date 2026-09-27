import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'te.dart';

/// The app's language: English or Telugu. Every text on screen goes through [Tr.tr]; a text with no Telugu yet
/// stays in English, so a missing translation never breaks a screen. Only what is SHOWN is translated: values
/// the app stores or sends to the server (gender, codes) stay in English.
class Lang extends ChangeNotifier {
  Lang._();
  static final instance = Lang._();

  static const english = 'en';
  static const telugu = 'te';

  String code = english;
  bool get isTelugu => code == telugu;

  /// True once the person has picked a language (the first screen asks).
  bool chosen = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      code = p.getString('lang') ?? english;
      chosen = p.containsKey('lang');
    } catch (_) {
      // Saved settings unreadable: English.
    }
  }

  /// Switches the language. The app's root listens and redraws every screen at once ([redrawAll]).
  Future<void> set(String value, [BuildContext? _]) async {
    code = value == telugu ? telugu : english;
    chosen = true;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setString('lang', code);
    } catch (_) {}
  }

  /// Every widget under [root] builds again, so texts inside unchanged (cached) widgets switch too.
  static void redrawAll(BuildContext root) {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (root as Element).visitChildren(mark);
  }
}

extension Tr on String {
  /// This text in the app's language (English when there is no Telugu for it yet).
  String get tr => Lang.instance.isTelugu ? (te[this] ?? this) : this;
}

extension TrFill on String {
  /// A sentence with slots, translated whole so Telugu can keep its own word order:
  /// `'Book {0}'.trf([d.name])` → "Book Dr. Rao" / "Dr. Rao ని బుక్ చేయండి".
  String trf(List<Object?> values) {
    var s = tr;
    for (var i = 0; i < values.length; i++) {
      s = s.replaceAll('{$i}', '${values[i] ?? ''}');
    }
    return s;
  }
}
