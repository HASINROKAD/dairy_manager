const express = require("express");
const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const { getMe, patchOnboarding, patchRole } = require("./user.controller");

const userRouter = express.Router();

userRouter.use(authenticate, attachUser);
userRouter.get("/me", getMe);
userRouter.patch("/me/onboarding", patchOnboarding);
userRouter.patch("/me/role", patchRole);

module.exports = { userRouter };
