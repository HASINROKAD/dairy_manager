const { AppError } = require("../common/errors/AppError");
const { UserModel } = require("../modules/user/user.model");

function checkRole(requiredRole) {
  return async (req, _res, next) => {
    try {
      const tokenRole = req.auth?.token?.role;
      let dbRole = req.user?.role;

      if (!dbRole && req.auth?.firebaseUid) {
        const user = await UserModel.findOne({
          firebaseUid: req.auth.firebaseUid,
        }).select("role");

        dbRole = user?.role;
      }

      const effectiveRole = tokenRole || dbRole;

      if (!effectiveRole) {
        next(
          new AppError(
            403,
            "FORBIDDEN",
            "Role is not assigned for this user. Complete profile setup or contact admin.",
          ),
        );
        return;
      }

      if (effectiveRole !== requiredRole) {
        next(
          new AppError(
            403,
            "FORBIDDEN",
            `Only ${requiredRole} role can access this resource.`,
          ),
        );
        return;
      }

      next();
    } catch (error) {
      next(error);
    }
  };
}

module.exports = { checkRole };
