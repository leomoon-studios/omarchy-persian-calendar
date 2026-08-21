const assert = require("assert")
const model = require("../Model.js")

const conversions = [
  [[2026, 8, 20], [1405, 5, 29]],
  [[2024, 3, 20], [1403, 1, 1]],
  [[2025, 3, 20], [1403, 12, 30]],
  [[2014, 3, 31], [1393, 1, 11]]
]

for (const [gregorian, persian] of conversions) {
  const converted = model.gregorianToJalali(...gregorian)
  assert.deepStrictEqual(
    [converted.year, converted.month, converted.day],
    persian
  )

  const roundTrip = model.jalaliToGregorian(...persian)
  assert.deepStrictEqual(
    [roundTrip.year, roundTrip.month, roundTrip.day],
    gregorian
  )
}

assert.strictEqual(model.toPersianDigits("1405/05/29"), "۱۴۰۵/۰۵/۲۹")
assert.strictEqual(model.persianDayOfYear(5, 29), 153)
assert.strictEqual(model.persianDaysInYear(1403), 366)
assert.strictEqual(model.persianDaysInYear(1405), 365)
assert.strictEqual(model.persianYearProgressPercent(1405, 1, 1), 0)
assert.strictEqual(model.persianYearProgressPercent(1405, 5, 29), 42)
assert.deepStrictEqual(model.weekdayOrder(6), [6, 0, 1, 2, 3, 4, 5])

const grid = model.persianMonthGrid(1405, 5, 6, "1405-05-29")
assert.strictEqual(grid.length, 6)
assert.ok(grid.every(week => week.days.length === 7))
assert.deepStrictEqual(grid[0].days.map(day => day.weekday), [6, 0, 1, 2, 3, 4, 5])
assert.strictEqual(grid.flatMap(week => week.days).filter(day => day.today).length, 1)

console.log("Persian calendar model tests passed")
