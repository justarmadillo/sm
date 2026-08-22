/**
 * Generate golden vectors from the ts-fsrs source and write them as JSON.
 *
 * This port claims to be identical to ts-fsrs, and identity is checked by
 * replaying these vectors in Dart rather than by re-asserting hand-copied
 * numbers: every card, log, seed and fuzzed interval here came out of the
 * reference implementation itself.
 *
 * Usage (from the repository root, with a ts-fsrs checkout available):
 *
 *   npx tsx fsrs-dart/tool/gen_ts_vectors.mts \
 *     --ts-fsrs <path-to-ts-fsrs>/packages/fsrs/src \
 *     --out fsrs-dart/test/vectors/ts_fsrs_vectors.json
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

function arg(name: string): string {
  const index = process.argv.indexOf(`--${name}`)
  if (index < 0 || index + 1 >= process.argv.length) {
    throw new Error(`missing --${name}`)
  }
  return process.argv[index + 1]
}

const srcDir = resolve(arg('ts-fsrs'))
const outPath = resolve(arg('out'))

const {
  fsrs,
  createEmptyCard,
  Rating,
  State,
  Grades,
  FSRSAlgorithm,
  generatorParameters,
  migrateParameters,
  clipParameters,
  forgetting_curve,
  computeDecayFactor,
  get_fuzz_range,
  dateDiffInDays,
  date_diff,
  date_scheduler,
  show_diff_message,
  StrategyMode,
  DefaultInitSeedStrategy,
  ConvertStepUnitToMinutes,
  BasicLearningStepsStrategy,
  default_w,
} = (await import(pathToFileURL(`${srcDir}/index.ts`).href)) as any

// `alea` is internal to ts-fsrs, so it is imported from its module directly.
const { alea } = (await import(pathToFileURL(`${srcDir}/alea.ts`).href)) as any

const START = new Date('2022-11-29T12:30:00.000Z')

/** A deterministic LCG, so the Dart replay sees exactly this walk. */
function lcg(seed: number) {
  let state = seed >>> 0
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0
    return state / 4294967296
  }
}

const serializeCard = (card: any) => ({
  due: card.due.toISOString(),
  stability: card.stability,
  difficulty: card.difficulty,
  elapsed_days: card.elapsed_days,
  scheduled_days: card.scheduled_days,
  learning_steps: card.learning_steps,
  reps: card.reps,
  lapses: card.lapses,
  state: card.state,
  last_review: card.last_review ? card.last_review.toISOString() : null,
})

const serializeLog = (log: any) => ({
  rating: log.rating,
  state: log.state,
  due: log.due.toISOString(),
  stability: log.stability,
  difficulty: log.difficulty,
  elapsed_days: log.elapsed_days,
  last_elapsed_days: log.last_elapsed_days,
  scheduled_days: log.scheduled_days,
  learning_steps: log.learning_steps,
  review: log.review.toISOString(),
})

const FSRS4_W17 = [
  0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474,
  0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755,
]
const FSRS5_W19 = [
  0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575,
  0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655,
  0.6621,
]
const CUSTOM_W21 = [
  0.3, 1.5, 2.9, 9.1, 6.0, 0.9, 2.8, 0.05, 1.7, 0.2, 0.9, 1.3, 0.1, 0.3, 1.5,
  0.5, 2.0, 0.6, 0.1, 0.09, 0.2,
]

const configs: { name: string; params: Record<string, unknown> }[] = [
  { name: 'default', params: {} },
  { name: 'long-term', params: { enable_short_term: false } },
  {
    name: 'no-steps',
    params: { learning_steps: [], relearning_steps: [] },
  },
  {
    name: 'many-steps',
    params: {
      learning_steps: ['1m', '5m', '10m', '1d'],
      relearning_steps: ['10m', '1h', '1d'],
    },
  },
  { name: 'single-step', params: { learning_steps: ['5m'], relearning_steps: ['5m'] } },
  { name: 'retention-095', params: { request_retention: 0.95 } },
  {
    name: 'retention-070-max100',
    params: { request_retention: 0.7, maximum_interval: 100 },
  },
  { name: 'fuzz', params: { enable_fuzz: true } },
  {
    name: 'fuzz-long-term',
    params: { enable_fuzz: true, enable_short_term: false },
  },
  { name: 'w17', params: { w: FSRS4_W17 } },
  { name: 'w19', params: { w: FSRS5_W19 } },
  { name: 'w21-custom', params: { w: CUSTOM_W21 } },
  {
    name: 'w21-custom-two-relearning-steps',
    params: { w: CUSTOM_W21, relearning_steps: ['10m', '20m'] },
  },
]

