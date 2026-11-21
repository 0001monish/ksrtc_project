const express = require("express");
const router = express.Router();

const passengerController = require("../controllers/passengerController");

router.get("/search", passengerController.searchBuses);
router.get("/route/:id", passengerController.getRouteDetails);
router.get(
  "/live-location/bus/:bus_number",
  passengerController.getBusLocationByBusNumber,
);

module.exports = router;
