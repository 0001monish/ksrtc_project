const express = require("express");
const router = express.Router();

const adminController = require("../controllers/adminController");
const { verifyToken, allowRoles } = require("../middleware/authMiddleware");

router.use(verifyToken, allowRoles("ADMIN"));

router.get("/buses", adminController.getAllBuses);
router.post("/buses", adminController.createBus);
router.put("/buses/:id", adminController.updateBus);
router.patch("/buses/:id/active", adminController.setBusActive);

router.get("/routes", adminController.getRoutes);
router.post("/routes", adminController.createRoute);
router.put("/routes/:id", adminController.updateRoute);
router.delete("/routes/:id", adminController.deleteRoute);

router.get("/schedule", adminController.getSchedules);
router.post("/conductors", adminController.createConductor);
module.exports = router;
