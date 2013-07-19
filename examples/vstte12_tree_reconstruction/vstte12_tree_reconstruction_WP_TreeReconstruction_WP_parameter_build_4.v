(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require list.List.
Require list.Length.
Require list.Mem.
Require list.Append.

(* Why3 assumption *)
Definition unit := unit.

(* Why3 assumption *)
Inductive tree :=
  | Leaf : tree
  | Node : tree -> tree -> tree.
Axiom tree_WhyType : WhyType tree.
Existing Instance tree_WhyType.

(* Why3 assumption *)
Fixpoint depths (d:Z) (t:tree) {struct t}: (list Z) :=
  match t with
  | Leaf => (cons d nil)
  | (Node l r) => (List.app (depths (d + 1%Z)%Z l) (depths (d + 1%Z)%Z r))
  end.

Axiom depths_head : forall (t:tree) (d:Z), match (depths d
  t) with
  | (cons x _) => (d <= x)%Z
  | nil => False
  end.

Axiom depths_unique : forall (t1:tree) (t2:tree) (d:Z) (s1:(list Z))
  (s2:(list Z)), ((List.app (depths d t1) s1) = (List.app (depths d
  t2) s2)) -> ((t1 = t2) /\ (s1 = s2)).

Axiom depths_prefix : forall (t:tree) (d1:Z) (d2:Z) (s1:(list Z))
  (s2:(list Z)), ((List.app (depths d1 t) s1) = (List.app (depths d2
  t) s2)) -> (d1 = d2).

Axiom depths_prefix_simple : forall (t:tree) (d1:Z) (d2:Z), ((depths d1
  t) = (depths d2 t)) -> (d1 = d2).

Axiom depths_subtree : forall (t1:tree) (t2:tree) (d1:Z) (d2:Z)
  (s1:(list Z)), ((List.app (depths d1 t1) s1) = (depths d2 t2)) ->
  (d2 <= d1)%Z.

Axiom depths_unique2 : forall (t1:tree) (t2:tree) (d1:Z) (d2:Z), ((depths d1
  t1) = (depths d2 t2)) -> ((d1 = d2) /\ (t1 = t2)).

(* Why3 assumption *)
Definition lex (x1:((list Z)* Z)%type) (x2:((list Z)* Z)%type): Prop :=
  match x1 with
  | (s1, d1) =>
      match x2 with
      | (s2, d2) => ((list.Length.length s1) < (list.Length.length s2))%Z \/
          (((list.Length.length s1) = (list.Length.length s2)) /\ match (s1,
          s2) with
          | ((cons h1 _), (cons h2 _)) => ((d2 < d1)%Z /\ (d1 <= h1)%Z) /\
              (h1 = h2)
          | _ => False
          end)
      end
  end.


(* Why3 goal *)
Theorem WP_parameter_build : forall (s:(list Z)), (forall (t:tree)
  (s':(list Z)), ~ ((List.app (depths 0%Z t) s') = s)) -> forall (t:tree),
  ~ ((depths 0%Z t) = s).
(* Why3 intros s h1 t. *)
intuition.
replace (depths 0 t) with (app (depths 0 t) nil) in H0.
apply (H _ _ H0).
apply Append.Append_l_nil.
Qed.


