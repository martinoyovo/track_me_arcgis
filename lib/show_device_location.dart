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
  // Create the system location data source.
  final _locationDataSource = SystemLocationDataSource();
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _appLifecycleState = state;
      if(_appSettingOpened) {
        if(_appLifecycleState == AppLifecycleState.resumed) {
          initLocationPermissions();
        }
      }
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
                      Expanded(
                        // Add a map view to the widget tree and set a controller.
                        child: ArcGISMapView(
                          controllerProvider: () => _mapViewController,
                          onMapViewReady: onMapViewReady,
                        ),
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
  }

  Future<void> initLocationPermissions() async {
    final status = await Permission.location.status;
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
