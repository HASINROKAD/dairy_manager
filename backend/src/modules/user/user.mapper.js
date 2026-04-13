function toPublicUser(user) {
  return {
    userId: user._id,
    firebaseUid: user.firebaseUid,
    name: user.name || null,
    phone: user.mobileNumber || null,
    email: user.email || null,
    role: user.role,
    activeSellerUserId: user.activeSellerUserId || null,
    activeSellerLinkedAt: user.activeSellerLinkedAt || null,
    profileCompleted: user.profileCompleted,
  };
}

module.exports = { toPublicUser };
