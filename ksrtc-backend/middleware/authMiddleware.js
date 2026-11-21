const jwt = require("jsonwebtoken");

exports.verifyToken = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({
      message: "Access denied. No token provided.",
    });
  }

  const token = authHeader.substring(7).trim();

  if (!token) {
    return res.status(401).json({
      message: "Access denied. No token provided.",
    });
  }

  if (!process.env.JWT_SECRET) {
    console.error("JWT_SECRET is missing from backend environment.");

    return res.status(500).json({
      message: "Server authentication configuration error.",
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    req.user = decoded;
    next();
  } catch (error) {
    console.error("JWT verification failed:", error.name);

    return res.status(401).json({
      message: "Invalid or expired token.",
    });
  }
};

exports.allowRoles = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        message: "Access denied. Unauthorized role.",
      });
    }

    next();
  };
};
