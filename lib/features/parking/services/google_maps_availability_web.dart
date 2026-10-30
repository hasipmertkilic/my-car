import 'dart:js_interop';

@JS('myCarGoogleMapsRequested')
external JSBoolean? get _requested;
@JS('myCarGoogleMapsReady')
external JSBoolean? get _ready;
@JS('myCarGoogleMapsFailed')
external JSBoolean? get _failed;
bool get googleMapsRequested => _requested?.toDart ?? false;
bool get googleMapsReady => _ready?.toDart ?? false;
bool get googleMapsFailed => _failed?.toDart ?? false;
