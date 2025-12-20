// Stub file for dart:html on non-web platforms
// This provides empty implementations so the code compiles on mobile

class Blob {
  Blob(List<dynamic> parts, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String href = '';
  String download = '';
  CssStyleDeclaration style = CssStyleDeclaration();
  
  void click() {}
}

class CssStyleDeclaration {
  String display = '';
  String border = '';
  String height = '';
  String width = '';
}

class FileUploadInputElement {
  FileUploadInputElement();
  
  bool multiple = false;
  String accept = '';
  List<File>? files;
  
  void click() {}
  
  Stream<dynamic> get onChange => const Stream.empty();
}

class File {
  String get name => '';
  int get size => 0;
  String get type => '';
  int? get lastModified => 0;
}

class Document {
  Body? get body => Body();
}

class Body {
  Children? get children => Children();
}

class Children {
  void add(dynamic element) {}
  void remove(dynamic element) {}
}

extension ChildrenExtension on Children? {
  void add(dynamic element) {}
  void remove(dynamic element) {}
}

class IFrameElement {
  String src = '';
  CssStyleDeclaration style = CssStyleDeclaration();
  String allow = '';
}

class Window {
  void open(String url, String target) {}
}

final document = Document();
final window = Window();

