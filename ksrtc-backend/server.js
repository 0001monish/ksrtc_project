require("dotenv").config();

const express = require("express");
const cors = require("cors");
const http = require("http");
const { Server } = require("socket.io");

const passengerRoutes = require("./routes/passengerRoutes");
const authRoutes = require("./routes/authRoutes");
const conductorRoutes = require("./routes/conductorRoutes");
const adminRoutes = require("./routes/adminRoutes");

const socketService = require("./services/socketService");

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
  },
});

socketService.initializeSocket(io);

app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
  }),
);

app.use(express.json());

app.use((req, res, next) => {
  req.io = io;
  next();
});

app.get("/", (req, res) => {
  res.json({
    message: "KSRTC Smart Bus Tracking API is running.",
  });
});

app.use("/auth", authRoutes);
app.use("/conductor", conductorRoutes);
app.use("/admin", adminRoutes);

// Passenger endpoints remain at the root to match existing Flutter paths.
app.use("/", passengerRoutes);

app.use((req, res) => {
  res.status(404).json({
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

app.use((error, req, res, next) => {
  console.error("Unhandled server error:", error);

  res.status(500).json({
    message: "Internal server error.",
  });
});

const PORT = process.env.PORT || 5001;

server.listen(PORT, () => {
  console.log(`KSRTC backend running on port ${PORT}`);
});
