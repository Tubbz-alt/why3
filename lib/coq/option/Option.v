(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2015   --   INRIA - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

(* This file is generated by Why3's Coq-realize driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.

Global Instance option_WhyType : forall T {T_WT : WhyType T}, WhyType (option T).
split.
apply @None.
intros [x|] [y|] ; try (now right) ; try (now left).
destruct (why_decidable_eq x y) as [E|E].
left.
now apply f_equal.
right.
contradict E.
now injection E.
Qed.
