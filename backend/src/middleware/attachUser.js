const { AppError } = require("../common/errors/AppError");
const { UserModel } = require("../modules/user/user.model");

async function attachUser(req, _res, next) {
  const firebaseUid = req.auth?.firebaseUid;

  if (!firebaseUid) {
    next(
      new AppError(401, "UNAUTHORIZED", "Missing authenticated user context."),
    );
    return;
  }

  const user = await UserModel.findOne({ firebaseUid });
  if (!user) {
    next(new AppError(404, "USER_NOT_FOUND", "User record does not exist."));
    return;
  }

  req.user = user;
  next();
}

module.exports = { attachUser };