/** Minute offsets the walk may pick between reviews. */
const OFFSETS = [0, 1, 6, 10, 60, 1440, 2880, 4320, 14400, 43200, 525600]

const walks = configs.map((config, configIndex) => {
  const seeds: string[] = []
  const scheduler = fsrs(config.params)
  scheduler.useStrategy(StrategyMode.SEED, function (this: unknown) {
    const seed = DefaultInitSeedStrategy.call(this)
    seeds.push(seed)
    return seed
  })

  const random = lcg(20221129 + configIndex * 7919)
  let card = createEmptyCard(START)
  let now = START
  const steps: unknown[] = []

  for (let i = 0; i < 25; i++) {
    const offset = OFFSETS[Math.floor(random() * OFFSETS.length)]
    now = new Date(now.getTime() + offset * 60 * 1000)
    const seedsBefore = seeds.length
    const preview = scheduler.repeat(card, now)
    const grade = Grades[Math.floor(random() * Grades.length)]
    const chosen = preview[grade]

    steps.push({
      now: now.toISOString(),
      offset_minutes: offset,
      grade,
      card_before: serializeCard(card),
      retrievability: scheduler.get_retrievability(card, now, false),
      retrievability_text: scheduler.get_retrievability(card, now, true),
      preview: Object.fromEntries(
        Grades.map((g: number) => [
          g,
          {
            card: serializeCard(preview[g].card),
            log: serializeLog(preview[g].log),
          },
        ])
      ),
      seed: seeds[seedsBefore] ?? null,
      rollback: serializeCard(scheduler.rollback(chosen.card, chosen.log)),
      forget: {
        card: serializeCard(scheduler.forget(chosen.card, now, false).card),
        log: serializeLog(scheduler.forget(chosen.card, now, false).log),
      },
      forget_reset: {
        card: serializeCard(scheduler.forget(chosen.card, now, true).card),
        log: serializeLog(scheduler.forget(chosen.card, now, true).log),
      },
    })
    card = chosen.card
  }

  return {
    name: config.name,
    params: config.params,
    resolved_parameters: {
      request_retention: scheduler.parameters.request_retention,
      maximum_interval: scheduler.parameters.maximum_interval,
      w: Array.from(scheduler.parameters.w),
      enable_fuzz: scheduler.parameters.enable_fuzz,
      enable_short_term: scheduler.parameters.enable_short_term,
      learning_steps: Array.from(scheduler.parameters.learning_steps),
      relearning_steps: Array.from(scheduler.parameters.relearning_steps),
    },
    interval_modifier: scheduler.interval_modifier,
    steps,
  }
})

// --- Algorithm primitives -------------------------------------------------

const algorithm = new FSRSAlgorithm({})
const primitives = {
  init_stability: Grades.map((g: number) => ({
    grade: g,
    value: algorithm.init_stability(g),
  })),
  init_difficulty: Grades.map((g: number) => ({
    grade: g,
    value: algorithm.init_difficulty(g),
  })),
  next_difficulty: [] as unknown[],
  next_recall_stability: [] as unknown[],
  next_forget_stability: [] as unknown[],
  next_short_term_stability: [] as unknown[],
  next_state: [] as unknown[],
  forgetting_curve: [] as unknown[],
  next_interval: [] as unknown[],
  linear_damping: [] as unknown[],
  mean_reversion: [] as unknown[],
  decay_factor: [] as unknown[],
}

