const { initializeFirebase } = require("../config/firebase");
const { AppError } = require("../common/errors/AppError");
const { env } = require("../config/env");

const tokenVerificationCache = new Map();

function getTokenCacheTtlMs() {
  const ttlMs = Number(env.authVerifyCacheTtlMs) || 0;
  if (ttlMs <= 0) {
    return 0;
  }

  // Keep revocation checks strict by default.
  if (env.authCheckTokenRevoked) {
    return 0;
  }

  return ttlMs;
}

function getCachedDecodedToken(cacheKey) {
  const cached = tokenVerificationCache.get(cacheKey);
  if (!cached) {
    return null;
  }

  if (cached.expiresAt <= Date.now()) {
    tokenVerificationCache.delete(cacheKey);
    return null;
  }

  return cached.decoded;
}

function setCachedDecodedToken(cacheKey, decoded) {
  const cacheTtlMs = getTokenCacheTtlMs();
  if (cacheTtlMs <= 0) {
    return;
  }

  const tokenExpMs = Number(decoded?.exp) * 1000;
  const now = Date.now();
  const maxLifetimeMs = Number.isFinite(tokenExpMs)
    ? Math.max(0, tokenExpMs - now)
    : cacheTtlMs;
  const effectiveTtlMs = Math.min(cacheTtlMs, maxLifetimeMs);

  if (effectiveTtlMs <= 0) {
    return;
  }

  tokenVerificationCache.set(cacheKey, {
    decoded,
    expiresAt: now + effectiveTtlMs,
  });
}

function parseBearerToken(headerValue = "") {
  if (!headerValue.startsWith("Bearer ")) {
    return null;
  }

  return headerValue.slice("Bearer ".length).trim();
}

async function authenticate(req, _res, next) {
  const token = parseBearerToken(req.headers.authorization);

  if (!token) {
    next(
      new AppError(
        401,
        "UNAUTHORIZED",
        "Missing or invalid Authorization header.",
      ),
    );
    return;
  }

  try {
    const cacheKey = `${env.authCheckTokenRevoked ? "revoked" : "normal"}:${token}`;
    let decoded = getCachedDecodedToken(cacheKey);

    if (!decoded) {
      const admin = initializeFirebase();
      decoded = await admin
        .auth()
        .verifyIdToken(token, env.authCheckTokenRevoked);
      setCachedDecodedToken(cacheKey, decoded);
    }

    req.auth = {
      firebaseUid: decoded.uid,
      email: decoded.email || "",
      phoneNumber: decoded.phone_number || "",
      token: decoded,
    };

    next();
  } catch (_error) {
    next(
      new AppError(401, "UNAUTHORIZED", "Invalid or expired Firebase token."),
    );
  }
}

module.exports = { authenticate };
