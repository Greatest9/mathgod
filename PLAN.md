# MathGod — Shared Work Plan

Status key: `[ ]` pending · `[~]` in progress · `[x]` done

---

## Phase A — Verified Bug Fixes

Quick wins verified against source. Fix `P1` items first — one unblocks plotting, the other is the UI jank.

### A1 · `e^x` cannot be plotted — resolved by Phase C
`replaceAll('e^', 'exp')` turned `e^x` into the identifier `expx` (unbound variable) → all 201 sample points threw → "No points to display". The old `function_grapher.dart` is replaced in Phase C by the shared `GraphEvaluator`, which parses `e` as Euler's number correctly.

### A2 · Solver ran on the UI thread — solver_screen.dart:57 `[x]`
Comment claimed "Run solver off the main thread", but `Future.microtask` stays on the same isolate and `GiacFFI.solve()` (giac_ffi.dart:84) is a *synchronous* native call → janked the UI on heavy Giac calls.
- Done: `_solve()` sends the work across the isolate boundary with `compute(_solveInBackground, _SolveRequest(input, approximate))`; a solver failure surfaces as a SnackBar instead of leaving the spinner stuck, and is also logged via `debugPrint`.
- Gotcha (cost a debug cycle): the first attempt used `Isolate.run(() => SolverEngine.instance.solve(...))`. That closure is created inside `_SolverScreenState._solve()`, so it captured the receiver — the isolate message carried the whole `State` → `FocusNode` → element tree → `TextPainter` → `WidgetsFlutterBinding` graph, and the VM rejected it at send time ("object is unsendable - Class: _AsyncCompleter"). On Android it surfaced as the generic "Illegal argument in isolate message", the catch reset `_loading` and showed a SnackBar, so solving never worked. The message must only contain a top-level function tear-off plus plain data, hence the request class.
- Same bug class existed in the graphers (`graph_2d.dart` / `graph_3d.dart` sampled via `Isolate.run` closures built in `State` methods, wrapped in a silent sync fallback) — both now use `compute` with request classes. `test/solver_isolate_test.dart` guards it: an unsendable `InheritedWidget` above `SolverScreen` plus `tester.runAsync` (isolate replies are not delivered inside the fake-async zone) asserts no SnackBar and a rendered result.
- **Required native change:** Giac's C wrapper shares one `giac::context*` and had no locking, so parallel isolates would have raced the CAS. Added a `std::mutex` around `giac_init()`/`solve_math()` in `android/app/src/main/cpp/giac_wrapper.cpp`. Android-only build — iOS never linked the wrapper (no `giac` refs in `project.pbxproj`), so it uses the Dart pattern path.
- Needs a native rebuild (`flutter clean` / full build) to take effect.
- Verified on device 2026-09-17 (SM-N9760, build `build-20260917-091914`): `d/dx[x^3]` → `3*x^2` with a Power Rule step, and `int(e^x,0,1)` → `exp(1)-1` with a verification step. logcat free of isolate-send errors.

### A3 · Newton fallback silently lied — pattern_solver.dart:451 `[x]`
`_ep()` fallback ended with `return x * x * x - 2`, so an unmatched expression (e.g. `newton(sin(x))` without Giac) reported the root of x³−2 ≈ 1.2599, not the true root.
- Done: `_ep()` and `_epd()` now return `double.nan` on unmatched input. `_newtonRaphson` checks `isFinite`, emits a "Cannot Evaluate f(x)" step and returns `isUnsolvable: true` instead of a wrong root. (When Giac is available, `solver_engine.dart:52` still prefers the real Giac result.)

### A4 · Deprecation cleanup (warnings, not crashes) `[x]`
- `.withOpacity(...)` → `.withValues(alpha: ...)` — done repo-wide: 44 sites across 7 files, 0 remaining in `lib/`.
- `ColorScheme.dark(background: / onBackground:)` → removed (deprecated); `surface:` / `onSurface:` were already correct — main.dart:45.
- `_looksValid` `caseSensitive: false` dead config removed (regex is now genuinely uppercase-only) — license_manager.dart:106.

### A5 · Notes / decisions (no change for now)
- `_deviceFingerprint` keys off `model|product|Build.ID` → identical phone models share a fingerprint; "3 devices" limit tracks models. Revisit if slot enforcement matters.
- History dedupe is adjacent-only (history_service.dart:44) — intentional, keep.
- 2×2 inverse emits Formula + Gauss-Jordan cards even when the computed inverse step is shown — mildly redundant pedagogy; keep as-is unless omitting looks better.

