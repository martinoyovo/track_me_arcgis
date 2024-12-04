//
// Copyright 2024 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import 'dart:async';
import 'dart:math';

import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ShowDeviceLocation extends StatefulWidget {
  const ShowDeviceLocation({super.key});

  @override
  State<ShowDeviceLocation> createState() => _ShowDeviceLocationState();
}

class _ShowDeviceLocationState extends State<ShowDeviceLocation> with WidgetsBindingObserver {
  // Create a controller for the map view.
  final _mapViewController = ArcGISMapView.createController();
  // A flag for when the settings bottom sheet is visible.
  var _settingsVisible = false;
  // Create the system location data source.
  final _locationDataSource = SystemLocationDataSource();
  // A subscription to receive status changes of the location data source.
  StreamSubscription? _statusSubscription;
  var _status = LocationDataSourceStatus.stopped;
  // A subscription to receive changes to the auto-pan mode.
  StreamSubscription? _autoPanModeSubscription;
  var _autoPanMode = LocationDisplayAutoPanMode.recenter;
  // A flag for when the map view is ready and controls can be used.
  var _ready = false;
  var _appSettingOpened = false;
  var _locationPermission = AppPermissionStatus.denied;
  AppLifecycleState? _appLifecycleState;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    initLocationPermissions();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _locationDataSource.stop();
    _statusSubscription?.cancel();
    _autoPanModeSubscription?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _appLifecycleState = state;
      if(_appSettingOpened) {
        if(_appLifecycleState == AppLifecycleState.resumed) {
          print('is back');
          initLocationPermissions();
        }
      }
      print(_appLifecycleState);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          top: false,
          child: Builder(
            builder: (_) {
              switch(_locationPermission) {
                case AppPermissionStatus.granted:
                  return Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            // Add a map view to the widget tree and set a controller.
                            child: ArcGISMapView(
                              controllerProvider: () => _mapViewController,
                              onMapViewReady: onMapViewReady,
                            ),
                          ),
                          Center(
                            child: ElevatedButton(
                              onPressed: _status ==
                                  LocationDataSourceStatus.failedToStart
                                  ? null
                                  : () => setState(() => _settingsVisible = true),
                              child: const Text('Location Settings'),
                            ),
                          ),
                        ],
                      ),
                      // Display a progress indicator and prevent interaction until state is ready.
                      Visibility(
                        visible: !_ready,
                        child: SizedBox.expand(
                          child: Container(
                            color: Colors.white30,
                            child:
                            const Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ),
                    ],
                  );
                case AppPermissionStatus.denied:
                  return Center(
                    child: ElevatedButton(
                      onPressed: checkLocationPermissions,
                      child: const Text('Enable location'),
                    ),
                  );
                case AppPermissionStatus.permanentlyDenied:
                  return Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'App location permission is denied. Go to settings and enable the location to use the app ',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final appSettingOpened = await openAppSettings();
                            setState(() {
                              _appSettingOpened = appSettingOpened;
                            });
                          },
                          child: const Text('Open App settings'),
                        ),
                      ],
                    ),
                  );
              }
            },
          )
      ),
      // The Settings bottom sheet.
      bottomSheet: _settingsVisible ? buildSettings(context) : null,
    );
  }

  // The build method for the Geometry Settings bottom sheet.
  Widget buildSettings(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20.0,
        20.0,
        20.0,
        max(
          20.0,
          View.of(context).viewPadding.bottom /
              View.of(context).devicePixelRatio,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Location Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _settingsVisible = false),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Show Location'),
              const Spacer(),
              // A switch to start and stop the location data source.
              Switch(
                value: _status == LocationDataSourceStatus.started,
                onChanged: (_) {
                  if (_status == LocationDataSourceStatus.started) {
                    _mapViewController.locationDisplay.stop();
                  } else {
                    _mapViewController.locationDisplay.start();
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              const Text('Auto-Pan Mode'),
              const Spacer(),
              // A dropdown button to select the auto-pan mode.
              DropdownButton(
                value: _autoPanMode,
                onChanged: (value) {
                  _mapViewController.locationDisplay.autoPanMode = value!;
                },
                items: const [
                  DropdownMenuItem(
                    value: LocationDisplayAutoPanMode.off,
                    child: Text('Off'),
                  ),
                  DropdownMenuItem(
                    value: LocationDisplayAutoPanMode.recenter,
                    child: Text('Recenter'),
                  ),
                  DropdownMenuItem(
                    value: LocationDisplayAutoPanMode.navigation,
                    child: Text('Navigation'),
                  ),
                  DropdownMenuItem(
                    value: LocationDisplayAutoPanMode.compassNavigation,
                    child: Text('Compass'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void onMapViewReady() async {
    // Create a map with the Navigation Night basemap style.
    _mapViewController.arcGISMap =
        ArcGISMap.withBasemapStyle(BasemapStyle.arcGISNavigationNight);

    // Set the initial system location data source and auto-pan mode.
    _mapViewController.locationDisplay.dataSource = _locationDataSource;
    _mapViewController.locationDisplay.autoPanMode =
        LocationDisplayAutoPanMode.recenter;

    // Subscribe to status changes and changes to the auto-pan mode.
    _statusSubscription = _locationDataSource.onStatusChanged.listen((status) {
      setState(() => _status = status);
    });
    setState(() => _status = _locationDataSource.status);
    _autoPanModeSubscription =
        _mapViewController.locationDisplay.onAutoPanModeChanged.listen((mode) {
      setState(() => _autoPanMode = mode);
    });
    setState(
      () => _autoPanMode = _mapViewController.locationDisplay.autoPanMode,
    );

    // Attempt to start the location data source (this will prompt the user for permission).
    try {
      await _locationDataSource.start();
    } on ArcGISException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(content: Text(e.message)),
        );
      }
    }

    // Set the ready state variable to true to enable the UI.
    setState(() => _ready = true);
  }

  Future<void> checkLocationPermissions() async {
    final requestPermission = await Permission.location.request();
    if (requestPermission.isGranted) {
      setState(() {
        _locationPermission = AppPermissionStatus.granted;
      });
    } else if(requestPermission.isPermanentlyDenied) {
      setState(() {
        _locationPermission = AppPermissionStatus.permanentlyDenied;
      });
    } else {
      setState(() {
        _locationPermission = AppPermissionStatus.denied;
      });
    }

    print(_locationPermission);
  }

  Future<void> initLocationPermissions() async {
    final status = await Permission.location.status;
    print(status);
    switch(status) {
      case PermissionStatus.granted:
        setState(() {
          _locationPermission = AppPermissionStatus.granted;
        });
      case PermissionStatus.permanentlyDenied:
        setState(() {
          _locationPermission = AppPermissionStatus.permanentlyDenied;
        });
      case PermissionStatus.denied:
      default:
        setState(() {
          _locationPermission = AppPermissionStatus.denied;
        });
    }
  }
}

enum AppPermissionStatus { granted, denied, permanentlyDenied }
