const express = require("express");
const router = express.Router();

const {
  registerUser,
  loginUser,
  loginConductor,
  loginAdmin,
} = require("../controllers/authController");

router.post("/register", registerUser);
router.post("/login", loginUser);
router.post("/conductor-login", loginConductor);
router.post("/admin-login", loginAdmin);

module.exports = router;
