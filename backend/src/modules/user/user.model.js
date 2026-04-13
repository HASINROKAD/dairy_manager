const mongoose = require("mongoose");

const USER_ROLES = ["seller", "customer"];

const userSchema = new mongoose.Schema(
  {
    firebaseUid: {
      type: String,
      required: true,
      unique: true,
      index: true,
      trim: true,
    },
    email: { type: String, default: "", trim: true },
    mobileNumber: { type: String, default: "", trim: true },
    name: { type: String, default: "", trim: true },
    role: { type: String, enum: USER_ROLES, default: null, index: true },
    activeSellerUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
      index: true,
    },
    activeSellerLinkedAt: { type: Date, default: null },
    profileCompleted: { type: Boolean, default: false, index: true },
    isActive: { type: Boolean, default: true },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

const UserModel = mongoose.model("User", userSchema);

module.exports = { UserModel, USER_ROLES };
