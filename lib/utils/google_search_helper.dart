export 'google_search_stub.dart'
    if (dart.library.js) 'google_search_web.dart'
    if (dart.library.io) 'google_search_mobile.dart';
