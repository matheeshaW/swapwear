# SwapWear ♻️👕
### Swap Your Style, Not Your Wallet.

**SwapWear** is a mobile-based swapping platform designed to reduce textile waste and promote responsible fashion consumption. It enables users to swap, browse, and manage second-hand clothes through a secure, community-driven application.

Built for the **User Experience Engineering (SE3050)** module by Group **Y3S1-WE-32** at SLIIT.

---

## 📖 Table of Contents
- [About the Project](#-about-the-project)
- [Key Features](#-key-features)
- [Tech Stack](#-tech-stack)
- [Design Methodology](#-design-methodology)
- [Installation](#-installation)
- [Team & Contributions](#-team--contributions)
- [License](#-license)

---

## 🌍 About the Project
The fashion industry generates millions of tons of waste annually. **SwapWear** provides a digital alternative to fast fashion, aligning with **UN SDG 12: Responsible Consumption and Production**.

Our goal is to help students and eco-conscious consumers refresh their wardrobes without spending money or harming the environment. The app combines the convenience of e-commerce with the sustainability of a circular economy.

---

## ✨ Key Features
* **🔐 Seamless Authentication:** Secure login via Email/Password or **Google Sign-In** managed by Firebase Authentication.
* **👗 Smart Listings & Browsing:** Browse apparel with filters for size, style, and condition. Includes **AI-based auto-tagging** (Google Cloud Vision API) to automatically detect clothing attributes.
* **💬 Real-Time Negotiation:** A WhatsApp-style chat interface with read receipts and status tracking (Pending, Accepted, Completed) for transparent swapping.
* **🌱 Eco-Impact Dashboard:** Visual analytics showing personal contributions, including **CO₂ saved**, water conserved, and items reused.
* **🔔 Smart Notifications:** Real-time push notifications via Firebase Cloud Messaging (FCM) for swap requests and messages.
* **🏆 Gamification:** Earn badges (e.g., "Eco Hero", "Top Swapper") to stay motivated.

---

## 🛠 Tech Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Frontend** | ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white) | Cross-platform mobile UI development. |
| **Language** | ![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white) | Programming language for Flutter. |
| **Backend** | ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black) | Auth, Firestore, Storage, Analytics, FCM. |
| **AI Integration** | ![Google Cloud](https://img.shields.io/badge/Google_Cloud-4285F4?style=flat&logo=google-cloud&logoColor=white) | Google Cloud Vision API for image analysis. |
| **Design** | ![Figma](https://img.shields.io/badge/Figma-F24E1E?style=flat&logo=figma&logoColor=white) | Wireframing and High-Fidelity Prototyping. |

---

## 🎨 Design Methodology
We followed the **Double Diamond UX Design Process**:
1.  **Discover:** User research via interviews and surveys to understand pain points in textile recycling.
2.  **Define:** Created Personas, Empathy Maps, and User Stories to frame the problem.
3.  **Develop:** Ideation, sketching, and low-fidelity wireframing.
4.  **Deliver:** High-fidelity prototyping in Figma and final implementation in Flutter.

*See the `docs/` folder for our full UX Research Report.*

---

## 🚀 Installation

To run this project locally, you will need **Flutter** installed on your machine.

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/yourusername/SwapWear.git](https://github.com/yourusername/SwapWear.git)
    cd SwapWear
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Setup:**
    * Create a project in the [Firebase Console](https://console.firebase.google.com/).
    * Add an Android app and download the `google-services.json` file.
    * Place `google-services.json` into `android/app/`.
    * Enable **Authentication** (Google & Email), **Firestore**, and **Storage**.

4.  **Run the app:**
    ```bash
    flutter run
    ```

---
## 👥 Team & Contributions (Y3S1-WE-32)

| Name | Role | Responsibilities |
| :--- | :--- | :--- |
| Weerakoon W.M.M.B | **UX Researcher & Developer** | Auth, Profile Management, AI Wardrobe integration (Vision API). |
| Herath H.M.N.P | **UI/UX Designer** | Apparel Listing, Browsing, Wishlist, Firestore CRUD. |
| Kahakotuwa K.N | **Content Strategist** | Swap Request System, Real-time Chat Negotiation. |
| Liyanage H.G.W.R | **UX Tester & Analyst** | Logistics, Notifications (FCM), Gamification, Eco-Dashboard. |

---

## 📄 License
This project is for educational purposes as part of the SE3050 module at SLIIT.
