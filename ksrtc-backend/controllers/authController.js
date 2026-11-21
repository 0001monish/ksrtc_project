const pool = require("../config/db");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

// =====================================
// CREATE JWT
// =====================================
const createToken = (payload) => {
  if (!process.env.JWT_SECRET) {
    throw new Error("JWT_SECRET is missing from backend environment.");
  }

  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: "1d",
  });
};

// =====================================
// PASSENGER REGISTER
// POST /auth/register
// =====================================
exports.registerUser = async (req, res) => {
  try {
    const { full_name, email, phone_number, password } = req.body;

    if (
      !full_name?.trim() ||
      !email?.trim() ||
      !phone_number?.trim() ||
      !password
    ) {
      return res.status(400).json({
        message: "All fields are required.",
      });
    }

    const normalizedName = full_name.trim();
    const normalizedEmail = email.trim().toLowerCase();
    const normalizedPhone = phone_number.trim();

    if (!/^\d{10}$/.test(normalizedPhone)) {
      return res.status(400).json({
        message: "Phone number must contain exactly 10 digits.",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        message: "Password must contain at least 6 characters.",
      });
    }

    const existingUser = await pool.query(
      `
      SELECT user_id
      FROM public.users
      WHERE LOWER(email) = $1
         OR phone_number = $2
      LIMIT 1
      `,
      [normalizedEmail, normalizedPhone],
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        message: "Email or phone number is already registered.",
      });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `
      INSERT INTO public.users
        (full_name, email, phone_number, password)
      VALUES ($1, $2, $3, $4)
      RETURNING user_id, full_name, email, phone_number
      `,
      [normalizedName, normalizedEmail, normalizedPhone, passwordHash],
    );

    return res.status(201).json({
      message: "Registration successful.",
      user: result.rows[0],
    });
  } catch (error) {
    console.error("registerUser:", error);

    if (error.code === "23505") {
      return res.status(409).json({
        message: "Email or phone number is already registered.",
      });
    }

    return res.status(500).json({
      message: "Server error during registration.",
    });
  }
};

// =====================================
// PASSENGER LOGIN
// POST /auth/login
// =====================================
exports.loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email?.trim() || !password) {
      return res.status(400).json({
        message: "Email and password are required.",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const result = await pool.query(
      `
      SELECT
        user_id,
        full_name,
        email,
        phone_number,
        password
      FROM public.users
      WHERE LOWER(email) = $1
      LIMIT 1
      `,
      [normalizedEmail],
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        message: "Invalid email or password.",
      });
    }

    const user = result.rows[0];

    const passwordMatch = await bcrypt.compare(password, user.password);

    if (!passwordMatch) {
      return res.status(401).json({
        message: "Invalid email or password.",
      });
    }

    const token = createToken({
      user_id: user.user_id,
      role: "PASSENGER",
    });

    delete user.password;

    return res.status(200).json({
      message: "Login successful.",
      token,
      role: "PASSENGER",
      user,
    });
  } catch (error) {
    console.error("loginUser:", error);

    return res.status(500).json({
      message: "Server error during login.",
    });
  }
};

// =====================================
// CONDUCTOR LOGIN
// POST /auth/conductor/login
// =====================================
exports.loginConductor = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email?.trim() || !password) {
      return res.status(400).json({
        message: "Email and password are required.",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const result = await pool.query(
      `
      SELECT
        conductor_id,
        full_name,
        email,
        phone,
        password_hash,
        is_active
      FROM public.conductors
      WHERE LOWER(email) = $1
      LIMIT 1
      `,
      [normalizedEmail],
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        message: "Invalid email or password.",
      });
    }

    const conductor = result.rows[0];

    if (!conductor.is_active) {
      return res.status(403).json({
        message: "This conductor account is inactive.",
      });
    }

    const passwordMatch = await bcrypt.compare(
      password,
      conductor.password_hash,
    );

    if (!passwordMatch) {
      return res.status(401).json({
        message: "Invalid email or password.",
      });
    }

    const token = createToken({
      conductor_id: conductor.conductor_id,
      role: "CONDUCTOR",
    });

    delete conductor.password_hash;

    return res.status(200).json({
      message: "Conductor login successful.",
      token,
      role: "CONDUCTOR",
      conductor,
    });
  } catch (error) {
    console.error("loginConductor:", error);

    return res.status(500).json({
      message: "Server error during conductor login.",
    });
  }
};

// =====================================
// ADMIN LOGIN
// POST /auth/admin/login
// =====================================
exports.loginAdmin = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email?.trim() || !password) {
      return res.status(400).json({
        message: "Email and password are required.",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const result = await pool.query(
      `
      SELECT
        admin_id,
        full_name,
        email,
        password_hash
      FROM public.admins
      WHERE LOWER(email) = $1
      LIMIT 1
      `,
      [normalizedEmail],
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        message: "Invalid email or password.",
      });
    }

    const admin = result.rows[0];

    const passwordMatch = await bcrypt.compare(password, admin.password_hash);

    if (!passwordMatch) {
      return res.status(401).json({
        message: "Invalid email or password.",
      });
    }

    const token = createToken({
      admin_id: admin.admin_id,
      role: "ADMIN",
    });

    delete admin.password_hash;

    return res.status(200).json({
      message: "Admin login successful.",
      token,
      role: "ADMIN",
      admin,
    });
  } catch (error) {
    console.error("loginAdmin:", error);

    return res.status(500).json({
      message: "Server error during admin login.",
    });
  }
};