### A6 · Triangle: home-screen "Geometry" card closes the app `[x]`
- Repro: home → tap **Geometry** (`home_screen.dart:378` pre-fills `sin(pi/4)`) → the app closes. A process death, so the Dart side is not the culprit.
- Ruled out locally: `sin(pi/4)` in the pattern path is fine (`Trigonometry`, `frac{sqrt{2}}{2}`, no throw) and there is no isolate boundary problem here.
- Working hypothesis: a native crash inside Giac on the exact-trig branch — `giacCmd = 'simplify($input)'` (solver_engine.dart, trig branch) and/or the follow-up `latex(...)` call. The trig branch already exists because `normal()` crashes the native lib on e.g. `sin(pi/8)`, so this build's trig simplification is suspect.
- **Root cause (trace captured on-device):** `Fatal signal 11 (SIGSEGV), SEGV_ACCERR` in tid **DartWorker** inside `libgiac.so` — 19 identical return-address frames = Giac's `simplify()` infinite-recurses on exact trig input and overflows the worker stack. It is the isolate thread, not the UI thread, so nothing in Flutter/Dart can catch it.
- **Fix (d2c6b4b, shipped):** the trig branch now `return null`s from `_solveViaGiac` and lets `solve()` fall through to the pattern path, which already computes exact trig values correctly (`sin(pi/4)` → √2/2). Giac's exact trignometry simplification is simply never invoked.
- Plan of attack (needs the device): capture the crash trace, then bisect which single Giac command kills it — `simplify(sin(pi/4))` vs `latex(sqrt(2)/2)` vs `evalf(sin(pi/4))` — and route the exact value through the pattern engine, using Giac only for a numeric check.
- Blocked: `adb devices` is empty (phone disconnected), so no logcat yet.

---

## Phase B — Step-by-Step Overhaul (all topics)

### Core principle
> You only get real steps if **you** compute the answer with an annotated algorithm.
> Giac is the **oracle**: final-value correctness + live verification.

### Architecture (3 layers)

**B1 · Shared step toolkit** — one vocabulary for every topic
- `ruleStep(title, latex, explanation, ruleName)` — consistent card format.
- `verificationStep(...)` — ends every solve with a real check (e.g. differentiate the antiderivative back; substitute roots into the equation; numeric probe through Giac `evalf`).

**B2 · Tiny symbolic engine in Dart** (~400–600 lines)
- AST: `Number | Var | Add | Mul | Pow | Fn`.
- Rational-number class → exact `1/3`, never `0.3333`.
- Rule-annotated ops: `diff()` (Power/Sum/Product/Chain/Quotient/Trig), matrix row-ops (Gauss-Jordan), cofactor det, characteristic polynomial, u-substitution detect, L'Hôpital.

**B3 · Giac exit-criteria validation**
- Dart engine computes its own final; Giac computes `normal(final)`; compare.
- Equal → green "✓ verified" badge. Not equal → show Giac's result, label steps "simplified"; never show a wrong final.
- Kill the boilerplate "CAS Engine / Command Sent / Result" cards (solver_engine.dart:266) — replaced by topic-aware steps + verification.

### Milestones

- **[x] M1 · All topics, low churn** — shared step toolkit + remove boilerplate + universal verification step. Wired at the single choke point `SolverEngine.solve()`, so all 26 pattern dispatchers and the Giac-only paths are covered.
  - `lib/engine/step_toolkit.dart` — `StepKit.method(operation, command)` / `StepKit.note(...)` / `StepKit.verification(Verification)` + `SolutionVerifier.check({operation, input, result, giacAvailable})` → `Verification(status: verified|failed|unavailable, check, detail)`.
  - Boilerplate deleted: `_buildGiacSteps` and the `CAS Final Verification` card are gone (also removed the now-unused `_texEscape`). The Giac-only path is now one topic-aware method card + one verification card.
  - The verifier never reuses the computation that produced the answer: central-difference probe (derivative), differentiate-the-antiderivative-back / Simpson quadrature (integral), two-sided numeric probe (limit), substitute the roots back (solve), det(A·A⁻¹)=1 (inverse), independent Dart expansion for n≤3 (determinant), det(A−λI)=0 per λ (eigenvalues), expand-the-factors-back (factorize), sample-near-the-point (series), inverse-transform (Laplace), exact-then-numeric identity (trig/evaluate/stats/…).
  - Honesty rules: any CAS error, unparsable input or non-numeric value → `unavailable` (never a false `failed`); a `failed` card says the steps are the method only and the displayed value is the CAS result. `giacAvailable: false` (desktop/web, no `.so`) short-circuits to `unavailable` with an explanatory card.
  - Deferred: the B3 "pattern vs Giac → simplified" compare-note. Both sides are exact and the displayed value is Giac's, so the verification card already delivers the never-a-wrong-final guarantee; comparing pattern `resultReadable` text needs Xcas-parseable normalization that is not worth the false positives yet.
  - Tests: `test/step_toolkit_test.dart` (every solve closes with a `Verification` step; boilerplate titles gone; honest `unavailable` on platforms without Giac) + existing `test/solver_isolate_test.dart`; `flutter analyze` clean (50 pre-existing infos, unchanged).
  - **On-device validation pending** — the Xcas verification commands only exist on Android; the local Windows run exercises the pattern path (`unavailable`) only.
