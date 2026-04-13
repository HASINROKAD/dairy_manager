const express = require("express");
const cors = require("cors");

const { authRouter } = require("./modules/auth/auth.routes");
const { userRouter } = require("./modules/user/user.routes");
const { locationRouter } = require("./modules/location/location.routes");
const { discoveryRouter } = require("./modules/discovery/discovery.routes");
const {
  joinRequestRouter,
} = require("./modules/joinRequest/joinRequest.routes");
const {
  notificationRouter,
} = require("./modules/notification/notification.routes");
const { sellerRouter } = require("./modules/delivery/seller.routes");
const { customerRouter } = require("./modules/delivery/customer.routes");
const {
  notFoundHandler,
  errorHandler,
} = require("./common/middleware/errorHandler");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => {
  res.status(200).json({ success: true, message: "Backend is healthy." });
});

app.use("/v1/auth", authRouter);
app.use("/v1", userRouter);
app.use("/v1", locationRouter);
app.use("/v1", discoveryRouter);
app.use("/v1", joinRequestRouter);
app.use("/v1", notificationRouter);

app.use("/api/seller", sellerRouter);
app.use("/api/customer", customerRouter);

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = { app };
