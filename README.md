# WealthPath

A personal finance iOS app for tracking paychecks, bills, and savings goals.

## Requirements

- Mac with [Xcode](https://apps.apple.com/us/app/xcode/id497799835) installed
- iOS 16+ simulator or physical iPhone

## Firebase Setup (Required)

This project uses Firebase for authentication and data storage. The `GoogleService-Info.plist` configuration file is **not included** in this repository for security reasons.

To run the app, you will need to:

1. Create a free [Firebase](https://firebase.google.com) project
2. Add an iOS app to the project using the bundle ID `com.davismorales.WealthPath`
3. Download the generated `GoogleService-Info.plist`
4. Add the file to `WealthPath/WealthPath/` in Xcode (drag it into the project navigator)

In Firebase, enable the following:
- **Authentication** → Email/Password sign-in
- **Firestore Database** → Create a database in production mode

## Running the App

Open **Terminal** and follow these steps:

**1. Clone the repository**

```bash
git clone https://github.com/davism7/WealthPath.git
