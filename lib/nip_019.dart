import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';

// can have keys: id, relays ( whose value is an array of strings)
typedef Nevent = Map<String, Object>;

/// bech32-encoded entities
class Nip19 {
  static encodePubkey(String pubkey) {
    return bech32Encode("npub", pubkey);
  }

  static encodePrivkey(String privkey) {
    return bech32Encode("nsec", privkey);
  }

  static encodeNote(String noteid) {
    return bech32Encode("note", noteid);
  }

  static String decodePubkey(String data) {
    Map map = bech32Decode(data);
    if (map["prefix"] == "npub") {
      return map["data"];
    } else {
      return "";
    }
  }

  static String decodePrivkey(String data) {
    Map map = bech32Decode(data);
    if (map["prefix"] == "nsec") {
      return map["data"];
    } else {
      return "";
    }
  }

  static String decodeNote(String data) {
    Map map = bech32Decode(data);
    if (map["prefix"] == "note") {
      return map["data"];
    } else {
      return "";
    }
  }

  static Nevent decodeNevent(String data) {
    var localDebug = false;
    if(localDebug) print("in decodeNevent len data = ${data.length} data = $data");
    Nevent nevent = {};
    int iData = 0; 

    while( iData + 4 < data.length) {
      if(localDebug) print("iData = $iData");
      List<int> typeList = hex.decode( data.substring(iData, iData + 2));
      List<int> lenList = hex.decode( data.substring(iData + 2, iData + 4));
    
      int type = typeList[0];
      int len = lenList[0];

      if(localDebug) print("type = $type len = $len"); 

      switch(type) {
      case 0:
        String id = data.substring(iData + 4, iData + 4 + len * 2);
        nevent["id"] = id;
        if(localDebug) print("nevent id = $id");
        break;
      case 1:
        String relay = data.substring(iData + 4, iData + 4 + len * 2);
        // convert hex string to list of int 
        List<int> intRelay = [];
        intRelay = hex.decode(relay);
        const asciiDecoder = AsciiDecoder(allowInvalid: true);

        if(localDebug) print("before AsciiDecoder call");
        final relayURL = asciiDecoder.convert(intRelay);

        if( nevent["relays"] == null) {
          nevent["relays"] = [relayURL];
        } else { 
          (nevent["relays"] as List<String>).add(relayURL);
        }

        if(localDebug) print("nevent relay = $relayURL");

        break;
      case 2:

        break;
      case 3:

        break;
      default:
        if(localDebug) print("in decodeNevent: malformed nevent" );
        return nevent;
      
      }
      if(localDebug) print("   to next TLV");
      iData = iData + 4 + len * 2 ;
    }

    return nevent;
  }
}


/// help functions

String bech32Encode(String prefix, String hexData) {
  final data = hex.decode(hexData);
  final convertedData = convertBits(data, 8, 5, true);
  final bech32Data = Bech32(prefix, convertedData);
  return bech32.encode(bech32Data);
}

Map<String, String> bech32Decode(String bech32Data) {
  //print("in becn32Decode 1 bech32Data = $bech32Data");
  final decodedData = bech32.decode(bech32Data, Bech32Validations.maxInputLength + 300);
  //print(decodedData.hrp);
  final convertedData = convertBits(decodedData.data, 5, 8, false);
  final hexData = hex.encode(convertedData);

  return {'prefix': decodedData.hrp, 'data': hexData};
}

List<int> convertBits(List<int> data, int fromBits, int toBits, bool pad) {
  var acc = 0;
  var bits = 0;
  final maxv = (1 << toBits) - 1;
  final result = <int>[];

  for (final value in data) {
    if (value < 0 || value >> fromBits != 0) {
      throw Exception('Invalid value: $value');
    }
    acc = (acc << fromBits) | value;
    bits += fromBits;

    while (bits >= toBits) {
      bits -= toBits;
      result.add((acc >> bits) & maxv);
    }
  }

  if (pad) {
    if (bits > 0) {
      result.add((acc << (toBits - bits)) & maxv);
    }
  } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
    throw Exception('Invalid data');
  }

  return result;
}
