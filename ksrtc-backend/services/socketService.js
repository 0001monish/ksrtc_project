let io;

exports.initializeSocket = (socketServer) => {
  io = socketServer;

  io.on("connection", (socket) => {
    console.log("Socket connected:", socket.id);

    socket.on("joinSchedule", (scheduleId) => {
      if (!scheduleId) return;

      socket.join(`schedule:${scheduleId}`);
      console.log(`Socket ${socket.id} joined schedule:${scheduleId}`);
    });

    socket.on("leaveSchedule", (scheduleId) => {
      if (!scheduleId) return;

      socket.leave(`schedule:${scheduleId}`);
      console.log(`Socket ${socket.id} left schedule:${scheduleId}`);
    });

    socket.on("disconnect", () => {
      console.log("Socket disconnected:", socket.id);
    });
  });

  return io;
};

exports.getIO = () => io;

exports.emitToSchedule = (scheduleId, event, payload) => {
  if (!io || !scheduleId) return;

  io.to(`schedule:${scheduleId}`).emit(event, payload);
};

exports.emitToAll = (event, payload) => {
  if (!io) return;

  io.emit(event, payload);
};
