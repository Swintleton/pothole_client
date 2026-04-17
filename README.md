# Road Defect Mapping Client

This repository contains the Flutter-based client application for the Road Defect Mapping project. The client communicates with the server application to authenticate users, capture road images, submit frames with location data, display detected potholes on an interactive map, and let users confirm or manage detections.

## What I Built

I built the client-side application of the project. It provides the user-facing workflow for:

- user registration and login
- camera-based road image capture
- periodic frame upload to the backend
- GPS-based location handling
- map-based visualization of detected potholes
- manual pothole creation and editing
- confirmation of detected potholes from the mobile client

## Tech Stack

The client is built with **Flutter** and **Dart**, with the following core packages and technologies:

- **google_maps_flutter** for interactive map rendering
- **camera** for live camera access and frame capture
- **location** and **permission_handler** for GPS and runtime permissions
- **http** for communication with the Flask backend
- **image** for image processing before upload
- **shared_preferences** for storing the authentication token, user ID, and role locally
- **Material 3** UI with Flutter's built-in widget system

## Features

- User authentication with persistent login state
- Registration and login screens
- Bottom navigation with **Home**, **Map**, and **Camera** pages
- Camera streaming and frame upload to the backend
- Detection confirmation dialog with image preview
- Interactive Google Map with pothole markers
- Manual pothole placement by long-pressing the map
- Editing and deleting potholes from the map view
- Role-aware map editing, where save/delete actions are only available to admins or the creator of the pothole entry

## Project Structure

```text
lib/
├── auth_helper.dart        # Authentication helper methods
├── camera_page.dart        # Camera capture and upload page
├── config.dart             # Backend and environment configuration
├── login_page.dart         # Login screen
├── main.dart               # App entry point and navigation
├── map_page.dart           # Google Maps page
├── my_home_page.dart       # Home screen
└── registration_page.dart  # Registration screen
```

## Requirements

- Flutter SDK with a Dart version compatible with `>=3.4.3 <4.0.0`
- A running instance of the server application
- A reachable backend URL configured for your environment
- Platform-specific Flutter tooling for the target device or emulator

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/Swintleton/pothole_client.git
   cd pothole_client
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Update the backend address before running the app.

   The current implementation uses a local server address in the client code, so you should replace it with the address of your own server where needed.

4. Run the application:

   ```bash
   flutter run
   ```

## Usage

After login, the application opens the main interface with three sections:

- **Home**: landing page of the app
- **Map**: shows potholes retrieved from the backend on a Google Map
- **Camera**: captures frames, uploads them to the backend, and handles detection confirmation

The map page loads pothole coordinates from the server and displays them as markers. Users can long-press the map to add a pothole manually. Existing markers can be opened for editing, and authorized users can update or delete entries.

The camera page requests camera permission, starts a live camera feed, periodically uploads frames to the backend, and polls the server for pending detection confirmations. When a detection needs review, the app shows a confirmation dialog and submits the user's response back to the server.

## Backend Integration

The client communicates with the server using authenticated HTTP requests. Based on the current implementation, the following backend endpoints are used by the mobile app:

- `POST /login`
- `POST /logout`
- `POST /upload_frame`
- `GET /get_detection_confirmation`
- `POST /confirm`
- `GET /potholes`
- `POST /add_pothole`
- `PUT /edit_pothole/<id>`
- `DELETE /delete_pothole/<id>`

## Documentation

Complete project documentation is available in the server repository's [`documentation`](https://github.com/Swintleton/pothole_server/tree/main/documentation) folder.

Detailed documentation:

- English: [`documentation_english.pdf`](https://github.com/Swintleton/pothole_server/blob/main/documentation/documentation_english.pdf)
- Hungarian: [`documentation_hungarian_original.pdf`](https://github.com/Swintleton/pothole_server/blob/main/documentation/documentation_hungarian_original.pdf)

## Notes

- The current client code contains configure the backend base URL in `config.dart` for your environment pointing to a local network IP address. These should be updated before deployment.
- The repository includes Android, iOS, Linux, macOS, Web, and Windows platform folders generated for Flutter targets.