for (const d of [1, 1.5, 3, 5, 6.3574867, 8, 9.5, 10]) {
  for (const g of Grades) {
    primitives.next_difficulty.push({
      difficulty: d,
      grade: g,
      value: algorithm.next_difficulty(d, g),
    })
  }
  primitives.linear_damping.push({
    delta_d: -1.5,
    old_d: d,
    value: algorithm.linear_damping(-1.5, d),
  })
  primitives.mean_reversion.push({
    init: 5.5,
    current: d,
    value: algorithm.mean_reversion(5.5, d),
  })
}

for (const d of [1, 3, 5, 7.5, 10]) {
  for (const s of [0.001, 0.1, 1, 10, 100, 1000, 36500]) {
    for (const r of [0.05, 0.5, 0.9, 0.99, 1]) {
      for (const g of [2, 3, 4]) {
        primitives.next_recall_stability.push({
          difficulty: d,
          stability: s,
          retrievability: r,
          grade: g,
          value: algorithm.next_recall_stability(d, s, r, g),
        })
      }
      primitives.next_forget_stability.push({
        difficulty: d,
        stability: s,
        retrievability: r,
        value: algorithm.next_forget_stability(d, s, r),
      })
    }
  }
}

for (const s of [0.001, 0.1, 0.5, 1, 2.3065, 10, 53.62691, 365, 3650, 36500]) {
  for (const g of Grades) {
    primitives.next_short_term_stability.push({
      stability: s,
      grade: g,
      value: algorithm.next_short_term_stability(s, g),
    })
  }
  for (const t of [0, 1, 2, 5, 10, 30, 100, 365, 1000]) {
    primitives.forgetting_curve.push({
      stability: s,
      elapsed_days: t,
      value: forgetting_curve(default_w, t, s),
    })
    for (const g of Grades) {
      primitives.next_state.push({
        stability: s,
        difficulty: 5.5,
        elapsed_days: t,
        grade: g,
        value: algorithm.next_state({ stability: s, difficulty: 5.5 }, t, g),
      })
    }
  }
}

for (const retention of [0.7, 0.8, 0.9, 0.95, 0.99]) {
  const inst = new FSRSAlgorithm({ request_retention: retention })
  for (const s of [0.001, 0.1, 1, 2.3065, 10, 53.62691, 365, 3650, 36500]) {
    primitives.next_interval.push({
      request_retention: retention,
      stability: s,
      value: inst.next_interval(s, 0),
      interval_modifier: inst.interval_modifier,
    })
  }
}

for (const decay of [0.1, 0.1542, 0.2, 0.5, 0.8]) {
  primitives.decay_factor.push({ decay, value: computeDecayFactor(decay) })
}

// --- Helpers --------------------------------------------------------------

const fuzzRanges: unknown[] = []
for (const ivl of [2.5, 3, 5, 7, 10, 20, 50, 100, 365, 3650, 36500, 40000]) {
  for (const elapsed of [0, 1, 5, 50, 400]) {
    fuzzRanges.push({
      interval: ivl,
      elapsed_days: elapsed,
      maximum_interval: 36500,
      value: get_fuzz_range(ivl, elapsed, 36500),
    })
  }
}

const aleaVectors = ['', '0', 'seed', '1669725000000_1_0', 'a'.repeat(50)].map(
  (seed) => {
    const prng = alea(seed)
    const values = [prng(), prng(), prng(), prng(), prng()]
    const int32s = [prng.int32(), prng.int32()]
    const doubles = [prng.double(), prng.double()]
    return { seed, values, int32s, doubles, state: prng.state() }
  }
)

