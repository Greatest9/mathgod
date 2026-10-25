# MathGod 🧮

[![Website](https://img.shields.io/badge/Website-mathgod--woad.vercel.app-blue?style=flat-square)](https://mathgod-woad.vercel.app/#home)
[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg?style=flat-square)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)

MathGod is an offline-first, high-performance symbolic mathematics and calculus solver built for mobile devices.

The primary mission of this project is educational empowerment—providing university students with a robust Computer Algebra System (CAS) that runs completely offline, mitigating the barriers of high data costs and unstable internet connectivity.

🌍 **Official Landing Page & Documentation:** [mathgod-woad.vercel.app](https://mathgod-woad.vercel.app/#home)

---

## 🚀 The Engineering Behind MathGod

This application represents a novel integration architecture combining modern mobile UI frameworks with low-level symbolic math engines:

* **Frontend:** Built with Flutter, utilizing Dart FFI (Foreign Function Interface) to seamlessly bridge high-performance native layers.
* **Core Computing Kernel:** Powered by the Giac/Xcas C++ library developed by Bernard Parisse.
* **Native Compilation:** Implemented via custom `CMakeLists.txt` configurations to compile the native Giac source into an optimized Android Shared Object (`.so`) binary using the Android NDK.

---

## ⚖️ Open Source & Licensing

In strict compliance with the **GNU General Public License v2.0 (GPLv2)**, the complete integration layer, build scripts, and interface mechanics for this application are fully open-sourced here for the global developer community.

### Credits & Attribution

* **Giac/Xcas Core:** Developed by Bernard Parisse / Université Grenoble Alpes. Source and documentation: [Institut Fourier - Giac](https://www-fourier.ujf-grenoble.fr/~parisse/giac.html)
* **Android Build Dependencies:** The Android-specific pre-generated configuration headers and prebuilt GMP/MPFR static libraries used in this project were sourced from the [GeoGebra Giac fork](https://github.com/geogebra/giac). These files are not part of the original Giac project and are attributed to the GeoGebra team accordingly.
