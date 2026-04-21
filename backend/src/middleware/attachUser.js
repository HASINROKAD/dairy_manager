const { AppError } = require("../common/errors/AppError");
const { UserModel } = require("../modules/user/user.model");
const { env } = require("../config/env");

const attachedUserCache = new Map();

function getCachedUser(firebaseUid) {
  const ttlMs = Number(env.attachUserCacheTtlMs) || 0;
  if (ttlMs <= 0) {
    return null;
  }

  const key = String(firebaseUid || "").trim();
  if (!key) {
    return null;
  }

  const cached = attachedUserCache.get(key);
  if (!cached) {
    return null;
  }

  if (cached.expiresAt <= Date.now()) {
    attachedUserCache.delete(key);
    return null;
  }

  return cached.user;
}

function setCachedUser(firebaseUid, user) {
  const ttlMs = Number(env.attachUserCacheTtlMs) || 0;
  if (ttlMs <= 0) {
    return;
  }

  const key = String(firebaseUid || "").trim();
  if (!key) {
    return;
  }

  attachedUserCache.set(key, {
    user,
    expiresAt: Date.now() + ttlMs,
  });
}

async function attachUser(req, _res, next) {
  const firebaseUid = req.auth?.firebaseUid;

  if (!firebaseUid) {
    next(
      new AppError(401, "UNAUTHORIZED", "Missing authenticated user context."),
    );
    return;
  }

  const cachedUser = getCachedUser(firebaseUid);
  if (cachedUser) {
    req.user = cachedUser;
    next();
    return;
  }

  const user = await UserModel.findOne({ firebaseUid })
    .select(
      "_id firebaseUid email mobileNumber name role activeSellerUserId activeSellerLinkedAt profileCompleted isActive",
    )
    .lean();

  if (!user) {
    next(new AppError(404, "USER_NOT_FOUND", "User record does not exist."));
    return;
  }

  req.user = user;
  setCachedUser(firebaseUid, user);
  next();
}

module.exports = { attachUser };
