// Default to IO (stub) but conditional export handles the switch
export 'file_io.dart' 
  if (dart.library.html) 'file_web.dart';