const dateHelpers = {
  date_diff_in_days: [
    ['2022-11-29T23:59:59.000Z', '2022-11-30T00:00:01.000Z'],
    ['2022-11-29T12:30:00.000Z', '2022-11-29T12:30:00.000Z'],
    ['2022-11-29T12:30:00.000Z', '2023-11-29T12:29:00.000Z'],
    ['2023-11-29T12:30:00.000Z', '2022-11-29T12:30:00.000Z'],
  ].map(([a, b]) => ({
    last: a,
    cur: b,
    value: dateDiffInDays(new Date(a), new Date(b)),
  })),
  date_diff: [
    ['2022-11-30T00:00:01.000Z', '2022-11-29T23:59:59.000Z', 'days'],
    ['2022-11-30T00:00:01.000Z', '2022-11-29T23:59:59.000Z', 'minutes'],
    ['2022-12-30T00:00:01.000Z', '2022-11-29T23:59:59.000Z', 'days'],
    ['2022-11-29T23:59:59.000Z', '2022-11-30T00:00:01.000Z', 'minutes'],
  ].map(([a, b, unit]) => ({
    now: a,
    pre: b,
    unit,
    value: date_diff(new Date(a), new Date(b), unit),
  })),
  date_scheduler: [
    [10, false],
    [1440, false],
    [-30, false],
    [1, true],
    [365, true],
  ].map(([t, isDay]) => ({
    t,
    is_day: isDay,
    value: date_scheduler(START, t as number, isDay as boolean).toISOString(),
  })),
  show_diff_message: [
    ['2022-11-29T12:30:30.000Z', false],
    ['2022-11-29T13:30:00.000Z', false],
    ['2022-12-29T12:30:00.000Z', true],
    ['2032-11-29T12:30:00.000Z', true],
  ].map(([due, unit]) => ({
    due,
    unit,
    value: show_diff_message(new Date(due as string), START, unit as boolean),
  })),
}

const parameterMigration = [
  { w: FSRS4_W17, relearning_steps: 1, short_term: true },
  { w: FSRS4_W17, relearning_steps: 3, short_term: true },
  { w: FSRS5_W19, relearning_steps: 1, short_term: true },
  { w: FSRS5_W19, relearning_steps: 2, short_term: false },
  { w: CUSTOM_W21, relearning_steps: 1, short_term: true },
  { w: CUSTOM_W21, relearning_steps: 4, short_term: true },
  { w: CUSTOM_W21, relearning_steps: 4, short_term: false },
  { w: [1, 2, 3], relearning_steps: 1, short_term: true },
  {
    w: Array.from({ length: 21 }, (_, i) => (i % 2 === 0 ? -5 : 99)),
    relearning_steps: 2,
    short_term: true,
  },
].map((entry) => ({
  input: entry.w,
  relearning_steps: entry.relearning_steps,
  short_term: entry.short_term,
  migrated: migrateParameters(entry.w, entry.relearning_steps, entry.short_term),
  clipped:
    entry.w.length === 17 || entry.w.length === 19 || entry.w.length === 21
      ? clipParameters(entry.w, entry.relearning_steps, entry.short_term)
      : null,
}))

const stepUnits = ['1m', '10m', '90m', '2h', '1d', '0m', '1440m'].map((step) => ({
  step,
  minutes: ConvertStepUnitToMinutes(step),
}))

const learningStepLayouts: unknown[] = []
for (const steps of [
  { learning_steps: ['1m', '10m'], relearning_steps: ['10m'] },
  { learning_steps: ['5m'], relearning_steps: ['5m'] },
  { learning_steps: [], relearning_steps: [] },
  {
    learning_steps: ['1m', '5m', '10m', '1d'],
    relearning_steps: ['10m', '1h'],
  },
]) {
  const params = generatorParameters(steps)
  for (const state of [State.New, State.Learning, State.Review, State.Relearning]) {
    for (const curStep of [0, 1, 2, 3, 4]) {
      const layout = BasicLearningStepsStrategy(params, state, curStep)
      learningStepLayouts.push({
        learning_steps: steps.learning_steps,
        relearning_steps: steps.relearning_steps,
        state,
        cur_step: curStep,
        layout: Object.fromEntries(
          Object.entries(layout).map(([grade, info]: [string, any]) => [
            grade,
            { scheduled_minutes: info.scheduled_minutes, next_step: info.next_step },
          ])
        ),
      })
    }
  }
}

// --- Reschedule -----------------------------------------------------------

