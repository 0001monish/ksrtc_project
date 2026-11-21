const express = require("express");
const router = express.Router();

const conductorController = require("../controllers/conductorController");
const { verifyToken, allowRoles } = require("../middleware/authMiddleware");

// Validate controller handlers
const requiredHandlers = [
  "checkActiveSession",
  "getScheduleByBusNumber",
  "loginToBus",
  "logoutBus",
  "updateBusStatus",
  "updateBusLocation",
];

for (const handler of requiredHandlers) {
  if (typeof conductorController[handler] !== "function") {
    throw new Error(
      `conductorRoutes: conductorController.${handler} is missing or is not a function`,
    );
  }
}

if (typeof verifyToken !== "function") {
  throw new Error("conductorRoutes: verifyToken is missing");
}

if (typeof allowRoles !== "function") {
  throw new Error("conductorRoutes: allowRoles is missing");
}

// All bus-session operations require conductor authentication
router.use(verifyToken, allowRoles("CONDUCTOR"));

router.get("/active-session", conductorController.checkActiveSession);

router.get("/schedule/:bus_number", conductorController.getScheduleByBusNumber);

router.post("/login-bus", conductorController.loginToBus);

router.post("/logout-bus/:session_id", conductorController.logoutBus);

router.put("/update-status", conductorController.updateBusStatus);

router.post("/update-location", conductorController.updateBusLocation);

module.exports = router;
