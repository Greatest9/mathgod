# MathGod 🧮

MathGod is an offline-first, high-performance symbolic mathematics and calculus solver built for mobile devices. 

The primary mission of this project is educational empowerment—providing university students with a robust Computer Algebra System (CAS) that runs completely offline, mitigating the barriers of high data costs and unstable internet connectivity.

## 🚀 The Engineering Behind MathGod

This application represents a novel integration architecture combining modern mobile UI frameworks with low-level symbolic math engines:
* **Frontend:** Built with Flutter using Dart FFI to bridge high-performance native layers.
* **Core Computing Kernel:** Powered by the incredible **Giac/Xcas** C++ library developed by Bernard Parisse.
* **Native Compilation:** Implemented via custom `CMakeLists.txt` configurations to compile the native Giac source into an optimized Android Shared Object (`.so`) binary using the Android NDK.

## ⚖️ Open Source & Licensing

In strict compliance with the **GNU General Public License v3.0 (GPLv3)**, the complete integration layer, build scripts, and interface mechanics for this application are fully open-sourced here for the global developer community. 

### Credits & Attribution
* **Giac/Xcas Core:** Developed by Bernard Parisse / Université Grenoble Alpes. 
* Core source repository and documentation can be found at: [Institut Fourier - Giac](https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac.html)
