import 'dart:io';

// file to show docker issue

void main(List<String> arguments) async {
  stdout.write("Enter your name, anon: ");

  String? name = stdin.readLineSync();
  if( name != null) {
    print("Hello $name");
  } else {
    print("\nShould not print this if readlineSync works.");
  }
} 