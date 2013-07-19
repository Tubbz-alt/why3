(* This file is generated by Why3's Coq-realize driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require list.List.

(* Why3 assumption *)
Fixpoint mem {a:Type} {a_WT:WhyType a} (x:a) (l:(list a)) {struct l}: Prop :=
  match l with
  | nil => False
  | (cons y r) => (x = y) \/ (mem x r)
  end.


Lemma mem_std :
  forall {a:Type} {a_WT:WhyType a} (x:a) (l:list a),
  mem x l <-> List.In x l.
Proof.
intros a a_WT x l.
induction l as [|h q].
easy.
simpl.
split ; intros [H|H].
now left.
right.
now apply IHq.
now left.
right.
now apply IHq.
Qed.
