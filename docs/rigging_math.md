# Stage-Builder Rigging & Statics Math Reference

> **DISCLAIMER**: All calculations in Stage-Builder are **PLANNING AIDS ONLY**, not engineering sign-off or structural certification. Verify all rigging, loads, and ballasting with a certified structural engineer or licensed rigger before production. All catalog ratings are generic placeholder values.

---

## 1. Beam Statics: Simply Supported Truss Spans

A continuous run of modular truss between two vertical supports (towers, ground supports, or chain hoists) is modeled as a simply supported horizontal beam of span length $L$.

### 1.1 Support Reactions

For a span extending from support $A$ at position $x = 0$ to support $B$ at position $x = L$:
- **Uniform Distributed Load (UDL)** $w$ (kg/m), comprising the truss self-weight:
  $$w = \frac{\sum M_{\text{truss}}}{L}$$
- **Discrete Point Loads** $P_i$ (kg) located at positions $x_i \in [0, L]$, representing attached fixtures, audio cabinets, cables, or bridles.

The vertical reaction forces at the supports are determined by static equilibrium ($\sum F_y = 0$, $\sum M_A = 0$):

$$R_A = \sum_{i=1}^n P_i \left(\frac{L - x_i}{L}\right) + \frac{w L}{2}$$

$$R_B = \sum_{i=1}^n P_i \left(\frac{x_i}{L}\right) + \frac{w L}{2}$$

$$\sum F_y = R_A + R_B = \sum_{i=1}^n P_i + w L$$

---

### 1.2 Bending Moments & Center-Equivalent Load

1. **Mid-span moment from UDL**:
   $$M_{\text{udl}} = \frac{w L^2}{8}$$

2. **Moment from discrete point load $P_i$ at distance $x_i$**:
   $$M_i = P_i \frac{x_i (L - x_i)}{L}$$

3. **Center-Equivalent Point Load Transformation**:
   A single concentrated point load $P_{\text{center}}$ placed at the exact center ($x = L/2$) creates a bending moment of:
   $$M_{\text{center}} = \frac{P_{\text{center}} L}{4}$$
   Equating moments gives the equivalent center load for any arbitrary point load and the self-weight UDL:
   $$P_{\text{equiv}, i} = P_i \frac{4 x_i (L - x_i)}{L^2}$$
   $$P_{\text{equiv, udl}} = \frac{w L}{2}$$
   $$P_{\text{total, equiv}} = \frac{w L}{2} + \sum_{i=1}^n P_i \frac{4 x_i (L - x_i)}{L^2}$$

---

### 1.3 Span Rating Interpolation & Utilization

Given a truss manufacturer rating table for span $L$:
- $P_{\text{allow}}(L)$: Allowable concentrated center point load (kg)
- $w_{\text{allow}}(L)$: Allowable uniform distributed load (kg/m)

For an arbitrary span $L$ between defined table points $L_1$ and $L_2$ ($L_1 \le L \le L_2$):
$$t = \frac{L - L_1}{L_2 - L_1}$$
$$P_{\text{allow}}(L) = (1 - t) P_{\text{allow}}(L_1) + t P_{\text{allow}}(L_2)$$
$$w_{\text{allow}}(L) = (1 - t) w_{\text{allow}}(L_1) + t w_{\text{allow}}(L_2)$$

The beam bending utilization is:
$$\text{Utilization} = \frac{P_{\text{total, equiv}}}{P_{\text{allow}}(L)}$$

---

## 2. Hoists, Shackles & Rigging Hardware

The Safe Working Load (SWL) of hardware is subject to a configurable Safety Factor ($SF$):
- **Static Hangs (Spansets, Shackles, Beam Clamps)**: Default $SF = 1.5$
- **Electric Chain Hoists / Motors**: Default $SF = 5.0$

$$\text{Allowable Load} = \frac{\text{SWL}}{SF}$$
$$\text{Hardware Utilization} = \frac{\text{Applied Load}}{\text{Allowable Load}} = \frac{\text{Applied Load} \times SF}{\text{SWL}}$$

---

## 3. Support Towers & Ground Columns

For vertical ground supports (towers, base plates, scaffolding legs):
- Total vertical downward load $F_{\text{vertical}}$ is the sum of transferred truss reactions $R$ plus support self-weight $M_{\text{support}}$.
- Rated capacity: $F_{\text{max, vert}}$

$$\text{Tower Utilization} = \frac{F_{\text{vertical}}}{F_{\text{max, vert}}}$$

---

## 4. Hand-Calculated Reference Benchmarks

These analytical solutions serve as ground-truth test references:

