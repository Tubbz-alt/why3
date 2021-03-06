(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require Reals.Rbasic_fun.
Require Reals.R_sqrt.
Require Reals.Rtrigo_def.
Require Reals.Rtrigo1.
Require Reals.Ratan.
Require BuiltIn.
Require real.Real.
Require real.Abs.
Require real.FromInt.
Require int.Int.
Require real.Square.
Require real.Trigonometry.

Require Import Interval.Interval_tactic.

(* Why3 assumption *)
Inductive mode :=
  | NearestTiesToEven : mode
  | ToZero : mode
  | Up : mode
  | Down : mode
  | NearestTiesToAway : mode.
Axiom mode_WhyType : WhyType mode.
Existing Instance mode_WhyType.

Axiom single : Type.
Parameter single_WhyType : WhyType single.
Existing Instance single_WhyType.

Parameter round: mode -> R -> R.

Parameter value: single -> R.

Parameter exact: single -> R.

Parameter model: single -> R.

(* Why3 assumption *)
Definition round_error (x:single): R :=
  (Reals.Rbasic_fun.Rabs ((value x) - (exact x))%R).

(* Why3 assumption *)
Definition total_error (x:single): R :=
  (Reals.Rbasic_fun.Rabs ((value x) - (model x))%R).

(* Why3 assumption *)
Definition no_overflow (m:mode) (x:R): Prop :=
  ((Reals.Rbasic_fun.Rabs (round m
  x)) <= (33554430 * 10141204801825835211973625643008)%R)%R.

Axiom Bounded_real_no_overflow : forall (m:mode) (x:R),
  ((Reals.Rbasic_fun.Rabs x) <= (33554430 * 10141204801825835211973625643008)%R)%R ->
  (no_overflow m x).

Axiom Round_monotonic : forall (m:mode) (x:R) (y:R), (x <= y)%R -> ((round m
  x) <= (round m y))%R.

Axiom Round_idempotent : forall (m1:mode) (m2:mode) (x:R), ((round m1
  (round m2 x)) = (round m2 x)).

Axiom Round_value : forall (m:mode) (x:single), ((round m
  (value x)) = (value x)).

Axiom Bounded_value : forall (x:single),
  ((Reals.Rbasic_fun.Rabs (value x)) <= (33554430 * 10141204801825835211973625643008)%R)%R.

Axiom Exact_rounding_for_integers : forall (m:mode) (i:Z),
  (((-16777216%Z)%Z <= i)%Z /\ (i <= 16777216%Z)%Z) -> ((round m
  (Reals.Raxioms.IZR i)) = (Reals.Raxioms.IZR i)).

Axiom Round_down_le : forall (x:R), ((round Down x) <= x)%R.

Axiom Round_up_ge : forall (x:R), (x <= (round Up x))%R.

Axiom Round_down_neg : forall (x:R), ((round Down (-x)%R) = (-(round Up
  x))%R).

Axiom Round_up_neg : forall (x:R), ((round Up (-x)%R) = (-(round Down x))%R).

Parameter round_logic: mode -> R -> single.

Axiom Round_logic_def : forall (m:mode) (x:R), (no_overflow m x) ->
  ((value (round_logic m x)) = (round m x)).

(* Why3 assumption *)
Definition of_real_post (m:mode) (x:R) (res:single): Prop :=
  ((value res) = (round m x)) /\ (((exact res) = x) /\ ((model res) = x)).

(* Why3 assumption *)
Definition add_post (m:mode) (x:single) (y:single) (res:single): Prop :=
  ((value res) = (round m ((value x) + (value y))%R)) /\
  (((exact res) = ((exact x) + (exact y))%R) /\
  ((model res) = ((model x) + (model y))%R)).

(* Why3 assumption *)
Definition sub_post (m:mode) (x:single) (y:single) (res:single): Prop :=
  ((value res) = (round m ((value x) - (value y))%R)) /\
  (((exact res) = ((exact x) - (exact y))%R) /\
  ((model res) = ((model x) - (model y))%R)).

(* Why3 assumption *)
Definition mul_post (m:mode) (x:single) (y:single) (res:single): Prop :=
  ((value res) = (round m ((value x) * (value y))%R)) /\
  (((exact res) = ((exact x) * (exact y))%R) /\
  ((model res) = ((model x) * (model y))%R)).

(* Why3 assumption *)
Definition div_post (m:mode) (x:single) (y:single) (res:single): Prop :=
  ((value res) = (round m ((value x) / (value y))%R)) /\
  (((exact res) = ((exact x) / (exact y))%R) /\
  ((model res) = ((model x) / (model y))%R)).

(* Why3 assumption *)
Definition neg_post (x:single) (res:single): Prop :=
  ((value res) = (-(value x))%R) /\ (((exact res) = (-(exact x))%R) /\
  ((model res) = (-(model x))%R)).

(* Why3 assumption *)
Definition lt (x:single) (y:single): Prop := ((value x) < (value y))%R.

(* Why3 assumption *)
Definition gt (x:single) (y:single): Prop := ((value y) < (value x))%R.


(* Why3 goal *)
Theorem MethodError : forall (x:R),
  ((Reals.Rbasic_fun.Rabs x) <= (1 / 32)%R)%R ->
  ((Reals.Rbasic_fun.Rabs ((1%R - ((05 / 10)%R * (x * x)%R)%R)%R - (Reals.Rtrigo_def.cos x))%R) <= (1 / 16777216)%R)%R.
(* Why3 intros x h1. *)
(* YOU MAY EDIT THE PROOF BELOW *)
intros x H.
interval with (i_bisect_diff x).
Qed.

