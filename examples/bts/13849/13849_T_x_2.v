(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.

(* Why3 assumption *)
Inductive t :=
  | T : t.
Axiom t_WhyType : WhyType t.
Existing Instance t_WhyType.

(* Why3 assumption *)
Inductive x (a:Type) (b:Type) :=
  | X : t -> a -> x a b
  | Y : t -> b -> x a b.
Axiom x_WhyType : forall (a:Type) {a_WT:WhyType a} (b:Type) {b_WT:WhyType b},
  WhyType (x a b).
Existing Instance x_WhyType.
Implicit Arguments X [[a] [b]].
Implicit Arguments Y [[a] [b]].

(* Why3 assumption *)
Inductive a1 :=
  | A0 : a1
  | A1 : a1.
Axiom a1_WhyType : WhyType a1.
Existing Instance a1_WhyType.

(* Why3 assumption *)
Inductive b :=
  | B : b.
Axiom b_WhyType : WhyType b.
Existing Instance b_WhyType.



(* Why3 goal *)
Theorem x1 : ((X T A0: (x a1 b)) = (X T A1: (x a1 b))).
(* YOU MAY EDIT THE PROOF BELOW *)
admit.
Admitted.