### Reference Case 1: Centered Point Load on 6m F34 Box Truss
- Span $L = 6.0\,\text{m}$, Self-weight $w = 6.0\,\text{kg/m}$ (total truss self-weight $36.0\,\text{kg}$).
- Point load $P_1 = 300.0\,\text{kg}$ at $x_1 = 3.0\,\text{m}$.
- **Reactions**:
  $$R_A = 300.0 \times \left(\frac{6.0 - 3.0}{6.0}\right) + \frac{6.0 \times 6.0}{2} = 150.0 + 18.0 = 168.0\,\text{kg}$$
  $$R_B = 300.0 \times \left(\frac{3.0}{6.0}\right) + 18.0 = 150.0 + 18.0 = 168.0\,\text{kg}$$
- **Total Load**: $168.0 + 168.0 = 336.0\,\text{kg}$.
- **Center-Equivalent Load**:
  $$P_{\text{equiv}, 1} = 300.0 \times \frac{4 \times 3.0 \times 3.0}{36.0} = 300.0\,\text{kg}$$
  $$P_{\text{equiv, udl}} = \frac{6.0 \times 6.0}{2} = 18.0\,\text{kg}$$
  $$P_{\text{total, equiv}} = 300.0 + 18.0 = 318.0\,\text{kg}$$
- **Rating (from F34 Table at 6m)**: $P_{\text{allow}} = 460.0\,\text{kg}$.
- **Utilization**: $\frac{318.0}{460.0} = 69.13\%$.

### Reference Case 2: Asymmetric Two-Point Load on 8m F34 Truss
- Span $L = 8.0\,\text{m}$, $w = 6.0\,\text{kg/m}$ ($48.0\,\text{kg}$ self-weight).
- $P_1 = 120.0\,\text{kg}$ at $x_1 = 2.0\,\text{m}$.
- $P_2 = 180.0\,\text{kg}$ at $x_2 = 6.0\,\text{m}$.
- **Reactions**:
  $$R_A = 120 \times \left(\frac{8 - 2}{8}\right) + 180 \times \left(\frac{8 - 6}{8}\right) + \frac{6 \times 8}{2} = 120 \times 0.75 + 180 \times 0.25 + 24 = 90 + 45 + 24 = 159.0\,\text{kg}$$
  $$R_B = 120 \times \left(\frac{2}{8}\right) + 180 \times \left(\frac{6}{8}\right) + 24 = 120 \times 0.25 + 180 \times 0.75 + 24 = 30 + 135 + 24 = 189.0\,\text{kg}$$
- **Total Load**: $159.0 + 189.0 = 348.0\,\text{kg} = 120 + 180 + 48$. Correct.
- **Center-Equivalent Load**:
  $$P_{\text{equiv}, 1} = 120 \times \frac{4 \times 2 \times 6}{64} = 120 \times \frac{48}{64} = 90.0\,\text{kg}$$
  $$P_{\text{equiv}, 2} = 180 \times \frac{4 \times 6 \times 2}{64} = 180 \times \frac{48}{64} = 135.0\,\text{kg}$$
  $$P_{\text{equiv, udl}} = \frac{6 \times 8}{2} = 24.0\,\text{kg}$$
  $$P_{\text{total, equiv}} = 90.0 + 135.0 + 24.0 = 249.0\,\text{kg}$$
- **Rating (from F34 Table at 8m)**: $P_{\text{allow}} = 340.0\,\text{kg}$.
- **Utilization**: $\frac{249.0}{340.0} = 73.24\%$.

### Reference Case 3: 1t Hoist Utilization
- Carried reaction $R = 650.0\,\text{kg}$.
- Hoist rated $\text{SWL} = 1000.0\,\text{kg}$, dynamic safety factor $SF = 1.0$ (direct SWL comparison):
  $$\text{Utilization} = \frac{650.0}{1000.0} = 65.0\%$$
- With motor safety factor $SF = 1.25$:
  $$\text{Utilization} = \frac{650.0 \times 1.25}{1000.0} = 81.25\%$$

---

## 5. Unit Conversion Standard

- **Internal Base**: Kilograms ($\text{kg}$) for mass/force, Meters ($\text{m}$) for length.
- **Standard Gravity**: $g = 9.80665\,\text{m/s}^2$
- **Kilonewtons ($\text{kN}$)**:
  $$F_{\text{kN}} = \frac{M_{\text{kg}} \times 9.80665}{1000.0}$$
  $$1\,\text{kN} = 101.9716\,\text{kg}$$
- **Pounds Force / Mass ($\text{lb}$)**:
  $$M_{\text{lb}} = M_{\text{kg}} \times 2.2046226$$
  $$1\,\text{kg} \approx 2.20462\,\text{lb}$$

