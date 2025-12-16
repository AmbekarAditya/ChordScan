
import 'dart:core';

void main() {
  final links = [
    "//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.azchords.com%2Fo%2Foasis%2Dtabs%2D2851%2Fwonderwall%2Dtabs%2D963098.html&rut=66f01ca3c0d58585b39d4e51459c5d2e3cf59a57f384c8989f95e349c8eb7df0",
    "//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.guitartabs.cc%2Ftabs%2Fo%2Foasis%2Fwonderwall_tab_ver_4.html&rut=919c0673dedf5a6fb80d12ccf840bdbcda8ee15deac7f66f27bfbd4cb1515216",
    "//duckduckgo.com/l/?uddg=https%3A%2F%2Fgenius.com%2FOasis%2Dwonderwall%2Dlyrics&rut=135dcc2754bf3e1b09821ea807a1bfd494ec37531b9c294854e2bc3bfb1735d6"
  ];

  for (final link in links) {
    print('Testing: $link');
    var targetLink = link;
    if (link.contains('duckduckgo.com/l/')) {
        final uri = Uri.parse(link.startsWith('//') ? 'https:$link' : link);
        final uddg = uri.queryParameters['uddg'];
        if (uddg != null) {
          targetLink = uddg;
          print('  -> Decoded: $targetLink');
        } else {
          print('  -> Failed to decode uddg');
        }
    }
  }
}
