# Comprehensive guide to manage location permissions in ArcGIS Maps SDK for Flutter

The **ArcGIS Maps SDK** provides a built-in location data source that continuously updates your device's location. When used in a Flutter app, it will automatically prompt the user with a system dialog to request location permissions at install time. This behavior from the SDK is specific to Flutter, as it works differently on other platforms. However, you may want more control over how and when these location requests are made in your app that is running, rather than relying on the system's default behavior. As an example, you might prefer to:

- Request location permissions on an onboarding screen instead of at first launch.
- Show a customized call-to-action screen to open location settings when location has not been granted.

In this article, we’ll use the [**ArcGIS Maps SDK for Flutter**](https://pub.dev/packages/arcgis_maps) and the [**permission_handler**](https://pub.dev/packages/permission_handler) package to create a smooth experience for users. We’re going to create an app that allows users to manage their location settings from within the app itself. When they grant location permission, a map will pop up. If they deny the permission, we’ll make it easy for them to go into their device settings and enable location access, so the map can display properly.

## **Set up ArcGIS Maps SDK**

Before diving in, ensure your Flutter app is set up to use the ArcGIS Maps SDK. This includes:

1. **Adding the Dependency**

   Add the `arcgis_maps` package to your project. Run the following command in your terminal:

    ```dart
    flutter pub add arcgis_maps
    ```

2. **Configuring Your API Key**

   Obtain an API key and configure your app for the ArcGIS Maps SDK.

   For detailed setup instructions, including platform-specific requirements, refer to the official [ArcGIS Maps SDK documentation](https://developers.arcgis.com/flutter).
    