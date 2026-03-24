/**
 * Pagination utility with an off-by-one bug.
 */

function paginate(items, page, pageSize) {
  // BUG: off-by-one in start index calculation
  // page is 1-based but calculation treats it as 0-based incorrectly
  const start = page * pageSize; // Should be (page - 1) * pageSize
  const end = start + pageSize;
  return {
    data: items.slice(start, end),
    total: items.length,
    page: page,
    totalPages: Math.ceil(items.length / pageSize),
  };
}

// Test
const items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

console.log(paginate(items, 1, 3)); // Expected: [1,2,3], Actual: [4,5,6]
console.log(paginate(items, 2, 3)); // Expected: [4,5,6], Actual: [7,8,9]

module.exports = { paginate };
