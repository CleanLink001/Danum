import 'dart:io';

Future<List<String>> getLocalSubnets() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    List<String> subnets = [];
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
          final parts = ip.split('.');
          if (parts.length == 4) {
            subnets.add('${parts[0]}.${parts[1]}.${parts[2]}.');
          }
        }
      }
    }
    return subnets;
  } catch (e) {
    return [];
  }
}
