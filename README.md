# KSRTC Smart Bus Tracking & Information Platform

A real-time public transportation tracking and information platform built using Flutter, Node.js, PostgreSQL, Google Maps, and Socket.IO.

## 1. Project Overview

The KSRTC Smart Bus Tracking & Information Platform is a full-stack application designed to improve public transportation information accessibility through real-time GPS tracking, live bus status updates, and centralized bus information management.

Passengers can view bus information, track buses on Google Maps, and receive service notifications. Conductors can share live GPS locations and update bus statuses, while administrators can manage buses and schedules through a centralized dashboard.

## 2. Problem Statement

Passengers often face difficulties knowing the real-time location of buses and accessing accurate information about delays, arrivals, departures, and schedule changes.

Traditional transportation systems may not provide timely updates, making journey planning difficult.

This project addresses these challenges by providing a centralized platform for real-time bus tracking and transportation information.

## 3. Features

### Passenger Module

- View available bus information and schedules.
- Track buses in real time using Google Maps.
- View current bus locations.
- Receive real-time bus status updates.
- Get notifications about transportation updates.

### Conductor Module

- Secure conductor authentication.
- View assigned bus and schedule.
- Automatic background GPS location updates.
- Update bus status:
  - ON_TIME
  - DELAYED
  - ARRIVED
  - DEPARTED
  - CANCELLED
  - COMPLETED
- Update current stop and remarks.

### Admin Module

- Secure admin authentication.
- Manage bus information.
- Manage bus schedules.
- Monitor bus operations.
- Manage transportation information.

### Real-Time Features

- Live GPS tracking.
- Real-time communication using Socket.IO.
- Live bus status updates.
- Passenger notifications.
- Automatic GPS location updates.

## 4. Technology Stack

| Component               | Technology            |
| ----------------------- | --------------------- |
| Frontend                | Flutter, Dart         |
| Backend                 | Node.js, Express.js   |
| Database                | PostgreSQL (Neon)     |
| Real-Time Communication | Socket.IO             |
| Maps Integration        | Google Maps Flutter   |
| Location Tracking       | Geolocator            |
| Authentication          | JSON Web Tokens (JWT) |
| API Communication       | REST APIs             |

## 5. System Architecture

The application follows a client-server architecture connecting passengers, conductors, and administrators to a centralized backend.

```text
       PASSENGER / CONDUCTOR / ADMIN
                    |
                    v
           FLUTTER APPLICATION
                    |
             REST API / SOCKET.IO
                    |
                    v
             NODE.JS + EXPRESS
                    |
          ---------------------
          |         |         |
        Routes  Controllers  Services
          |         |         |
          ---------------------
                    |
                    v
             POSTGRESQL (NEON)
                    |
                    v
                 SOCKET.IO
                    |
                    v
          REAL-TIME APP UPDATES
```

### Architecture Explanation

1. Flutter provides the user interface for passengers, conductors, and administrators.
2. Node.js and Express handle API requests and application business logic.
3. PostgreSQL stores user, bus, schedule, location, and status information.
4. Socket.IO enables real-time communication between the backend and Flutter application.
5. Geolocator obtains the conductor's GPS coordinates.
6. Google Maps displays live bus locations to passengers.

## 6. Database Schema

The application uses PostgreSQL as its relational database.

The main database entities include:

| Table              | Purpose                               |
| ------------------ | ------------------------------------- |
| accounts           | User authentication                   |
| citizen_profiles   | Passenger information                 |
| driver_profiles    | Conductor information                 |
| buses              | Bus information                       |
| schedules          | Bus schedules and assignments         |
| live_bus_location  | Live GPS coordinates and timestamps   |
| bus_status         | Current bus status, stop, and remarks |
| conductor_sessions | Active conductor sessions             |
| notifications      | Passenger notifications               |
| device_tokens      | Device notification tokens            |

_Note: Refer to the actual database migrations for the complete and exact database schema._

## 7. Project Structure

```text
ksrtc/
│
├── ksrtc-backend/
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── routes/
│   ├── services/
│   ├── sockets/
│   ├── server.js
│   ├── package.json
│   ├── package-lock.json
│   ├── .env.example
│   └── .gitignore
│
├── ksrtcapp/
│   ├── android/
│   ├── assets/
│   ├── lib/
│   ├── test/
│   ├── pubspec.yaml
│   └── .gitignore
│
├── screenshots/
│   ├── passenger-home.png
│   ├── bus-information.png
│   ├── live-tracking.png
│   ├── conductor-dashboard.png
│   ├── live-gps-tracking.png
│   ├── bus-status-update.png
│   └── admin-dashboard.png
│
├── README.md
└── LICENSE
```

## 8. Installation and Setup

### Prerequisites

- Node.js and npm
- Flutter SDK
- Android Studio or VS Code
- PostgreSQL database (Neon)
- Google Maps API key

### Step 1: Clone the Repository

```bash
git clone YOUR_GITHUB_REPOSITORY_URL
cd ksrtc_project
```

### Step 2: Backend Setup

Navigate to the backend folder:

```bash
cd ksrtc-backend
npm install
```

Create a `.env` file using `.env.example` and configure the required environment variables:

- PostgreSQL database connection string
- JWT secret
- Backend port
- Other required configuration

Start the backend using the appropriate script defined in `package.json`.

### Step 3: Frontend Setup

Open another terminal and navigate to the Flutter folder:

```bash
cd ksrtcapp
flutter pub get
```

Configure the Google Maps API key using the local Android secrets configuration.

Configure the API base URL to point to your backend server.

Run the Flutter application:

```bash
flutter run
```

## 9. Screenshots

All application screenshots are available in the [`screenshots/`](screenshots/) directory.

### Passenger Home Screen

![Passenger Home](screenshots/passenger-home.png)

### Bus Information Screen

![Bus Information](screenshots/bus-information.png)

### Live Bus Tracking

![Live Bus Tracking](screenshots/live-tracking.png)

### Conductor Dashboard

![Conductor Dashboard](screenshots/conductor-dashboard.png)

### Live GPS Tracking

![Live GPS Tracking](screenshots/live-gps-tracking.png)

### Bus Status Update

![Bus Status Update](screenshots/bus-status-update.png)

### Admin Dashboard

![Admin Dashboard](screenshots/admin-dashboard.png)

## 10. Future Improvements

- Improved estimated arrival time calculations.
- Route optimization.
- Advanced transportation analytics.
- Improved notification infrastructure.
- Production-grade monitoring and scalability.

## 11. License

This project is licensed under the MIT License. See the [LICENSE](LICENSE.txt) file for details.
