const pool = require("../config/db");
const socketService = require("../services/socketService");
// ============================================================
// GET CONDUCTOR'S ACTIVE SESSION
// GET /conductor/active-session
// ============================================================
exports.checkActiveSession = async (req, res) => {
  try {
    const conductorId = req.user.conductor_id;

    if (!conductorId) {
      return res.status(400).json({
        message: "Conductor ID is missing from the authenticated user.",
      });
    }

    const result = await pool.query(
      `
      SELECT
        cs.session_id,
        cs.conductor_id,
        cs.schedule_id,
        cs.login_time,
        cs.is_active,
        s.bus_id,
        s.route_id,
        s.departure_time,
        s.arrival_time,
        b.bus_number,
        b.bus_type,
        r.route_name,
        r.source,
        r.destination
      FROM public.conductor_sessions cs
      JOIN public.schedule s ON s.schedule_id = cs.schedule_id
      JOIN public.bus b ON b.bus_id = s.bus_id
      JOIN public.route r ON r.route_id = s.route_id
      WHERE cs.conductor_id = $1
        AND cs.is_active = TRUE
      ORDER BY cs.login_time DESC
      LIMIT 1
      `,
      [conductorId],
    );

    if (!result.rows.length) {
      return res.status(200).json({
        hasActiveSession: false,
        session: null,
        message: "No active bus session.",
      });
    }

    return res.status(200).json({
      hasActiveSession: true,
      session: result.rows[0],
    });
  } catch (error) {
    console.error("checkActiveSession:", error);

    return res.status(500).json({
      message: "Could not check active conductor session.",
      error: error.message,
    });
  }
};

// ============================================================
// GET SCHEDULE BY BUS NUMBER
// GET /conductor/schedule/:bus_number
// ============================================================
exports.getScheduleByBusNumber = async (req, res) => {
  try {
    const busNumber = String(req.params.bus_number || "").trim();

    if (!busNumber) {
      return res.status(400).json({
        message: "Bus number is required.",
      });
    }

    const result = await pool.query(
      `
      SELECT
        s.schedule_id,
        s.bus_id,
        s.route_id,
        s.departure_time,
        s.arrival_time,
        s.operating_days,
        s.frequency,
        b.bus_number,
        b.bus_type,
        b.capacity,
        r.route_name,
        r.source,
        r.destination,
        r.distance_km
      FROM public.schedule s
      JOIN public.bus b ON b.bus_id = s.bus_id
      JOIN public.route r ON r.route_id = s.route_id
      WHERE UPPER(TRIM(b.bus_number)) = UPPER(TRIM($1))
        AND s.is_active = TRUE
        AND b.is_active = TRUE
      ORDER BY s.departure_time
      `,
      [busNumber],
    );

    if (!result.rows.length) {
      return res.status(404).json({
        message: "No active schedule found for this bus.",
      });
    }

    return res.status(200).json({
      bus_number: busNumber,
      schedules: result.rows,
    });
  } catch (error) {
    console.error("getScheduleByBusNumber:", error);

    return res.status(500).json({
      message: "Could not retrieve bus schedule.",
      error: error.message,
    });
  }
};

