const mongoose = require("mongoose");

const { AppError } = require("../../common/errors/AppError");
const { UserModel } = require("../user/user.model");
const { SellerProfileModel } = require("../seller/sellerProfile.model");
const { JoinRequestModel } = require("./joinRequest.model");
const { createNotification } = require("../notification/notification.service");

function toJoinRequestDto(doc) {
  return {
    id: doc._id,
    customerUserId: doc.customerUserId?._id || doc.customerUserId,
    customerName: doc.customerUserId?.name || null,
    sellerUserId: doc.sellerUserId?._id || doc.sellerUserId,
    sellerName: doc.sellerUserId?.name || null,
    status: doc.status,
    rejectionReason: doc.rejectionReason || null,
    respondedAt: doc.respondedAt || null,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

async function createJoinRequest({ customerUser, sellerUserId }) {
  if (!mongoose.Types.ObjectId.isValid(sellerUserId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid seller user id.");
  }

  if (String(customerUser._id) === String(sellerUserId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Cannot request yourself.");
  }

  if (customerUser.activeSellerUserId) {
    throw new AppError(
      400,
      "ALREADY_LINKED",
      "You are already linked to a seller organization.",
    );
  }

  const seller = await UserModel.findOne({
    _id: sellerUserId,
    role: "seller",
    isActive: true,
    profileCompleted: true,
  }).select("_id name");

  if (!seller) {
    throw new AppError(404, "SELLER_NOT_FOUND", "Seller not found.");
  }

  const pendingByCustomer = await JoinRequestModel.findOne({
    customerUserId: customerUser._id,
    status: "pending",
  }).select("_id");

  if (pendingByCustomer) {
    throw new AppError(
      409,
      "PENDING_REQUEST_EXISTS",
      "You already have a pending join request.",
    );
  }

  const request = await JoinRequestModel.create({
    customerUserId: customerUser._id,
    sellerUserId: seller._id,
    status: "pending",
  });

  await createNotification({
    recipientUserId: seller._id,
    actorUserId: customerUser._id,
    type: "request_sent",
    title: "New customer join request",
    message: `${customerUser.name || "A customer"} requested to join your organization.`,
    metadata: {
      requestId: request._id,
      customerUserId: customerUser._id,
      sellerUserId: seller._id,
    },
  });

  const hydrated = await JoinRequestModel.findById(request._id)
    .populate("customerUserId", "name")
    .populate("sellerUserId", "name")
    .lean();

  return toJoinRequestDto(hydrated);
}

async function listCustomerJoinRequests(customerUserId) {
  const requests = await JoinRequestModel.find({ customerUserId })
    .sort({ createdAt: -1 })
    .populate("sellerUserId", "name")
    .lean();

  return requests.map(toJoinRequestDto);
}

async function listSellerJoinRequests({ sellerUserId, status }) {
  const query = {
    sellerUserId,
    ...(status ? { status } : {}),
  };

  const requests = await JoinRequestModel.find(query)
    .sort({ createdAt: -1 })
    .populate("customerUserId", "name mobileNumber")
    .lean();

  return requests.map(toJoinRequestDto);
}

async function reviewJoinRequest({
  sellerUser,
  requestId,
  action,
  rejectionReason,
}) {
  if (!mongoose.Types.ObjectId.isValid(requestId)) {
    throw new AppError(400, "VALIDATION_ERROR", "Invalid request id.");
  }

  const normalizedAction = String(action || "")
    .trim()
    .toLowerCase();
  if (!["accept", "reject"].includes(normalizedAction)) {
    throw new AppError(
      400,
      "VALIDATION_ERROR",
      "action must be accept or reject.",
    );
  }

  const session = await mongoose.startSession();

  try {
    let output;

    await session.withTransaction(async () => {
      const request = await JoinRequestModel.findOne({
        _id: requestId,
        sellerUserId: sellerUser._id,
        status: "pending",
      }).session(session);

      if (!request) {
        throw new AppError(404, "REQUEST_NOT_FOUND", "Join request not found.");
      }

      const customer = await UserModel.findOne({
        _id: request.customerUserId,
        role: "customer",
        isActive: true,
      }).session(session);

      if (!customer) {
        throw new AppError(404, "CUSTOMER_NOT_FOUND", "Customer not found.");
      }

      if (normalizedAction === "accept") {
        if (
          customer.activeSellerUserId &&
          String(customer.activeSellerUserId) !== String(sellerUser._id)
        ) {
          throw new AppError(
            409,
            "CUSTOMER_ALREADY_LINKED",
            "Customer is already linked to another seller.",
          );
        }

        customer.activeSellerUserId = sellerUser._id;
        customer.activeSellerLinkedAt = new Date();
        await customer.save({ session });

        request.status = "accepted";
        request.rejectionReason = "";
        request.respondedAt = new Date();
        request.respondedByUserId = sellerUser._id;
        await request.save({ session });

        await JoinRequestModel.updateMany(
          {
            customerUserId: customer._id,
            status: "pending",
            _id: { $ne: request._id },
          },
          {
            $set: {
              status: "rejected",
              rejectionReason: "Another seller request already accepted.",
              respondedAt: new Date(),
              respondedByUserId: sellerUser._id,
            },
          },
          { session },
        );

        await createNotification({
          recipientUserId: customer._id,
          actorUserId: sellerUser._id,
          type: "request_accepted",
          title: "Join request accepted",
          message: `${sellerUser.name || "Seller"} accepted your join request.`,
          metadata: {
            requestId: request._id,
            customerUserId: customer._id,
            sellerUserId: sellerUser._id,
          },
          session,
        });
      } else {
        request.status = "rejected";
        request.rejectionReason = (rejectionReason || "").trim();
        request.respondedAt = new Date();
        request.respondedByUserId = sellerUser._id;
        await request.save({ session });

        await createNotification({
          recipientUserId: customer._id,
          actorUserId: sellerUser._id,
          type: "request_rejected",
          title: "Join request rejected",
          message: `${sellerUser.name || "Seller"} rejected your join request.${
            request.rejectionReason ? ` Reason: ${request.rejectionReason}` : ""
          }`,
          metadata: {
            requestId: request._id,
            customerUserId: customer._id,
            sellerUserId: sellerUser._id,
          },
          session,
        });
      }

      const hydrated = await JoinRequestModel.findById(request._id)
        .populate("customerUserId", "name")
        .populate("sellerUserId", "name")
        .session(session)
        .lean();

      output = toJoinRequestDto(hydrated);
    });

    return output;
  } finally {
    await session.endSession();
  }
}

async function listSellerCustomers(sellerUserId) {
  const customers = await UserModel.find({
    role: "customer",
    isActive: true,
    activeSellerUserId: sellerUserId,
  })
    .select("_id firebaseUid name mobileNumber email activeSellerLinkedAt")
    .sort({ activeSellerLinkedAt: -1, createdAt: -1 })
    .lean();

  return customers.map((customer) => ({
    customerUserId: customer._id,
    customerFirebaseUid: customer.firebaseUid,
    name: customer.name || null,
    phone: customer.mobileNumber || null,
    email: customer.email || null,
    linkedAt: customer.activeSellerLinkedAt || null,
  }));
}

async function getCustomerOrganization(customerUser) {
  if (!customerUser.activeSellerUserId) {
    return null;
  }

  const sellerUser = await UserModel.findOne({
    _id: customerUser.activeSellerUserId,
    role: "seller",
    isActive: true,
  })
    .select("_id firebaseUid name mobileNumber email")
    .lean();

  if (!sellerUser) {
    return null;
  }

  const sellerProfile = await SellerProfileModel.findOne({
    userId: sellerUser._id,
  })
    .select("shopName displayAddress")
    .lean();

  return {
    sellerUserId: sellerUser._id,
    sellerFirebaseUid: sellerUser.firebaseUid,
    sellerName: sellerUser.name || null,
    shopName: sellerProfile?.shopName || null,
    displayAddress: sellerProfile?.displayAddress || null,
    phone: sellerUser.mobileNumber || null,
    email: sellerUser.email || null,
    linkedAt: customerUser.activeSellerLinkedAt || null,
  };
}

module.exports = {
  createJoinRequest,
  listCustomerJoinRequests,
  listSellerJoinRequests,
  reviewJoinRequest,
  listSellerCustomers,
  getCustomerOrganization,
};
