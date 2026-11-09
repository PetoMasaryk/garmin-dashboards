# Garmin Vibe-Coded Custom Dashboards 🚴‍♂️⚡

A collection of high-visibility **Connect IQ Data Field** projects designed to transform your Garmin Edge cycling computer screen into dynamic, color-coded metric displays.

## 📂 Repository Navigation

Quickly jump to the project subfolders in this repository:

| Data Field / Dashboard | Target Device | Navigation Link |
| :--- | :--- | :--- |
| **Edge 530 Custom Dashboard** | Garmin Edge 530 | [📁 Edge 530 Dashboard](./Edge530CustomDashboard) |
| **3s Power Data Field** | Garmin Edge 850 / Multi-Device | [📁 Power Data Field](./Power%20Data%20Field) |
| **HR Zone Data Field** | Garmin Edge 850 / Multi-Device | [📁 HR Data Field](./HR%20Data%20Field) |

---

## 🚲 Project Breakdown

### 1. Edge 530 Custom Dashboard (`./Edge 530 Dashboard`)

Targeted specifically for the **Garmin Edge 530** ($246 \times 322\text{ px}$, Connect IQ API Level 3.3). Designed as a full-screen primary layout.

* **Full-Screen Layout:** Dark-mode contrast layout designed for low power consumption and high visibility outdoors.
* **Metrics:** Clock, Current Speed, Average Speed, Cadence, Heart Rate, Altitude, Total Ascent / Descent, and Elapsed Time.
* **7-Zone Power Bar:** Visual FTP-based power zone strip with an active indicator position.
* **Calculated Values:** Includes smoothed grade estimates and rolling 3-second power calculations.

---

### 2. 3s Power Data Field (`./Power Data Field`)

A standalone single data field focused purely on dynamic power visualization and effort control.

* **3-Second Power Focus:** Smooth 3-second rolling average output to eliminate micro-fluctuations.
* **Dynamic Zone Backgrounds:** Displays full background/border color changes according to training power zones relative to FTP.
* **Edge 850 UI:** Scaled typography optimized for high-density screen displays.

---

### 3. HR Zone Data Field (`./HR Data Field`)

A dedicated heart rate monitoring field designed for immediate visual feedback during efforts.

* **Dynamic HR Zone Coloring:** Background and border tint shift dynamically depending on target heart rate zones ($Z_1$ through $Z_5$).
* **Clean & Legible:** High-contrast layout designed for fast reading during race or interval efforts.

---

## 🛠️ Build & Installation Guide

1. **Prerequisites:**
   * Download and set up the [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/).
   * Install the Connect IQ Extension for VS Code.

2. **Compilation:**
   * Open the target subfolder (e.g., `Power Data Field`) as your workspace root.
   * Select the target device (e.g., `edge_530` or `edge_850`).
   * Build using the Connect IQ compiler task.

3. **Device Configuration:**
   * Deploy the generated `.iq` file to your device via the standard developer app directory layout.
   * On your Edge device, edit your profile screen to a **1-field layout** and choose the Connect IQ data field.

---

## 🔗 References & Resources

* [Garmin Connect IQ Developer Portal](https://developer.garmin.com/connect-iq/)
* [Toybox.Activity.Info API Documentation](https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/Info.html)
* [Connect IQ Basics](https://developer.garmin.com/connect-iq/articles/connect-iq-basics/App_Types.html)