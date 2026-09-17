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
- **[ ] M2 · Biggest visual upgrade** — AST derivative engine with rule emission; rational display for fractions.
- **[ ] M3 · Depth** — real Gauss-Jordan trace for matrix inverse, exact determinant/eigenvalues, u-substitution integrals, L'Hôpital limits.
- **[ ] M4 · Fill gap topics** — Laplace/inverse Laplace via table transforms; literal `F(x,y,z)` parsing for vector calculus / line integrals / multiple integrals / partial derivatives; equation-solving strategies (factor → isolate → check, quadratic formula).

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
4. **M1** — step toolkit + verification everywhere; changes all topics, no math rewrite.
5. **M2** — AST derivative engine.
6. **M3** — matrices / integrals / limits depth.
7. **M4** — gap topics + equation-solving.

---

## Out of scope (for reference, by design)
- License security is client-side-obscured + server-checked at activation; key lives in `secret_parts.dart`. Not hardening further unless requested.
- Offline-first positioning is preserved; all work above is on-device.