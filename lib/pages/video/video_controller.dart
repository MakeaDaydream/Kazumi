import 'dart:io';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/webview_desktop/webview_desktop_controller.dart';
import 'package:kazumi/pages/webview_linux/webview_linux_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:window_manager/window_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';

part 'video_controller.g.dart';

class VideoPageController = _VideoPageController with _$VideoPageController;

abstract class _VideoPageController with Store {
  @observable
  bool loading = true;

  @observable
  ObservableList<String> logLines = ObservableList.of([]);

  @observable
  int currentEspisode = 1;

  @observable
  int currentRoad = 0;

  // 安卓全屏状态
  @observable
  bool androidFullscreen = false;

  // 上次观看位置
  @observable
  int historyOffset = 0;

  String title = '';

  String src = '';

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  final PluginsController pluginsController = Modular.get<PluginsController>();
  final HistoryController historyController = Modular.get<HistoryController>();

  changeEpisode(int episode, {int currentRoad = 0, int offset = 0}) async {
    loading = true;
    currentEspisode = episode;
    this.currentRoad = currentRoad;
    logLines.clear();
    KazumiLogger().log(Level.info, '跳转到第$episode话');
    String urlItem = roadList[currentRoad].data[episode - 1];
    if (urlItem.contains(currentPlugin.baseUrl) ||
        urlItem.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
      urlItem = urlItem;
    } else {
      urlItem = currentPlugin.baseUrl + urlItem;
    }
    if (urlItem.startsWith('http://')) {
      urlItem = urlItem.replaceFirst('http', 'https');
    }
    if (Platform.isWindows) {
      final WebviewDesktopItemController webviewDesktopItemController =
          Modular.get<WebviewDesktopItemController>();
      await webviewDesktopItemController.loadUrl(urlItem, offset: offset);
    }
    if (Platform.isLinux) {
      final WebviewLinuxItemController webviewLinuxItemController =
          Modular.get<WebviewLinuxItemController>();
      await webviewLinuxItemController.loadUrl(urlItem, offset: offset);
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final WebviewItemController webviewItemController =
          Modular.get<WebviewItemController>();
      await webviewItemController.loadUrl(urlItem, offset: offset);
    }
  }

  Future<void> enterFullScreen() async {
    if (Platform.isIOS) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black,
        systemNavigationBarDividerColor: Colors.black,
        statusBarColor: Colors.black,
      ));
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(true);
      return;
    }
    await landScape();
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  //退出全屏显示
  Future<void> exitFullScreen() async {
    if (Platform.isIOS) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ));
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(false);
    }
    dynamic document;
    late SystemUiMode mode = SystemUiMode.edgeToEdge;
    try {
      if (kIsWeb) {
        document.exitFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid &&
            (await DeviceInfoPlugin().androidInfo).version.sdkInt < 29) {
          mode = SystemUiMode.manual;
        }
        await SystemChrome.setEnabledSystemUIMode(
          mode,
          overlays: SystemUiOverlay.values,
        );
        if (Utils.isCompact()) {
          verticalScreen();
        }
      }
    } catch (exception, stacktrace) {
      KazumiLogger()
          .log(Level.error, exception.toString(), stackTrace: stacktrace);
    }
  }

  //横屏
  Future<void> landScape() async {
    dynamic document;
    try {
      if (kIsWeb) {
        await document.documentElement?.requestFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        // await SystemChrome.setEnabledSystemUIMode(
        //   SystemUiMode.immersiveSticky,
        //   overlays: [],
        // );
        await SystemChrome.setPreferredOrientations(
          [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        );
        // await AutoOrientation.landscapeAutoMode(forceSensor: true);
      }
    } catch (exception, stacktrace) {
      // debugPrint(exception.toString());
      // debugPrint(stacktrace.toString());
      KazumiLogger()
          .log(Level.error, exception.toString(), stackTrace: stacktrace);
    }
  }

//竖屏
  Future<void> verticalScreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
}
