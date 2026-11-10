# SnapFix Flutter App

This directory contains the SnapFix mobile client for iOS and Android.

## Run

Start the FastAPI backend from `../server`, then run:

```sh
flutter pub get
flutter run
```

The default API address is `http://127.0.0.1:8001` for iOS Simulator. Use `http://10.0.2.2:8001` for Android Emulator after updating `lib/api.dart`. Physical devices require a reachable LAN or deployed backend address.

## Verify

```sh
flutter analyze
flutter test
```

See the [English project homepage](../README.md) or [简体中文项目主页](../README.zh-CN.md) for architecture, AI configuration, demo scenarios, evaluation, and source documentation.
