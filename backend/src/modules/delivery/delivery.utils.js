function getTodayDateKey() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function getCurrentDeliverySlot(now = new Date()) {
  const hour = now.getHours();
  return hour < 12 ? "morning" : "evening";
}

function asRupees(basePricePerLitreRupees, quantityLitres) {
  return Number(
    (Number(basePricePerLitreRupees) * Number(quantityLitres)).toFixed(2),
  );
}

module.exports = { getTodayDateKey, getCurrentDeliverySlot, asRupees };
