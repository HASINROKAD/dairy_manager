function getTodayDateKey() {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  const day = String(now.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function asRupees(basePricePerLitreRupees, quantityLitres) {
  return Number(
    (Number(basePricePerLitreRupees) * Number(quantityLitres)).toFixed(2),
  );
}

module.exports = { getTodayDateKey, asRupees };
