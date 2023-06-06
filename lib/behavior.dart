// ignore_for_file: non_constant_identifier_names
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart' hide Headers;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:intl/intl.dart';
import 'package:retrofit/retrofit.dart';
part 'behavior.g.dart';

@RestApi(baseUrl: "https://nightmare.fun:444/api/v1", parser: Parser.FlutterCompute)
abstract class BehaviorAPI {
  factory BehaviorAPI(Dio dio, {String baseUrl}) = _BehaviorAPI;

  ///
  @POST('/user_behavior/')
  Future<String> appInit({
    @DioOptions() RequestOptions? options,
    @Body() required Map<String, dynamic> params,
  });
}

BehaviorAPI behaviorAPI = BehaviorAPI(Dio());

void appInit(Map<String, dynamic> params) {
  behaviorAPI.appInit(params: params);
}

initApi(String appName, String versionName) async {
  DeviceInfoPlugin plugin = DeviceInfoPlugin();
  JsonEncoder encoder = const JsonEncoder.withIndent('  ');
  Map<String, dynamic> request = {};
  if (GetPlatform.isAndroid) {
    AndroidDeviceInfo androidDeviceInfo = await plugin.androidInfo;
    // String prettyPrint = encoder.convert(androidDeviceInfo.data);
    // Log.i('androidDeviceInfo -> $prettyPrint');
    request['arch'] = androidDeviceInfo.supportedAbis.first;
    request['os'] = 'Android ${androidDeviceInfo.version.release}';
    request['model'] = await UniqueUtil.getDevicesId();
  }
  if (GetPlatform.isMacOS) {
    MacOsDeviceInfo macOsDeviceInfo = await plugin.macOsInfo;
    // String macprettyPrint = encoder.convert(macOsDeviceInfo.data);
    // Log.i('macOsDeviceInfo -> $macprettyPrint');
    request['arch'] = macOsDeviceInfo.arch;
    request['os'] = macOsDeviceInfo.osRelease;
    request['model'] = macOsDeviceInfo.model;
  }
  DateTime dateTime = DateTime.now();
  String time = DateFormat('yyyy-MM-dd').format(dateTime);
  request.addAll({
    'app': appName,
    'time': time,
    'platform': GetPlatform.isAndroid
        ? 'Android'
        : GetPlatform.isMacOS
            ? 'macOS'
            : GetPlatform.isWindows
                ? 'Windows'
                : 'Linux',
    'unique_key': await UniqueUtil.getUniqueKey(),
    'app_version': versionName,
  });
  Log.i('request -> ${encoder.convert(request)}');
  appInit(request);
}
