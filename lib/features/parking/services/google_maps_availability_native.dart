import 'package:flutter/foundation.dart';

bool get googleMapsRequested =>
    defaultTargetPlatform == TargetPlatform.android &&
    const bool.fromEnvironment('GOOGLE_MAPS_ENABLED', defaultValue: true);
bool get googleMapsReady => googleMapsRequested;
bool get googleMapsFailed => false;
