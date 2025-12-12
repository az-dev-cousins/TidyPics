import 'package:photo_manager/photo_manager.dart';

Future<bool> checkAndRequestPermission() async {
  final PermissionState ps = await PhotoManager.requestPermissionExtend();
  return ps.isAuth;
}
