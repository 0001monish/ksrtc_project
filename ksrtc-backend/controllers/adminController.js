const pool = require("../config/db");
const bcrypt = require("bcryptjs");

// =====================================================
// HELPERS
// =====================================================

// Safely convert optional values to integers.
const toIntOrNull = (value) => {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  const parsed = Number(value);
  return Number.isInteger(parsed) ? parsed : null;
};

// Safely convert optional decimal values.
const toNumberOrNull = (value) => {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  const parsed = Number(value);

  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
};

// Standard error response.
const handleError = (res, error, message = "Server error") => {
  console.error(message, error);
  return res.status(500).json({ message });
};

// Validate schedule data.
const validateSchedule = (item) => {
  return (
    item &&
    typeof item === "object" &&
    item.source?.trim() &&
    item.destination?.trim() &&
    item.departure_time &&
    item.arrival_time
  );
};

// =====================================================
// GET ALL BUSES
// GET /admin/buses
// =====================================================

exports.getAllBuses = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        b.bus_id,
        b.bus_number,
        b.bus_type,
        b.capacity,
        b.operator_name,
        b.is_active,

        s.schedule_id,
        s.departure_time,
        s.arrival_time,
        s.operating_days,
        s.frequency,
        s.is_active AS schedule_active,

        r.route_id,
        r.route_name,
        r.source,
        r.destination,
        r.distance_km,
        r.route_type

      FROM bus b

      LEFT JOIN schedule s
        ON s.bus_id = b.bus_id

      LEFT JOIN route r
        ON r.route_id = s.route_id

      ORDER BY b.bus_id, s.schedule_id;
    `);

    return res.status(200).json({
      buses: result.rows,
    });
  } catch (error) {
    return handleError(res, error, "Failed to fetch buses");
  }
};

// =====================================================
// CREATE BUS
// POST /admin/buses
// =====================================================

exports.createBus = async (req, res) => {
  const {
    bus_number,
    bus_type,
    capacity,
    operator_name,
    schedules = [],
  } = req.body;

  if (!bus_number?.trim()) {
    return res.status(400).json({
      message: "Bus number is required",
    });
  }

  if (!Number.isInteger(Number(capacity)) || Number(capacity) <= 0) {
    return res.status(400).json({
      message: "Valid bus capacity is required",
    });
  }

  if (!Array.isArray(schedules)) {
    return res.status(400).json({
      message: "Schedules must be an array",
    });
  }

  for (const item of schedules) {
    if (!validateSchedule(item)) {
      return res.status(400).json({
        message:
          "Each schedule requires source, destination, departure time and arrival time",
      });
    }
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 1. Create bus.
    const busResult = await client.query(
      `
      INSERT INTO bus (
        bus_number,
        bus_type,
        capacity,
        operator_name,
        is_active
      )
      VALUES ($1, $2, $3, $4, TRUE)
      RETURNING *;
      `,
      [
        bus_number.trim(),
        bus_type || "Ordinary",
        Number(capacity),
        operator_name || null,
      ],
    );

    const bus = busResult.rows[0];

    const createdSchedules = [];

    // 2. Create routes and schedules.
    for (const item of schedules) {
      const routeResult = await client.query(
        `
        INSERT INTO route (
          route_name,
          source,
          destination,
          distance_km,
          route_type
        )
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *;
        `,
        [
          item.route_name ||
            `${item.source.trim()} - ${item.destination.trim()}`,
          item.source.trim(),
          item.destination.trim(),
          toNumberOrNull(item.distance_km),
          item.route_type || null,
        ],
      );

      const route = routeResult.rows[0];

      const scheduleResult = await client.query(
        `
        INSERT INTO schedule (
          bus_id,
          route_id,
          departure_time,
          arrival_time,
          operating_days,
          frequency,
          is_active
        )
        VALUES ($1, $2, $3, $4, $5, $6, TRUE)
        RETURNING *;
        `,
        [
          bus.bus_id,
          route.route_id,
          item.departure_time,
          item.arrival_time,
          item.operating_days || null,
          item.frequency || null,
        ],
      );

      createdSchedules.push({
        ...scheduleResult.rows[0],
        route,
      });
    }

    await client.query("COMMIT");

    return res.status(201).json({
      message: "Bus created successfully",
      bus,
      schedules: createdSchedules,
    });
  } catch (error) {
    await client.query("ROLLBACK");

    console.error("createBus error:", error);

    return res.status(500).json({
      message: "Failed to create bus",
    });
  } finally {
    client.release();
  }
};

// =====================================================
// UPDATE BUS
// PUT /admin/buses/:id
// =====================================================

exports.updateBus = async (req, res) => {
  const busId = Number(req.params.id);

  if (!Number.isInteger(busId) || busId <= 0) {
    return res.status(400).json({
      message: "Invalid bus ID",
    });
  }

  const { bus_number, bus_type, capacity, operator_name, schedules } = req.body;

  if (schedules !== undefined && !Array.isArray(schedules)) {
    return res.status(400).json({
      message: "Schedules must be an array",
    });
  }

  if (
    capacity !== undefined &&
    capacity !== null &&
    (!Number.isInteger(Number(capacity)) || Number(capacity) <= 0)
  ) {
    return res.status(400).json({
      message: "Invalid bus capacity",
    });
  }

  for (const item of schedules || []) {
    if (!validateSchedule(item)) {
      return res.status(400).json({
        message:
          "Each schedule requires source, destination, departure time and arrival time",
      });
    }
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 1. Update bus details.
    const busResult = await client.query(
      `
      UPDATE bus
      SET
        bus_number = COALESCE($1, bus_number),
        bus_type = COALESCE($2, bus_type),
        capacity = COALESCE($3, capacity),
        operator_name = COALESCE($4, operator_name)
      WHERE bus_id = $5
      RETURNING *;
      `,
      [
        bus_number?.trim() || null,
        bus_type || null,
        capacity !== undefined ? Number(capacity) : null,
        operator_name !== undefined ? operator_name : null,
        busId,
      ],
    );

    if (busResult.rows.length === 0) {
      await client.query("ROLLBACK");

      return res.status(404).json({
        message: "Bus not found",
      });
    }

    const bus = busResult.rows[0];
    const updatedSchedules = [];

    // 2. Update existing schedules or insert new schedules.
    for (const item of schedules || []) {
      // -----------------------------------------------
      // UPDATE EXISTING SCHEDULE
      // -----------------------------------------------

      if (item.schedule_id) {
        const existingResult = await client.query(
          `
          SELECT schedule_id, route_id
          FROM schedule
          WHERE schedule_id = $1
            AND bus_id = $2
          FOR UPDATE;
          `,
          [item.schedule_id, busId],
        );

        if (existingResult.rows.length === 0) {
          throw new Error(
            `Schedule ${item.schedule_id} does not belong to this bus`,
          );
        }

        const existing = existingResult.rows[0];

        // Check whether this route is shared.
        const usageResult = await client.query(
          `
          SELECT COUNT(*)::int AS usage_count
          FROM schedule
          WHERE route_id = $1;
          `,
          [existing.route_id],
        );

        const isShared = usageResult.rows[0].usage_count > 1;

        let routeResult;

        if (isShared) {
          // Create a separate route to protect other schedules.
          routeResult = await client.query(
            `
            INSERT INTO route (
              route_name,
              source,
              destination,
              distance_km,
              route_type
            )
            VALUES ($1, $2, $3, $4, $5)
            RETURNING *;
            `,
            [
              item.route_name ||
                `${item.source.trim()} - ${item.destination.trim()}`,
              item.source.trim(),
              item.destination.trim(),
              toNumberOrNull(item.distance_km),
              item.route_type || null,
            ],
          );
        } else {
          // Update route directly when it is not shared.
          routeResult = await client.query(
            `
            UPDATE route
            SET
              route_name = $1,
              source = $2,
              destination = $3,
              distance_km = $4,
              route_type = $5
            WHERE route_id = $6
            RETURNING *;
            `,
            [
              item.route_name ||
                `${item.source.trim()} - ${item.destination.trim()}`,
              item.source.trim(),
              item.destination.trim(),
              toNumberOrNull(item.distance_km),
              item.route_type || null,
              existing.route_id,
            ],
          );
        }

        const route = routeResult.rows[0];

        // Update schedule.
        const scheduleResult = await client.query(
          `
          UPDATE schedule
          SET
            route_id = $1,
            departure_time = $2,
            arrival_time = $3,
            operating_days = $4,
            frequency = $5,
            is_active = COALESCE($6, is_active)
          WHERE schedule_id = $7
          RETURNING *;
          `,
          [
            route.route_id,
            item.departure_time,
            item.arrival_time,
            item.operating_days || null,
            item.frequency || null,
            typeof item.is_active === "boolean" ? item.is_active : null,
            item.schedule_id,
          ],
        );

        updatedSchedules.push({
          ...scheduleResult.rows[0],
          route,
        });
      } else {
        // -----------------------------------------------
        // CREATE NEW SCHEDULE
        // -----------------------------------------------

        const routeResult = await client.query(
          `
          INSERT INTO route (
            route_name,
            source,
            destination,
            distance_km,
            route_type
          )
          VALUES ($1, $2, $3, $4, $5)
          RETURNING *;
          `,
          [
            item.route_name ||
              `${item.source.trim()} - ${item.destination.trim()}`,
            item.source.trim(),
            item.destination.trim(),
            toNumberOrNull(item.distance_km),
            item.route_type || null,
          ],
        );

        const route = routeResult.rows[0];

        const scheduleResult = await client.query(
          `
          INSERT INTO schedule (
            bus_id,
            route_id,
            departure_time,
            arrival_time,
            operating_days,
            frequency,
            is_active
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7)
          RETURNING *;
          `,
          [
            busId,
            route.route_id,
            item.departure_time,
            item.arrival_time,
            item.operating_days || null,
            item.frequency || null,
            typeof item.is_active === "boolean" ? item.is_active : true,
          ],
        );

        updatedSchedules.push({
          ...scheduleResult.rows[0],
          route,
        });
      }
    }

    await client.query("COMMIT");

    return res.status(200).json({
      message: "Bus updated successfully",
      bus,
      schedules: updatedSchedules,
    });
  } catch (error) {
    await client.query("ROLLBACK");

    console.error("updateBus error:", error);

    return res.status(500).json({
      message: "Failed to update bus",
    });
  } finally {
    client.release();
  }
};

// =====================================================
// SET BUS ACTIVE / INACTIVE
// PATCH /admin/buses/:id/active
// =====================================================

exports.setBusActive = async (req, res) => {
  const busId = Number(req.params.id);
  const { is_active } = req.body;

  if (!Number.isInteger(busId) || busId <= 0) {
    return res.status(400).json({
      message: "Invalid bus ID",
    });
  }

  if (typeof is_active !== "boolean") {
    return res.status(400).json({
      message: "is_active must be true or false",
    });
  }

  try {
    const result = await pool.query(
      `
      UPDATE bus
      SET is_active = $1
      WHERE bus_id = $2
      RETURNING *;
      `,
      [is_active, busId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "Bus not found",
      });
    }

    return res.json({
      message: "Bus status updated successfully",
      bus: result.rows[0],
    });
  } catch (error) {
    return handleError(res, error, "Failed to update bus status");
  }
};

// =====================================================
// GET ROUTES
// GET /admin/routes
// =====================================================

exports.getRoutes = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT *
      FROM route
      ORDER BY route_id;
    `);

    return res.json({
      routes: result.rows,
    });
  } catch (error) {
    return handleError(res, error, "Failed to fetch routes");
  }
};

