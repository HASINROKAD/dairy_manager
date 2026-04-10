function toPublicUser(user) {
  return {
    userId: user._id,
    firebaseUid: user.firebaseUid,
    name: user.name || null,
    phone: user.mobileNumber || null,
    email: user.email || null,
    role: user.role,
    profileCompleted: user.profileCompleted,
  };
}

module.exports = { toPublicUser };
