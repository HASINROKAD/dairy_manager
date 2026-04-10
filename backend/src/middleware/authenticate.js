const { initializeFirebase } = require("../config/firebase");
const { AppError } = require("../common/errors/AppError");

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
    const admin = initializeFirebase();
    const decoded = await admin.auth().verifyIdToken(token, true);

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
