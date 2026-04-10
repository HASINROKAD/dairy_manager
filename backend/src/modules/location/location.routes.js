const express = require("express");
const { authenticate } = require("../../middleware/authenticate");
const { attachUser } = require("../../middleware/attachUser");
const {
  resolveAddress,
  putMyLocation,
  getMyLocation,
} = require("./location.controller");

const locationRouter = express.Router();

locationRouter.use(authenticate, attachUser);
locationRouter.post("/me/location/resolve", resolveAddress);
locationRouter.put("/me/location", putMyLocation);
locationRouter.get("/me/location", getMyLocation);

module.exports = { locationRouter };