// ============================================================
// CONDUCTOR STARTS A BUS SESSION
// POST /conductor/login-bus
// ============================================================
exports.loginToBus = async (req, res) => {
  const client = await pool.connect();
  let transactionStarted = false;

  try {
    const conductorId = req.user.conductor_id;
    const busNumber = String(req.body.bus_number || "").trim();

    if (!conductorId) {
      return res.status(400).json({
        message: "Conductor ID is missing from the authenticated user.",
      });
    }

    if (!busNumber) {
      return res.status(400).json({
        message: "Bus number is required.",
      });
    }

    await client.query("BEGIN");
    transactionStarted = true;

    // Diagnostic: confirm which database the backend is connected to.
    const dbCheck = await client.query(`
      SELECT
        current_database() AS database_name,
        current_schema() AS current_schema,
        current_setting('search_path') AS search_path,
        (SELECT COUNT(*) FROM public.bus) AS buses_count,
        (SELECT COUNT(*) FROM public.schedule) AS schedules_count,
        (SELECT COUNT(*) FROM public.route) AS routes_count
    `);

    console.log("BACKEND DATABASE CHECK:", dbCheck.rows[0]);
    console.log("LOGIN BUS DEBUG:", {
      busNumber,
      conductorId,
    });

    // Diagnostic: bus and schedule, even if the route is missing.
    const diagnosticResult = await client.query(
      `
      SELECT
        s.schedule_id,
        s.bus_id,
        s.route_id,
        s.is_active AS schedule_active,
        b.bus_number,
        b.is_active AS bus_active,
        r.route_id AS matched_route_id,
        r.route_name
      FROM public.schedule s
      JOIN public.bus b ON b.bus_id = s.bus_id
      LEFT JOIN public.route r ON r.route_id = s.route_id
      WHERE UPPER(TRIM(b.bus_number)) = UPPER(TRIM($1))
      `,
      [busNumber],
    );

    console.log("BUS/SCHEDULE DIAGNOSTIC:", diagnosticResult.rows);

    // Find an active schedule with a valid route.
    const scheduleResult = await client.query(
      `
      SELECT
        s.schedule_id,
        s.bus_id,
        s.route_id,
        s.departure_time,
        s.arrival_time,
        b.bus_number,
        b.bus_type,
        b.capacity,
        r.route_name,
        r.source,
        r.destination,
        r.distance_km
      FROM public.schedule s
      JOIN public.bus b ON b.bus_id = s.bus_id
      JOIN public.route r ON r.route_id = s.route_id
      WHERE UPPER(TRIM(b.bus_number)) = UPPER(TRIM($1))
        AND s.is_active = TRUE
        AND b.is_active = TRUE
      ORDER BY s.departure_time
      LIMIT 1
      FOR UPDATE OF s
      `,
      [busNumber],
    );

    console.log("ACTIVE SCHEDULE QUERY RESULT:", scheduleResult.rows);

    if (!scheduleResult.rows.length) {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(404).json({
        message: "No active schedule found for this bus.",
        debug: {
          database: dbCheck.rows[0],
          busScheduleRows: diagnosticResult.rows,
        },
      });
    }

    const schedule = scheduleResult.rows[0];

    // Check whether this conductor already has an active session.
    const conductorSessionResult = await client.query(
      `
      SELECT session_id
      FROM public.conductor_sessions
      WHERE conductor_id = $1
        AND is_active = TRUE
      LIMIT 1
      FOR UPDATE
      `,
      [conductorId],
    );

    if (conductorSessionResult.rows.length) {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(409).json({
        message: "You already have an active bus session. Log out first.",
      });
    }

    // Check whether another conductor is using this schedule.
    const activeSessionResult = await client.query(
      `
      SELECT session_id
      FROM public.conductor_sessions
      WHERE schedule_id = $1
        AND is_active = TRUE
      LIMIT 1
      FOR UPDATE
      `,
      [schedule.schedule_id],
    );

    if (activeSessionResult.rows.length) {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(409).json({
        message: "This bus is already active with another conductor.",
      });
    }

    // Create the conductor's active session.
    const sessionResult = await client.query(
      `
      INSERT INTO public.conductor_sessions
        (conductor_id, schedule_id, login_time, logout_time, is_active)
      VALUES ($1, $2, NOW(), NULL, TRUE)
      RETURNING
        session_id,
        conductor_id,
        schedule_id,
        login_time,
        is_active
      `,
      [conductorId, schedule.schedule_id],
    );

    await client.query("COMMIT");
    transactionStarted = false;

    return res.status(201).json({
      message: "Bus session started.",
      session: {
        ...sessionResult.rows[0],
        ...schedule,
      },
    });
  } catch (error) {
    if (transactionStarted) {
      try {
        await client.query("ROLLBACK");
      } catch (rollbackError) {
        console.error("loginToBus rollback:", rollbackError);
      }
    }

    console.error("loginToBus:", error);

    return res.status(500).json({
      message: "Could not start bus session.",
      error: error.message,
    });
  } finally {
    client.release();
  }
};

// ============================================================
// ============================================================
// CONDUCTOR LOGS OUT OF BUS SESSION
// POST /conductor/logout-bus/:session_id
// ============================================================

exports.logoutBus = async (req, res) => {
  try {
    const conductorId = req.user.conductor_id;
    const sessionId = Number(req.params.session_id);

    if (!conductorId) {
      return res.status(400).json({
        message: "Conductor ID is missing from the authenticated user.",
      });
    }

    if (!Number.isInteger(sessionId) || sessionId <= 0) {
      return res.status(400).json({
        message: "Valid session ID is required.",
      });
    }

    console.log("LOGOUT BUS REQUEST:", {
      conductorId,
      sessionId,
    });

    // End this active session, but only if it belongs to this conductor.
    const result = await pool.query(
      `
      UPDATE public.conductor_sessions
      SET
        logout_time = NOW(),
        is_active = FALSE
      WHERE session_id = $1
        AND conductor_id = $2
        AND is_active = TRUE
      RETURNING
        session_id,
        conductor_id,
        schedule_id,
        login_time,
        logout_time,
        is_active
      `,
      [sessionId, conductorId],
    );

    // Session was successfully ended.
    if (result.rows.length > 0) {
      console.log("BUS SESSION ENDED:", result.rows[0]);

      return res.status(200).json({
        success: true,
        message: "Bus session ended successfully.",
        session: result.rows[0],
      });
    }

    // Check whether this session exists and belongs to this conductor.
    const existingSession = await pool.query(
      `
      SELECT
        session_id,
        conductor_id,
        schedule_id,
        login_time,
        logout_time,
        is_active
      FROM public.conductor_sessions
      WHERE session_id = $1
        AND conductor_id = $2
      LIMIT 1
      `,
      [sessionId, conductorId],
    );

    // The session was already ended.
    if (
      existingSession.rows.length > 0 &&
      existingSession.rows[0].is_active === false
    ) {
      console.log("BUS SESSION WAS ALREADY ENDED:", existingSession.rows[0]);

      return res.status(200).json({
        success: true,
        message: "Bus session was already ended.",
        session: existingSession.rows[0],
      });
    }

    // Session does not exist or does not belong to this conductor.
    return res.status(404).json({
      success: false,
      message: "Session not found for this conductor.",
    });
  } catch (error) {
    console.error("logoutBus error:", error);

    return res.status(500).json({
      success: false,
      message: "Could not end bus session.",
      error: error.message,
    });
  }
};