// =====================================================
// CREATE ROUTE
// POST /admin/routes
// =====================================================

exports.createRoute = async (req, res) => {
  const { source, destination, distance_km, route_name, route_type } = req.body;

  if (!source?.trim() || !destination?.trim()) {
    return res.status(400).json({
      message: "Source and destination are required",
    });
  }

  try {
    const result = await pool.query(
      `
      INSERT INTO route (
        source,
        destination,
        distance_km,
        route_name,
        route_type
      )
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *;
      `,
      [
        source.trim(),
        destination.trim(),
        toNumberOrNull(distance_km),
        route_name || `${source.trim()} - ${destination.trim()}`,
        route_type || null,
      ],
    );

    return res.status(201).json({
      message: "Route created successfully",
      route: result.rows[0],
    });
  } catch (error) {
    return handleError(res, error, "Failed to create route");
  }
};

// =====================================================
// UPDATE ROUTE
// PUT /admin/routes/:id
// =====================================================

exports.updateRoute = async (req, res) => {
  const routeId = Number(req.params.id);

  if (!Number.isInteger(routeId) || routeId <= 0) {
    return res.status(400).json({
      message: "Invalid route ID",
    });
  }

  const { source, destination, distance_km, route_name, route_type } = req.body;

  try {
    const result = await pool.query(
      `
      UPDATE route
      SET
        source = COALESCE($1, source),
        destination = COALESCE($2, destination),
        distance_km = COALESCE($3, distance_km),
        route_name = COALESCE($4, route_name),
        route_type = COALESCE($5, route_type)
      WHERE route_id = $6
      RETURNING *;
      `,
      [
        source?.trim() || null,
        destination?.trim() || null,
        toNumberOrNull(distance_km),
        route_name || null,
        route_type || null,
        routeId,
      ],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "Route not found",
      });
    }

    return res.json({
      message: "Route updated successfully",
      route: result.rows[0],
    });
  } catch (error) {
    return handleError(res, error, "Failed to update route");
  }
};

