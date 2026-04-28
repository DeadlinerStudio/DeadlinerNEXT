export type Season = 'spring' | 'summer' | 'autumn' | 'winter'

interface YearSeasonMap {
  spring: [
    number,
    number
  ]; // 立春
  summer: [
    number,
    number
  ]; // 立夏
  autumn: [
    number,
    number
  ]; // 立秋
  winter: [
    number,
    number
  ]; // 立冬
}

export class SeasonUtils {
  /**
   * 2025-2035 年四季边界节气日期。
   *
   * 规则：
   * - [立春, 立夏) => spring
   * - [立夏, 立秋) => summer
   * - [立秋, 立冬) => autumn
   * - [立冬, 次年立春) => winter
   *
   * 注意：
   * Date 的 month 是 0-based，所以 2 月写 1，5 月写 4。
   */
  private static readonly SEASON_TERMS: Record<number, YearSeasonMap> = {
    2025: {
      spring: [2, 3],
      summer: [5, 5],
      autumn: [8, 7],
      winter: [11, 7]
    },
    2026: {
      spring: [2, 4],
      summer: [5, 5],
      autumn: [8, 7],
      winter: [11, 7]
    },
    2027: {
      spring: [2, 4],
      summer: [5, 6],
      autumn: [8, 8],
      winter: [11, 7]
    },
    2028: {
      spring: [2, 4],
      summer: [5, 6],
      autumn: [8, 8],
      winter: [11, 8]
    },
    2029: {
      spring: [2, 3],
      summer: [5, 5],
      autumn: [8, 7],
      winter: [11, 7]
    },
    2030: {
      spring: [2, 4],
      summer: [5, 5],
      autumn: [8, 7],
      winter: [11, 7]
    },
    2031: {
      spring: [2, 4],
      summer: [5, 6],
      autumn: [8, 8],
      winter: [11, 7]
    },
    2032: {
      spring: [2, 4],
      summer: [5, 6],
      autumn: [8, 8],
      winter: [11, 8]
    },
    2033: {
      spring: [2, 3],
      summer: [5, 5],
      autumn: [8, 7],
      winter: [11, 7]
    },
    2034: {
      spring: [2, 4],
      summer: [5, 5],
      autumn: [8, 7],
      winter: [11, 7]
    },
    2035: {
      spring: [2, 4],
      summer: [5, 5],
      autumn: [8, 7],
      winter: [11, 7]
    }
  }

  /**
   * 获取当前季节。
   *
   * @param date 默认为当前日期，也可传入指定日期测试。
   * @returns spring | summer | autumn | winter
   */
  static getCurrentSeason(date: Date = new Date()): Season {
    const year = date.getFullYear()

    if (year < 2025 || year > 2035) {
      throw new Error(`SeasonUtils only supports years from 2025 to 2035. Current year: ${year}`)
    }

    const terms = SeasonUtils.SEASON_TERMS[year]

    const current = SeasonUtils.toDateNumber(date)

    const springStart = SeasonUtils.toDateNumber(
      new Date(year, terms.spring[0] - 1, terms.spring[1])
    )
    const summerStart = SeasonUtils.toDateNumber(
      new Date(year, terms.summer[0] - 1, terms.summer[1])
    )
    const autumnStart = SeasonUtils.toDateNumber(
      new Date(year, terms.autumn[0] - 1, terms.autumn[1])
    )
    const winterStart = SeasonUtils.toDateNumber(
      new Date(year, terms.winter[0] - 1, terms.winter[1])
    )

    if (current >= winterStart) {
      return 'winter'
    }

    if (current >= autumnStart) {
      return 'autumn'
    }

    if (current >= summerStart) {
      return 'summer'
    }

    if (current >= springStart) {
      return 'spring'
    }

    // 当年立春前仍属于上一年冬季。
    return 'winter'
  }

  /**
   * 转成 YYYYMMDD，避免直接比较 Date 时受到时分秒影响。
   */
  private static toDateNumber(date: Date): number {
    const year = date.getFullYear()
    const month = date.getMonth() + 1
    const day = date.getDate()

    return year * 10000 + month * 100 + day
  }
}