// ============================================================
// UPDATE BUS STATUS / CURRENT STOP / REMARKS
// PUT /conductor/update-status
// ============================================================

exports.updateBusStatus = async (req, res) => {
  try {
    const conductorId = req.user.conductor_id;

    const status = req.body.status ?? req.body.current_status;
    const current_stop = req.body.current_stop?.trim() || null;
    const remarks = req.body.remarks?.trim() || null;

    const allowedStatuses = [
      "ON_TIME",
      "DELAYED",
      "ARRIVED",
      "DEPARTED",
      "CANCELLED",
      "COMPLETED",
    ];

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({
        message: "Invalid bus status.",
        allowedStatuses,
      });
    }

    if (!conductorId) {
      return res.status(400).json({
        message: "Conductor ID is missing.",
      });
    }

    const sessionResult = await pool.query(
      `SELECT session_id, schedule_id
       FROM public.conductor_sessions
       WHERE conductor_id = $1
       AND is_active = TRUE
       ORDER BY login_time DESC
       LIMIT 1`,
      [conductorId],
    );

    if (!sessionResult.rows.length) {
      return res.status(403).json({
        message: "You must log in to a bus first.",
      });
    }

    const scheduleId = sessionResult.rows[0].schedule_id;

    console.log("BUS STATUS UPDATE:", {
      conductorId,
      scheduleId,
      status,
      current_stop,
      remarks,
    });

    // Save status in PostgreSQL.
    const result = await pool.query(
      `INSERT INTO public.bus_status
       (schedule_id, bus_date, current_status,
        current_stop, remarks, updated_at)
       VALUES ($1, CURRENT_DATE, $2, $3, $4, NOW())
       RETURNING *`,
      [scheduleId, status, current_stop, remarks],
    );

    const payload = result.rows[0];

    console.log("BUS STATUS SAVED:", payload);

    // Broadcast separately so socket errors don't undo the API success.
    try {
      socketService.emitToSchedule(scheduleId, "statusUpdated", payload);

      socketService.emitToAll("statusUpdated", payload);
    } catch (socketError) {
      console.error("STATUS SOCKET ERROR:", socketError);
    }

    return res.status(200).json({
      message: "Bus status updated successfully.",
      status: payload,
    });
  } catch (error) {
    console.error("updateBusStatus:", error);

    return res.status(500).json({
      message: "Could not update bus status.",
      error: error.message,
    });
  }
};

// ============================================================
// UPDATE BUS LOCATION
// POST /conductor/update-location
// ============================================================

exports.updateBusLocation = async (req, res) => {
  try {
    const conductorId = req.user.conductor_id;
    const { latitude, longitude } = req.body;

    // 1. Check whether Flutter is sending GPS coordinates
    console.log("GPS REQUEST RECEIVED:", {
      conductorId,
      latitude,
      longitude,
    });

    // Validate coordinates
    if (
      latitude === undefined ||
      longitude === undefined ||
      isNaN(Number(latitude)) ||
      isNaN(Number(longitude)) ||
      Number(latitude) < -90 ||
      Number(latitude) > 90 ||
      Number(longitude) < -180 ||
      Number(longitude) > 180
    ) {
      return res.status(400).json({
        message: "Valid latitude and longitude are required",
      });
    }

    // 2. Find the conductor's active bus session
    const sessionResult = await pool.query(
      `SELECT cs.session_id, cs.schedule_id
       FROM public.conductor_sessions cs
       WHERE cs.conductor_id = $1
       AND cs.is_active = TRUE
       ORDER BY cs.login_time DESC
       LIMIT 1`,
      [conductorId],
    );

    console.log("GPS ACTIVE SESSION:", sessionResult.rows);

    if (!sessionResult.rows.length) {
      return res.status(404).json({
        message: "No active bus session found",
      });
    }

    const { schedule_id } = sessionResult.rows[0];

    // 3. Save GPS location
    const result = await pool.query(
      `INSERT INTO public.live_bus_location
       (schedule_id, latitude, longitude, updated_at)
       VALUES ($1, $2, $3, NOW())
       RETURNING schedule_id, latitude, longitude, updated_at`,
      [schedule_id, Number(latitude), Number(longitude)],
    );

    const locationPayload = result.rows[0];

    console.log("GPS LOCATION SAVED:", locationPayload);

    // 4. Notify passengers through Socket.IO
    socketService.emitToSchedule(
      schedule_id,
      "locationUpdated",
      locationPayload,
    );

    return res.status(200).json({
      message: "Location updated successfully",
      location: locationPayload,
    });
  } catch (error) {
    console.error("Update bus location error:", error);

    return res.status(500).json({
      message: "Failed to update bus location",
      error: error.message,
    });
  }
};