// =====================================================
// DELETE ROUTE
// DELETE /admin/routes/:id
// =====================================================

exports.deleteRoute = async (req, res) => {
  const routeId = Number(req.params.id);

  if (!Number.isInteger(routeId) || routeId <= 0) {
    return res.status(400).json({
      message: "Invalid route ID",
    });
  }

  try {
    const scheduleCheck = await pool.query(
      `
      SELECT 1
      FROM schedule
      WHERE route_id = $1
      LIMIT 1;
      `,
      [routeId],
    );

    if (scheduleCheck.rows.length > 0) {
      return res.status(409).json({
        message: "Cannot delete route because it is assigned to a schedule",
      });
    }

    const result = await pool.query(
      `
      DELETE FROM route
      WHERE route_id = $1
      RETURNING *;
      `,
      [routeId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "Route not found",
      });
    }

    return res.json({
      message: "Route deleted successfully",
    });
  } catch (error) {
    return handleError(res, error, "Failed to delete route");
  }
};

// =====================================================
// GET SCHEDULES
// GET /admin/schedule
// =====================================================

exports.getSchedules = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        s.schedule_id,
        s.bus_id,
        s.route_id,
        s.departure_time,
        s.arrival_time,
        s.operating_days,
        s.frequency,
        s.is_active AS schedule_active,

        b.bus_number,
        b.bus_type,
        b.capacity,
        b.is_active AS bus_active,

        r.route_name,
        r.source,
        r.destination,
        r.distance_km,
        r.route_type

      FROM schedule s

      JOIN bus b
        ON b.bus_id = s.bus_id

      JOIN route r
        ON r.route_id = s.route_id

      ORDER BY s.schedule_id;
    `);

    return res.status(200).json({
      schedules: result.rows,
    });
  } catch (error) {
    return handleError(res, error, "Failed to fetch schedules");
  }
};

// =====================================================
// CREATE CONDUCTOR
// POST /admin/conductors
// =====================================================

exports.createConductor = async (req, res) => {
  try {
    const { full_name, email, phone, password } = req.body;

    if (!full_name?.trim() || !email?.trim() || !password) {
      return res.status(400).json({
        message: "Full name, email, and password are required.",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        message: "Password must contain at least 6 characters.",
      });
    }

    const normalizedName = full_name.trim();
    const normalizedEmail = email.trim().toLowerCase();
    const normalizedPhone = phone?.trim() || null;

    // Check duplicate email.
    const existing = await pool.query(
      `
      SELECT conductor_id
      FROM conductors
      WHERE LOWER(email) = $1
      LIMIT 1;
      `,
      [normalizedEmail],
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({
        message: "A conductor with this email already exists.",
      });
    }

    // Hash password.
    const passwordHash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `
      INSERT INTO conductors (
        full_name,
        email,
        phone,
        password_hash,
        is_active
      )
      VALUES ($1, $2, $3, $4, TRUE)
      RETURNING
        conductor_id,
        full_name,
        email,
        phone,
        is_active;
      `,
      [normalizedName, normalizedEmail, normalizedPhone, passwordHash],
    );

    return res.status(201).json({
      message: "Conductor account created successfully.",
      conductor: result.rows[0],
    });
  } catch (error) {
    console.error("createConductor:", error);

    if (error.code === "23505") {
      return res.status(409).json({
        message: "A conductor with these details already exists.",
      });
    }

    return res.status(500).json({
      message: "Failed to create conductor account.",
    });
  }
};
