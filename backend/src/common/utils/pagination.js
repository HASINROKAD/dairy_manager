function asPositiveInteger(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }

  return parsed;
}

function parsePaginationParams({
  page,
  limit,
  defaultLimit = 20,
  maxLimit = 100,
} = {}) {
  const safeDefaultLimit = Math.max(1, defaultLimit);
  const safeMaxLimit = Math.max(safeDefaultLimit, maxLimit);

  const parsedPage = asPositiveInteger(page, 1);
  const parsedLimit = Math.min(
    Math.max(asPositiveInteger(limit, safeDefaultLimit), 1),
    safeMaxLimit,
  );

  return {
    page: parsedPage,
    limit: parsedLimit,
    skip: (parsedPage - 1) * parsedLimit,
  };
}

function buildPaginationMeta({ page, limit, totalItems, returnedItems }) {
  const safeTotalItems = Math.max(0, Number(totalItems) || 0);
  const safeLimit = Math.max(1, Number(limit) || 1);
  const totalPages =
    safeTotalItems > 0 ? Math.ceil(safeTotalItems / safeLimit) : 0;

  return {
    page: Number(page) || 1,
    limit: safeLimit,
    totalItems: safeTotalItems,
    totalPages,
    returnedItems: Math.max(0, Number(returnedItems) || 0),
    hasPreviousPage: (Number(page) || 1) > 1,
    hasNextPage: totalPages > 0 && (Number(page) || 1) < totalPages,
  };
}

module.exports = {
  parsePaginationParams,
  buildPaginationMeta,
};