- **[x] M2 · Biggest visual upgrade** — AST derivative engine with rule emission; rational display for fractions.
  - `lib/engine/symbolic.dart` — `SymbolicEngine` with a tiny AST (`NumEx`/`VarEx`/`FnEx`/`PowEx`/`AddEx`/`MulEx`), `Q` exact rationals, and a canonicalising `_Parser` + `_diff` that emit rule cards (Power/Sum/Product/Chain/Quotient/Trig/Log/Constant). Only the default pattern path runs when Giac is absent; with Giac as oracle, its result + `_verify` is the final value.
  - `test/symbolic_engine_test.dart` — 21 differentiation cases incl. `1/3*x^3 -> x^2`, `(x+1)/(x-1)` quotient, `e^(2x)` chain, out-of-grammar → null.
- **[x] M3 · Depth** — exact determinant/eigenvalues, Gauss-Jordan inverse trace, u-substitution integrals, L'Hôpital limits.
  - `lib/engine/matrix_algebra.dart` — `ExactMatrix` over `Q`: cofactor-expansion determinant with `2×2 / 3×3+` card traces, Gauss-Jordan inverse on `[A|I]` (Swap/Normalise pivot/Eliminate/Singular/Inverse read off cards), characteristic polynomial (ascending, 1×1..3×3) with exact roots (integers, fractions, reduced radicals, complex pairs, rational-root-theorem factoring for cubics), `eigenAnalysis(...)`.
  - `lib/engine/symbolic.dart` adds `integrate(expr)` and `limit(expr)` engines, both engine-first wired into `pattern_solver.dart` `_integral`/`_limit` (legacy fallback preserved), plus `_determinant`/`_matrixInverse`/`_eigenvalue` wired to `matrix_algebra.dart`. Definite integrals use `evaluateBounds` + `fmtValue` → real FTC Part 2 card. `pi`-bounded limits fold (`pi/2`, `3/2*pi`) and near-zero results snap to `0`.
  - Tests: `test/matrix_algebra_test.dart` (det 2×2/3×3/fractional/4×4, inverse + singular + 3×3, eigen sqrt/rational/repeated/complex/3×3) + 40 new `SymbolicEngine` integrate/limit cases. Full suite 65 tests green, `flutter analyze` 0 errors (59 pre-existing infos/warnings).
  - Engine-first wiring verified by `_determinant`/`_matrixInverse`/`_eigenvalue`/`_integral`/`_limit` in the pattern fallback; the giac-first `solve()` path still prefers Giac's value and appends the honest verification card.
- **[x] M4 · Fill gap topics** — Laplace/inverse Laplace via table transforms; literal `F(x,y,z)` parsing for vector calculus / line integrals / multiple integrals / partial derivatives; equation-solving strategies (factor → isolate → check, quadratic formula).
  - `lib/engine/pattern_solver.dart`:
    - `_laplaceCore` extends the Laplace table: linearity sums, scaling `k·f(t)`, `t^n e^{at}` / `t·e^{at}` (s-shift), `e^{at} sin/cos(ωt)`, `sinh/cosh(at)`; trig/hyperbolic rows tolerate the `3*t` form.
    - `_invLaplaceCore` extends the inverse table: constants `k/s`, `k/s^n` scaling, `k/(s²±ω²)` (now with the `k/ω` factor, fixing the old sine row that dropped `k`), `1/(s±a)^n`, s-shifted sine/cosine `((s±a)²+ω²)`, hyperbolic rows, linearity sums, and cover-up partial fractions for distinct real poles `N(s)/((s-p1)(s-p2))`.
    - `_solveEquation` + `solve(...)` dispatch: normalized to one side, `_polyCoeffs` extracts (a,b,c) handling `*`/bare terms, then linear isolate, quadratic via discriminant + perfect-square factor step + formula, complex-root case, contradictions, factored `(x-r1)(x-r2)=0` via zero-product, exact rational roots via `_fracQ`; word-parser inputs `roots of` / `solutions to` already route through `solve(...)`.
    - `_fnCall` parses literal `F(x,y,z)`; `_partialDerivative` (second-arg variable + keeps function name), `_multipleIntegral`, `_lineIntegral`, `_vectorCalculus` now echo the actual function/field in steps and results instead of generic `f`.
  - Tests: `test/m4_gap_test.dart` — 29 cases (solve linear/quadratic/factored/complex/none, Laplace table rows + linearity + s-shift, inverse table rows + partial fractions, F(x,y,z) parsing across partial/double/triple/gradient/div). Full suite 97 green; `flutter analyze` 0 errors.

