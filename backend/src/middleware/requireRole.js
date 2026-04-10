const { AppError } = require("../common/errors/AppError");

function requireRole(...allowedRoles) {
  return (req, _res, next) => {
    const role = req.user?.role;

    if (!role || !allowedRoles.includes(role)) {
      next(
        new AppError(
          403,
          "FORBIDDEN",
          "You are not allowed to access this resource.",
        ),
      );
      return;
    }

    next();
  };
}

module.exports = { requireRole };
