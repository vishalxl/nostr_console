import 'dart:io';
import 'package:qr/qr.dart';

enum enumRoomType { kind4, kind40, kind140, RoomLocationTag, RoomTTag}

String getPostKindFrom(enumRoomType eType) {
  switch (eType) {
  case enumRoomType.kind4:
    return "4";
  case enumRoomType.kind40:
    return "42";
  case enumRoomType.kind140:
    return "142";
  case enumRoomType.RoomLocationTag:
    return "1";
  case enumRoomType.RoomTTag:
    return "1";
  }

}

Set<String>? getTagsFromContent(String content) {
  Set<String>? tags = null;

  String regexp1 = '(#[a-zA-Z0-9_\-]+ )|(#[a-zA-Z0-9_\-]+)\$';
  RegExp httpRegExp = RegExp(regexp1);
  
  for( var match in httpRegExp.allMatches(content) ) {
    if( tags == null)
      tags = {};

    tags.add( content.substring(match.start + 1, match.end).trim() );
  }
  return tags;
}


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

Future<void> myWait(int ms) async {
  Future<void> foo1() async {
    await Future.delayed(Duration(milliseconds: ms));
    return;
  }
  await foo1();
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

String getQrCodeAsString(String str) {
  String output = "";

  final qrCode = QrCode(4, QrErrorCorrectLevel.L)
                ..addData('$str');
  final qrImage = QrImage(qrCode);

  assert( qrImage.moduleCount == 33);
  //print("qrimage modulecount =  ${qrImage.moduleCount}");
  String leftPadding = "   ";
  var x = 0;
  for (x = 0; x < qrImage.moduleCount -1 ; x += 2) {
    output += leftPadding;
    for (var y = 0; y < qrImage.moduleCount ; y++) {

      bool topDark = qrImage.isDark(y, x);
      bool bottomDark = qrImage.isDark(y, x + 1);
      if (topDark && bottomDark) {
        output += "█";
      }
      else if (topDark ) {
        output += "▀";
      } else if ( bottomDark) {
        output += "▄";
      } else if( !topDark && !bottomDark) {
        output += " ";
      }
    }
    output += "\n";
  }

  if( qrImage.moduleCount %2 == 1) {
    output += leftPadding;
    for (var y = 0; y < qrImage.moduleCount ; y++) {
      bool dark = qrImage.isDark(y, x);
      if (dark ) {
        output += "▀";
      } else {
        output += " ";
      }

    }
    output += "\n";
  }

  return output;
}

void clearScreen() {
  print("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
}

// returns a string entered by the user
String getStringFromUser(String prompt, [String defaultValue=""] ) {
  String str = "";
  
  stdout.write(prompt);
  str = (stdin.readLineSync())??"";

  if( str.length == 0)
    str = defaultValue;
  return str;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// relay related functions

// returns list in form  ( if 3 sized list)
// "pubkey1","pubkey2","pubkey3"
String getJsonList(Set<String> publicKeys) {
  String s = "";
  int i = 0;
  for(String pubkey in publicKeys) {
    s += "\"${pubkey.toLowerCase()}\"";
    if( i < publicKeys.length - 1) {
      s += ",";
    }
    i++; 
  }
  return s;
}

String getKindRequest(String subscriptionId, List<int> kind, int limit, int sinceWhen) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since":${sinceWhen.toString()}';
  }
  var    strSubscription1  = '["REQ","$subscriptionId",{"kinds":[';
  var    strSubscription2  ='], "limit":$limit$strTime  } ]';

  String strKind = "";
  for(int i = 0; i < kind.length; i++) {
    String comma = ",";
    if( i == kind.length-1) {
      comma = "";
    }
    strKind = strKind + kind[i].toString() + comma;
  }
  String strRequest = strSubscription1 + strKind + strSubscription2;
  //print(strRequest);
  return strRequest;
}

String getUserRequest(String subscriptionId, String publicKey, int numUserEvents, int sinceWhen) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since": ${sinceWhen.toString()}';
  }
  var    strSubscription1  = '["REQ","$subscriptionId",{ "authors": ["';
  var    strSubscription2  ='"], "limit": $numUserEvents $strTime  } ]';
  return strSubscription1 + publicKey.toLowerCase() + strSubscription2;
}

String getMentionRequest(String subscriptionId, Set<String> ids, int numUserEvents, int sinceWhen, String tagToGet) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since": ${sinceWhen.toString()}';
  }
  var    strSubscription1  = '["REQ","$subscriptionId",{ "$tagToGet": [';
  var    strSubscription2  ='], "limit": $numUserEvents $strTime  } ]';
  return strSubscription1 + getJsonList(ids) + strSubscription2;
}

String getMultiUserRequest(String subscriptionId, Set<String> publicKeys, int numUserEvents, int sinceWhen) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since": ${sinceWhen.toString()}';
  }

  var    strSubscription1  = '["REQ","$subscriptionId",{ "authors": [';
  var    strSubscription2  ='], "limit": $numUserEvents $strTime } ]';
  String s = "";
  s = getJsonList(publicKeys);
  return strSubscription1 + s + strSubscription2;
}

// ends with a newline
void printSet( Set<String> toPrint, [ String prefix = ""]) {
  stdout.write(prefix);

  int i = 0;
  toPrint.forEach((element) {
    if( i != 0) {
      stdout.write(", ");
    }

    stdout.write(element);
    i++;
  });
  stdout.write("\n");
}
