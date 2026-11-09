# Edge 530 Custom Dashboard — Connect IQ source project

This is a first-pass Connect IQ Data Field project targeting the Garmin Edge 530 (246 × 322 px, API level 3.3). The intended usage is to add it as the **only data field** on a data screen so the custom drawing area is as large as possible.

## What's implemented in source

- Dark full-screen dashboard layout inspired by the agreed mockup
- Clock, current/average speed, cadence, heart rate, altitude, ascent/descent, elapsed time
- Approximate 3-s rolling power average from the latest three data-field updates
- FTP-based seven-colour power zone strip and marker
- HR-coloured panel
- Smoothed grade estimate derived from altitude/distance samples

## Important limitations — read before installing

This is **source code, not a compiled `.iq` application**. It has not been compiled or tested in Garmin's simulator in this environment. It must be built with the official Garmin Connect IQ SDK and may need syntax/API adjustments after compilation.

Three fields in the visual concept cannot be populated reliably using the basic `Activity.Info` fields used by this project:

- **Di2 battery:** shown as `--` placeholder. The basic activity data API does not expose Di2 battery percentage.
- **Power-meter battery:** shown as `--` placeholder. Sensor battery support requires a separate ANT+ integration and depends on the sensor/device API data available to the app.
- **Performance condition:** shown as `PC --` placeholder. It is not exposed as a field in the documented `Activity.Info` API for this implementation.

The grade is an estimate calculated from altitude change over distance, not Garmin's native grade field. It can be noisy at low speed or with GPS/barometric altitude variation. The rolling power is the mean of the last three updates, not guaranteed to be exactly three seconds if the device update cadence varies. FTP (230 W) and HR-zone thresholds are currently constants in the source and can be adjusted.

## Build

1. Install Garmin Connect IQ SDK and its VS Code extension / command-line tools.
2. Open this folder as the Connect IQ project.
3. Select `Edge530` as the target device and compile `manifest.xml`.
4. Run in the Edge 530 simulator, inspect clipping and font fit, and correct any SDK/compiler issues.
5. Once compiled, install the `.iq` package on the device using Garmin's developer/install workflow.

## Device setup

On the Edge 530, create a data screen with one field and select **Edge 530 Custom Dashboard**. Multi-field layouts will reduce the available drawing area and will not match the intended design.

## References

- Garmin Connect IQ compatible devices: https://developer.garmin.com/connect-iq/compatible-devices/
- Activity.Info API: https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/Info.html
- Connect IQ app types / data fields: https://developer.garmin.com/connect-iq/articles/connect-iq-basics/App_Types.html
