import 'dart:io';

class HistogramEntry {
  String str;
  int    count;
  HistogramEntry(this.str, this.count);
  static int histogramSorter(HistogramEntry a, HistogramEntry b) {
    if( a.count < b.count ) {
      return 1;
    } if( a.count == b.count ) {
      return 0;
    } else {
      return -1;
    }
  }
}


bool nonEnglish(String str) {
  bool result = false;
  return result;
}

bool isNumeric(String s) {
 return double.tryParse(s) != null;
}

bool isWordSeparater(String s) {
  if( s.length != 1) {
    return false;
  }
  return s[0] == ' ' || s[0] == '\n' || s[0] == '\r' || s[0] == '\t' 
      || s[0] == ',' || s[0] == '.' || s[0] == '-' || s[0] == '('|| s[0] == ')';
}


bool isWhitespace(String s) {
  if( s.length != 1) {
    return false;
  }
  return s[0] == ' ' || s[0] == '\n' || s[0] == '\r' || s[0] == '\t';
}

extension StringX on String {

  int isChannelPageNumber(int max) {
  
    if(this.length < 2 || this[0] != '/') {
      return 0;
    } 

    String rest = this.substring(1);

    //print("rest = $rest");
    int? n = int.tryParse(rest);
    if( n != null) {
      if( n < max)
        return n;
    }
    return 0;
  }

  isEnglish( ) {
    // since smaller words can be smileys they should not be translated
    if( length < 10) 
      return true;
    
    if( !isLatinAlphabet())
      return false;

    if (isRomanceLanguage())
      return false;

    return true;
  }

  isPortugese() {
    false; // https://1000mostcommonwords.com/1000-most-common-portuguese-words/
  }

  bool isRomanceLanguage() {

    // https://www.thoughtco.com/most-common-french-words-1372759
    Set<String> frenchWords = {"oui", "je", "le", "un", "de", "merci", "une", "ce", "pas"}; // "et" is in 'et al'
    Set<String> spanishWords = {"y", "se", "el", "uso", "que", "te", "los", "va", "ser", "si", "por", "lo", "es", "era", "un", "o"};
    Set<String> portugeseWords = {"como", "seu", "que", "ele", "foi", "eles", "tem", "este", "por", "quente", "vai", 
                                  "ter", "mas", "ou", "teve", "fora", "é", "te", "mais"};

    Set<String> romanceWords = frenchWords.union(spanishWords).union(portugeseWords);
    for( String word in romanceWords) {
      if( this.toLowerCase().contains(" $word ")) {
        return true;
      }
    }
    return false;
  }

  isLatinAlphabet({caseSensitive = false}) {
    int countLatinletters = 0;
    for (int i = 0; i < length; i++) {
      final target = caseSensitive ? this[i] : this[i].toLowerCase();
      if ( (target.codeUnitAt(0) > 96 && target.codeUnitAt(0) < 123)  || ( isNumeric(target) ) || isWhitespace(target)) {
        countLatinletters++; 
      }
    }
    
    if( countLatinletters < ( 40.0/100 ) * length ) {
      return false;
    } else {
      return true;
    }
  }
}    


bool isValidPubkey(String pubkey) {
  if( pubkey.length == 64) {
    return true;
  }

  return false;
}

String myPadRight(String str, int width) {
  String newStr = "";

  if( str.length < width) {
    newStr = str.padRight(width);
  } else {
    newStr = str.substring(0, width);
  }
  return newStr;
}

// returns tags as string that can be used to calculate event has. called from EventData constructor
String getStrTagsFromJson(dynamic json) {
  String str = "";

  int i = 0;
  for( dynamic tag in json ) {
    if( i != 0) {
      str += ",";
    }

    str += "[";
    int j = 0;
    for(dynamic element in tag) {
      if( j != 0) {
        str += ",";
      }
      str += "\"${element.toString()}\"";
      j++;
    }
    str += "]";
    i++;
  }
  return str;
}


String addEscapeChars(String str) {
  String temp = "";
  //temp = temp.replaceAll("\\", "\\\\");
  temp = str.replaceAll("\"", "\\\"");
  return temp.replaceAll("\n", "\\n");
}

String unEscapeChars(String str) {
  //print("in unEscape: |$str|");
  String temp = str.replaceAll("\"", "\\\"");
  //temp = temp.replaceAll("\\\\", "\\");
  temp = temp.replaceAll("\n", "\\n");
  //print("returning |$temp|\n");
  return temp;
}

void printUnderlined(String x) =>  { stdout.write("$x\n${getNumDashes(x.length)}\n")}; 

String getNumSpaces(int num) {
  String s = "";
  for( int i = 0; i < num; i++) {
    s += " ";
  }
  return s;
}

String getNumDashes(int num, [String dashType = "-"]) {
  String s = "";
  for( int i = 0; i < num; i++) {
    s += dashType;
  }
  return s;
}


List<List<int>> getUrlRanges(String s) {
  List<List<int>> urlRanges = [];
  String regexp1 = "http[s]*:\/\/[a-zA-Z0-9]+([.a-zA-Z0-9/_\\-\\#\\+=\\&\\?]*)";
  
  RegExp httpRegExp = RegExp(regexp1);
  for( var match in httpRegExp.allMatches(s) ) {
    List<int> entry = [match.start, match.end];
    urlRanges.add(entry);
  }

  return urlRanges;
}


// returns true if n is in any of the ranges given in list
int isInRange( int n, List<List<int>> ranges ) {
  for( int i = 0; i < ranges.length; i++) {
    if( n >= ranges[i][0] && n < ranges[i][1]) {
      return ranges[i][1];
    }
  }
  return 0;
}
