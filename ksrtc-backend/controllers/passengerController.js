const pool = require("../config/db");

// =====================================
// SEARCH BUSES
// GET /search?source=Virajpet&destination=Mysore
// =====================================
exports.searchBuses = async (req, res) => {
  try {
    let { source, destination } = req.query;

    if (!source || !destination) {
      return res.status(400).json({
        message: "Source and destination are required.",
      });
    }

    source = source.trim();
    destination = destination.trim();

    const result = await pool.query(
      `
      SELECT
        s.schedule_id,
        b.bus_id,
        b.bus_number,
        b.bus_type,
        r.route_id,
        r.route_name,
        r.route_type,
        r.source,
        r.destination,

        (
          SELECT COUNT(*)
          FROM route_stops rs
          WHERE rs.route_id = r.route_id
        ) AS total_stops,

        TO_CHAR(s.departure_time, 'HH12:MI AM') AS departure_time,
        TO_CHAR(s.arrival_time, 'HH12:MI AM') AS arrival_time,

        COALESCE(bs.current_status, 'ON_TIME') AS current_status,
        COALESCE(bs.current_stop, 'Not updated') AS current_stop,
        COALESCE(bs.remarks, '') AS remarks

      FROM schedule s
      JOIN bus b ON b.bus_id = s.bus_id
      JOIN route r ON r.route_id = s.route_id

      LEFT JOIN LATERAL (
        SELECT current_status, current_stop, remarks
        FROM bus_status
        WHERE schedule_id = s.schedule_id
        ORDER BY updated_at DESC
        LIMIT 1
      ) bs ON TRUE

      WHERE
        LOWER(TRIM(r.source)) LIKE LOWER($1)
        AND LOWER(TRIM(r.destination)) LIKE LOWER($2)
        AND COALESCE(b.is_active, TRUE) = TRUE

      ORDER BY s.departure_time;
      `,
      [`%${source}%`, `%${destination}%`],
    );

    return res.json({
      buses: result.rows,
    });
  } catch (error) {
    console.error("searchBuses error:", error);

    return res.status(500).json({
      message: "Failed to search buses.",
    });
  }
};

// =====================================
// GET ROUTE DETAILS AND STOPS
// GET /route/:id
// =====================================
exports.getRouteDetails = async (req, res) => {
  try {
    const routeId = Number(req.params.id);

    if (!Number.isInteger(routeId) || routeId <= 0) {
      return res.status(400).json({
        message: "Invalid route ID.",
      });
    }

    const routeResult = await pool.query(
      `
      SELECT
        route_id,
        route_name,
        route_type,
        source,
        destination,
        distance_km
      FROM route
      WHERE route_id = $1;
      `,
      [routeId],
    );

    if (routeResult.rows.length === 0) {
      return res.status(404).json({
        message: "Route not found.",
      });
    }

    const stopsResult = await pool.query(
      `
      SELECT
        rs.route_stop_id,
        rs.stop_sequence,
        rs.stop_type,
        rs.halt_duration_minutes,
        st.stop_id,
        st.stop_name,
        st.city,
        st.state
      FROM route_stops rs
      JOIN stops st ON st.stop_id = rs.stop_id
      WHERE rs.route_id = $1
      ORDER BY rs.stop_sequence ASC;
      `,
      [routeId],
    );

    return res.json({
      route: routeResult.rows[0],
      stops: stopsResult.rows,
    });
  } catch (error) {
    console.error("getRouteDetails error:", error);

    return res.status(500).json({
      message: "Failed to fetch route details.",
    });
  }
};

// =====================================
// GET LIVE BUS LOCATION
// GET /live-location/bus/:bus_number
// =====================================
exports.getBusLocationByBusNumber = async (req, res) => {
  try {
    const busNumber = req.params.bus_number?.trim();

    if (!busNumber) {
      return res.status(400).json({
        message: "Bus number is required.",
      });
    }

    const result = await pool.query(
      `
      SELECT
        s.schedule_id,
        b.bus_id,
        b.bus_number,
        r.route_id,
        r.route_name,
        r.source,
        r.destination,
        loc.latitude,
        loc.longitude,
        loc.updated_at,

        COALESCE(bs.current_status, 'ON_TIME') AS current_status,
        COALESCE(bs.current_stop, 'Not updated') AS current_stop,
        COALESCE(bs.remarks, '') AS remarks

      FROM schedule s
      JOIN bus b ON b.bus_id = s.bus_id
      JOIN route r ON r.route_id = s.route_id

      LEFT JOIN LATERAL (
        SELECT latitude, longitude, updated_at
        FROM live_bus_location
        WHERE schedule_id = s.schedule_id
        ORDER BY updated_at DESC
        LIMIT 1
      ) loc ON TRUE

      LEFT JOIN LATERAL (
        SELECT current_status, current_stop, remarks
        FROM bus_status
        WHERE schedule_id = s.schedule_id
        ORDER BY updated_at DESC
        LIMIT 1
      ) bs ON TRUE

      WHERE UPPER(TRIM(b.bus_number)) = UPPER($1)
      ORDER BY s.departure_time
      LIMIT 1;
      `,
      [busNumber],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "Bus not found.",
      });
    }

    return res.json({
      location: result.rows[0],
    });
  } catch (error) {
    console.error("getBusLocationByBusNumber error:", error);

    return res.status(500).json({
      message: "Failed to fetch bus location.",
    });
  }
};
