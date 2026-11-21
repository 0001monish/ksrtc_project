# KSRTC Smart Bus Tracking & Reservation System

A real-time bus tracking and seat reservation platform designed to improve public transportation services through GPS tracking, digital reservations, and real-time communication.

## Project Overview

The KSRTC Smart Bus Tracking & Reservation System is a full-stack application that connects passengers, conductors, and administrators through a centralized platform.

Passengers can reserve bus seats and track buses in real time. Conductors can share live GPS locations and update bus statuses, while administrators can manage buses, schedules, and reservations.

## Problem Statement

Traditional public transportation systems often lack convenient seat reservation facilities, real-time bus tracking, and timely communication about delays or schedule changes.

Passengers may struggle to know the current location of their buses, while transport administrators need an efficient way to manage bus operations.

This project addresses these challenges through a centralized digital transportation management system.

## Features

### Passenger Module
- Passenger registration and login.
- Browse available buses and schedules.
- Seat reservation.
- View reservation details.
- Real-time bus tracking using Google Maps.
- Receive notifications and bus status updates.

### Conductor Module
- Conductor authentication.
- View assigned bus and schedule.
- Automatic background GPS location updates.
- Update bus status (ON_TIME, DELAYED, ARRIVED, DEPARTED, CANCELLED, COMPLETED).
- Update current stop and remarks.

### Admin Module
- Admin authentication.
- Manage buses and schedules.
- Manage reservations.
- Monitor bus operations.
- Manage transportation information.

### Real-Time Features
- Live bus location updates.
- Socket.IO communication.
- Real-time bus status updates.
- Passenger notifications.
- Automatic GPS tracking.

## Technology Stack

| Component | Technology |
|---|---|
| Frontend | Flutter, Dart |
| Backend | Node.js, Express.js |
| Database | PostgreSQL (Neon) |
| Real-time Communication | Socket.IO |
| Maps | Google Maps Flutter |
| Location Tracking | Geolocator |
| Authentication | JWT |
| API Communication | REST APIs |

## System Architecture

The application follows a client-server architecture.

```text
             PASSENGER
                 |
             CONDUCTOR
                 |
               ADMIN
                 |
                 v
        FLUTTER APPLICATION
                 |
          REST API / Socket.IO
                 |
                 v
        NODE.JS + EXPRESS
                 |
        -------------------
        |        |        |
     Routes  Controllers Services
        |        |        |
        -------------------
                 |
                 v
          POSTGRESQL (NEON)
                 |
                 v
          REAL-TIME UPDATES
                 |
              SOCKET.IO
                 |
                 v
       FLUTTER APPLICATION
```

### Architecture Explanation

1. Flutter provides the user interface for passengers, conductors, and administrators.
2. Node.js and Express handle API requests and business logic.
3. PostgreSQL stores application data.
4. Socket.IO provides real-time communication.
5. Geolocator obtains the conductor's GPS coordinates.
6. Google Maps displays bus locations to passengers.

## Database Schema

The system uses PostgreSQL as its relational database.

The main data entities include:

| Entity | Purpose |
|---|---|
| Users / Accounts | User authentication and profiles |
| Buses | Bus information |
| Schedules | Bus routes and scheduled journeys |
| Reservations | Passenger seat reservations |
| Live Bus Locations | GPS coordinates and update timestamps |
| Bus Status | Current bus status, stop, and remarks |
| Conductor Sessions | Active conductor and bus assignments |
| Notifications | Passenger and system notifications |

*Note: Update this list to match the exact table names in your final database schema.*

## Project Structure

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
│   ├── .env.example
│   └── .gitignore
│
├── ksrtcapp/
│   ├── android/
│   ├── assets/
│   ├── lib/
│   ├── pubspec.yaml
│   └── .gitignore
│
├── README.md
└── LICENSE
```

## Installation and Setup

### Prerequisites

- Node.js and npm
- Flutter SDK
- Android Studio or VS Code
- PostgreSQL database (Neon)
- Google Maps API key

### 1. Clone the Repository

```bash
git clone YOUR_GITHUB_REPOSITORY_URL
cd ksrtc
```

### 2. Backend Setup

```bash
cd ksrtc-backend
npm install
```

Create a `.env` file using `.env.example` and configure your environment variables, including your PostgreSQL connection string and JWT secret.

Start the backend using the appropriate script defined in `package.json`.

### 3. Frontend Setup

```bash
cd ../ksrtcapp
flutter pub get
```

Configure the Google Maps API key using the local Android secrets configuration.

Configure the API base URL to point to your backend server.

Run the Flutter application:

```bash
flutter run
```

## Screenshots

Add screenshots of your application in a `screenshots/` folder.

Suggested screenshots:

- Passenger Home Screen
- Bus Search and Reservation
- Live Bus Tracking
- Conductor Dashboard
- Live GPS Tracking
- Bus Status Update
- Admin Dashboard

Example:

```markdown
![Passenger Home](screenshots/passenger-home.png)

![Live Bus Tracking](screenshots/live-tracking.png)

![Conductor Dashboard](screenshots/conductor-dashboard.png)
```

## Future Improvements

- Online payment integration.
- Improved route optimization.
- Advanced bus arrival time estimation.
- Enhanced analytics dashboard.
- Production-grade notification infrastructure.
- Improved scalability and monitoring.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE.txt) file for details.

## Author

Developed as a full-stack public transportation management project using Flutter, Node.js, PostgreSQL, and real-time technologies.
