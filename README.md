# AI-Powered Attendance System

This is a high-performance biometric attendance solution built with Flutter. It leverages Google ML Kit for real-time face detection and a 512-dimensional FaceNet TFLite model for high-accuracy face recognition.



## 🚀 Key Features
* **Biometric Accuracy:** Utilizes a 512-d embedding space for superior recognition precision.
* **Real-time Detection:** Integrated with Google ML Kit for lightning-fast face localization.
* **Optimized Inference:** Custom normalization pipeline mapping images to the $[-1, 1]$ range.
* **Production Ready:** Implements asynchronous processing to ensure a 60fps UI/UX.

---

## 🏗️ Technical Architecture

The system follows a three-stage pipeline:
1. **Face Detection:** ML Kit identifies physical faces in the camera frame.
2. **Preprocessing:** Detected faces are cropped, resized to **160x160**, and normalized using:
   $$\text{normalized} = \frac{\text{pixel} - 127.5}{128.0}$$
3. **Vector Matching:** - The **FaceNet** model generates a feature vector $V \in \mathbb{R}^{512}$.
    - **Cosine Similarity** is calculated between the live vector and reference embeddings.

---

## 🛠️ Installation & Setup

### Prerequisites
* Flutter SDK (3.x or higher)
* Android Studio / USB Debugging enabled
* A physical Android device (Recommended for TFLite)

### Assets Configuration
Ensure your `assets/` folder is structured as follows:
```text
assets/
├── model/
│   └── facenet.tflite     # 512-d Model
├── photos/
│   └── student_01.jpg     # Reference images
└── metadata.json          # Student records & mapping