const rescheduleCases = [
  {
    name: 'good-run',
    reviews: [
      { rating: Rating.Good, review: '2024-09-13T00:00:00.000Z' },
      { rating: Rating.Good, review: '2024-09-13T00:00:00.000Z' },
      { rating: Rating.Good, review: '2024-09-17T00:00:00.000Z' },
      { rating: Rating.Good, review: '2024-09-28T00:00:00.000Z' },
    ],
    skipManual: false,
    update_memory_state: false,
  },
  {
    name: 'with-lapses',
    reviews: [
      { rating: Rating.Again, review: '2024-09-13T00:00:00.000Z' },
      { rating: Rating.Good, review: '2024-09-13T00:10:00.000Z' },
      { rating: Rating.Hard, review: '2024-09-15T00:00:00.000Z' },
      { rating: Rating.Easy, review: '2024-09-20T00:00:00.000Z' },
      { rating: Rating.Again, review: '2024-10-20T00:00:00.000Z' },
    ],
    skipManual: true,
    update_memory_state: true,
  },
  {
    name: 'with-manual',
    reviews: [
      { rating: Rating.Good, review: '2024-09-13T00:00:00.000Z' },
      {
        rating: Rating.Manual,
        review: '2024-09-14T00:00:00.000Z',
        due: '2024-09-20T00:00:00.000Z',
        state: State.Review,
        stability: 21.79,
        difficulty: 5.05,
      },
      { rating: Rating.Good, review: '2024-09-20T00:00:00.000Z' },
    ],
    skipManual: false,
    update_memory_state: false,
  },
].map((testCase) => {
  const scheduler = fsrs()
  const result = scheduler.reschedule(
    createEmptyCard('2024-09-13T00:00:00.000Z'),
    testCase.reviews.map((review: any) => ({
      ...review,
      review: new Date(review.review),
      due: review.due ? new Date(review.due) : undefined,
    })),
    {
      skipManual: testCase.skipManual,
      update_memory_state: testCase.update_memory_state,
      now: new Date('2024-10-25T00:00:00.000Z'),
      // Pinned so the replayed first card does not depend on generation time.
      first_card: createEmptyCard('2024-09-13T00:00:00.000Z'),
    }
  )
  return {
    name: testCase.name,
    reviews: testCase.reviews,
    skip_manual: testCase.skipManual,
    update_memory_state: testCase.update_memory_state,
    now: '2024-10-25T00:00:00.000Z',
    first_card_due: '2024-09-13T00:00:00.000Z',
    collections: result.collections.map((item: any) => ({
      card: serializeCard(item.card),
      log: serializeLog(item.log),
    })),
    reschedule_item: result.reschedule_item
      ? {
          card: serializeCard(result.reschedule_item.card),
          log: serializeLog(result.reschedule_item.log),
        }
      : null,
  }
})

// JavaScript number-to-string conversion, which the default seed strategy
// interpolates into the fuzz seed. Dart formats doubles differently, so the
// port reimplements this and needs vectors to prove it.
const jsNumberStrings = [
  0, 1, 5, -5, 0.5, 1 / 3, 2.3065, 2.11810397, 2.3065 * 2.11810397,
  0.1 + 0.2, 1e20, 1e21, 1.5e21, 1e-6, 1e-7, 1.2345e-9, 123456789012345680000,
  Number.MAX_SAFE_INTEGER, 1.7976931348623157e308, 5e-324, 36500, 0.001,
].map((value) => ({ value, text: String(value) }))

const payload = {
  generator: 'ts-fsrs',
  start: START.toISOString(),
  walks,
  primitives,
  fuzz_ranges: fuzzRanges,
  alea: aleaVectors,
  date_helpers: dateHelpers,
  parameter_migration: parameterMigration,
  step_units: stepUnits,
  learning_step_layouts: learningStepLayouts,
  reschedule: rescheduleCases,
  js_number_strings: jsNumberStrings,
}

mkdirSync(dirname(outPath), { recursive: true })
writeFileSync(outPath, JSON.stringify(payload), 'utf-8')
console.log(`wrote ${outPath}`)
