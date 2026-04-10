const express = require("express");
const { authenticate } = require("../../middleware/authenticate");
const { syncAuth } = require("./auth.controller");

const authRouter = express.Router();

authRouter.post("/sync", authenticate, syncAuth);

module.exports = { authRouter };
