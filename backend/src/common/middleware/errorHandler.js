const { AppError } = require("../errors/AppError");

function notFoundHandler(req, _res, next) {
  next(
    new AppError(
      404,
      "NOT_FOUND",
      `Route not found: ${req.method} ${req.originalUrl}`,
    ),
  );
}

function errorHandler(error, _req, res, _next) {
  if (error instanceof AppError) {
    res.status(error.statusCode).json({
      success: false,
      error: {
        code: error.code,
        message: error.message,
        details: error.details,
      },
    });
    return;
  }

  res.status(500).json({
    success: false,
    error: {
      code: "INTERNAL_SERVER_ERROR",
      message: "Unexpected server error.",
      details: [],
    },
  });
}

module.exports = { notFoundHandler, errorHandler };
