import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

const kAppAuthorEmail = 'huylv.tech@gmail.com';
const kBuyMeCoffeeUrl = 'https://buymeacoffee.com/huylvtech';
const kBankQRData =
    '00020101021138510010A00000072701210006970407010763338880208QRIBFTTA53037045802VN830084006304AC20';

final appInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});
