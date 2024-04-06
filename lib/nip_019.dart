import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';

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
}

/// help functions

String bech32Encode(String prefix, String hexData) {
  final data = hex.decode(hexData);
  final convertedData = convertBits(data, 8, 5, true);
  final bech32Data = Bech32(prefix, convertedData);
  return bech32.encode(bech32Data);
}

Map<String, String> bech32Decode(String bech32Data) {
  final decodedData = bech32.decode(bech32Data);
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