### Topic coverage tiers (from the 26 dispatchers)

| Tier | Topics | Depth |
|---|---|---|
| Deep trace | derivative, integral, limit, determinant, matrixInverse, eigenvalue, series, taylor, newton, euler, ode | AST rule engine + exact rationals |
| Real per-input arithmetic | laplace, invLaplace, lineIntegral, multipleIntegral, partialDerivative, vectorCalculus, solve(...), normal(...) | table/definition-driven, one layer below AST |
| Verify + annotate | statistics, numberTheory, factorize, complex, trigonometry, fourierSeries | formula-based computation + verification step |
| Conceptual (no trace possible) | abstractAlgebra (`group(Z_n)`), topology (`topology(compact)`) | explanation cards + worked examples + verification step |

**Coverage claim:** nonzero, non-boilerplate steps for ~26/26 inputs; full math traces for ~16; intermediate depth for ~8; 2 stay conceptual-with-examples.

---

## Phase C — Proper graphing system (2D + 3D) `[x]`

User decision: rebuild the plotter into a real graphing system, including a 3D surface mode. Renderer is CustomPainter for both views; evaluation is Giac-first with a math_expressions fallback.

- `lib/engine/graph_evaluator.dart` — per-point evaluator: `eval2D(expr, x)` / `eval3D(expr, x, y)`. Giac path is `evalf(subst(...))`; fallback normalizes `e`/`pi`, implicit multiplication, then parses once per expression (cached). Returns `null` for undefined points.
- `lib/widgets/graph_2d.dart` — `Graph2DView`. Adaptive sampling (220 base cells + curvature refinement to depth 4), gap detection at discontinuities, pan + pinch-zoom, double-tap auto-fit, robust Y auto-fit (2% tail trim), 1-2-5 nice grid ticks + axis labels. Sampling runs off-thread via `compute(_sample2DEntry, _Sample2DRequest(...))`.
- `lib/widgets/graph_3d.dart` — `Graph3DView`. `z = f(x, y)` mesh (42×42 over `[-6, 6]²`), undefined cells skipped, drag-rotate + pinch-zoom, painter's-algorithm depth sort, height ramp `#4D4DA6 → #00E5AA` with normal-based shading, axes labels + height legend. Sampling off-thread via `compute(_sample3DEntry, _Sample3DRequest(...))`.
- `lib/widgets/function_grapher.dart` — reworked as a thin shell: 2D⇄3D toggle, per-mode presets, domain chips (2D only). Public API `FunctionGrapher` / `FunctionGrapher.show` unchanged, so `solver_screen.dart` is untouched.
- fl_chart is no longer used by the plotter (it was the only consumer); CustomPainter owns rendering. `math_expressions` stays for the fallback evaluator.

Resolves A1 (`e^x`, and any `e`-based expression). Also removes the UI jank from plotting by moving sampling off the main isolate (same philosophy as A2).

Status: implemented and `flutter analyze`-clean. On-device check done 2026-09-17 (SM-N9760): `e^x` preset plots, `2D ⇄ 3D` toggle works, 3D mesh + drag-rotate fine. Remaining eyeball items (shading quality, pinch-zoom feel, `1/x` gap detection) are cosmetic only. Note: isolate sampling relies on the A2 native mutex to keep Giac calls safe.

---

## Suggested execution order

1. ~~**Phase C** (graphing rework)~~ — done.
2. ~~**A2** (P1 jank) + native Giac mutex~~ — done (needs native rebuild).
3. ~~**A3 + A4** (P2/P3 cleanups)~~ — done.
4. ~~**M1** — step toolkit + verification everywhere; changes all topics, no math rewrite.~~ — done.
5. ~~**M2** — AST derivative engine.~~ — done.
6. ~~**M3** — matrices / integrals / limits depth.~~ — done.
7. ~~**M4** — gap topics + equation-solving.~~ — done.

---

## Out of scope (for reference, by design)
- License security is client-side-obscured + server-checked at activation; key lives in `secret_parts.dart`. Not hardening further unless requested.
- Offline-first positioning is preserved; all work above is on-device.