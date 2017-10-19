(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require HighOrd.
Require int.Int.
Require map.Map.
Require bool.Bool.
Require list.List.
Require list.Length.
Require list.Mem.
Require list.Append.

(* Why3 assumption *)
Inductive datatype :=
  | TYunit : datatype
  | TYint : datatype
  | TYbool : datatype.
Axiom datatype_WhyType : WhyType datatype.
Existing Instance datatype_WhyType.

(* Why3 assumption *)
Inductive value :=
  | Vvoid : value
  | Vint : Z -> value
  | Vbool : bool -> value.
Axiom value_WhyType : WhyType value.
Existing Instance value_WhyType.

(* Why3 assumption *)
Inductive operator :=
  | Oplus : operator
  | Ominus : operator
  | Omult : operator
  | Ole : operator.
Axiom operator_WhyType : WhyType operator.
Existing Instance operator_WhyType.

Axiom mident : Type.
Parameter mident_WhyType : WhyType mident.
Existing Instance mident_WhyType.

Axiom mident_decide : forall (m1:mident) (m2:mident), (m1 = m2) \/
  ~ (m1 = m2).

Axiom ident : Type.
Parameter ident_WhyType : WhyType ident.
Existing Instance ident_WhyType.

Axiom ident_decide : forall (m1:ident) (m2:ident), (m1 = m2) \/ ~ (m1 = m2).

(* Why3 assumption *)
Inductive term :=
  | Tvalue : value -> term
  | Tvar : ident -> term
  | Tderef : mident -> term
  | Tbin : term -> operator -> term -> term.
Axiom term_WhyType : WhyType term.
Existing Instance term_WhyType.

(* Why3 assumption *)
Inductive fmla :=
  | Fterm : term -> fmla
  | Fand : fmla -> fmla -> fmla
  | Fnot : fmla -> fmla
  | Fimplies : fmla -> fmla -> fmla
  | Flet : ident -> term -> fmla -> fmla
  | Fforall : ident -> datatype -> fmla -> fmla.
Axiom fmla_WhyType : WhyType fmla.
Existing Instance fmla_WhyType.

(* Why3 assumption *)
Inductive stmt :=
  | Sskip : stmt
  | Sassign : mident -> term -> stmt
  | Sseq : stmt -> stmt -> stmt
  | Sif : term -> stmt -> stmt -> stmt
  | Sassert : fmla -> stmt
  | Swhile : term -> fmla -> stmt -> stmt.
Axiom stmt_WhyType : WhyType stmt.
Existing Instance stmt_WhyType.

Axiom decide_is_skip : forall (s:stmt), (s = Sskip) \/ ~ (s = Sskip).

(* Why3 assumption *)
Definition env := (mident -> value).

(* Why3 assumption *)
Definition stack := (list (ident* value)%type).

Parameter get_stack: ident -> (list (ident* value)%type) -> value.

Axiom get_stack_def : forall (i:ident) (pi:(list (ident* value)%type)),
  match pi with
  | Init.Datatypes.nil => ((get_stack i pi) = Vvoid)
  | (Init.Datatypes.cons (x, v) r) => ((x = i) -> ((get_stack i pi) = v)) /\
      ((~ (x = i)) -> ((get_stack i pi) = (get_stack i r)))
  end.

Axiom get_stack_eq : forall (x:ident) (v:value) (r:(list (ident*
  value)%type)), ((get_stack x (Init.Datatypes.cons (x, v) r)) = v).

Axiom get_stack_neq : forall (x:ident) (i:ident) (v:value) (r:(list (ident*
  value)%type)), (~ (x = i)) -> ((get_stack i (Init.Datatypes.cons (x,
  v) r)) = (get_stack i r)).

Parameter eval_bin: value -> operator -> value -> value.

Axiom eval_bin_def : forall (x:value) (op:operator) (y:value), match (x,
  y) with
  | ((Vint x1), (Vint y1)) =>
      match op with
      | Oplus => ((eval_bin x op y) = (Vint (x1 + y1)%Z))
      | Ominus => ((eval_bin x op y) = (Vint (x1 - y1)%Z))
      | Omult => ((eval_bin x op y) = (Vint (x1 * y1)%Z))
      | Ole => ((x1 <= y1)%Z -> ((eval_bin x op y) = (Vbool true))) /\
          ((~ (x1 <= y1)%Z) -> ((eval_bin x op y) = (Vbool false)))
      end
  | (_, _) => ((eval_bin x op y) = Vvoid)
  end.

(* Why3 assumption *)
Fixpoint eval_term (sigma:(mident -> value)) (pi:(list (ident* value)%type))
  (t:term) {struct t}: value :=
  match t with
  | (Tvalue v) => v
  | (Tvar id) => (get_stack id pi)
  | (Tderef id) => (sigma id)
  | (Tbin t1 op t2) => (eval_bin (eval_term sigma pi t1) op (eval_term sigma
      pi t2))
  end.

(* Why3 assumption *)
Fixpoint eval_fmla (sigma:(mident -> value)) (pi:(list (ident* value)%type))
  (f:fmla) {struct f}: Prop :=
  match f with
  | (Fterm t) => ((eval_term sigma pi t) = (Vbool true))
  | (Fand f1 f2) => (eval_fmla sigma pi f1) /\ (eval_fmla sigma pi f2)
  | (Fnot f1) => ~ (eval_fmla sigma pi f1)
  | (Fimplies f1 f2) => (eval_fmla sigma pi f1) -> (eval_fmla sigma pi f2)
  | (Flet x t f1) => (eval_fmla sigma (Init.Datatypes.cons (x,
      (eval_term sigma pi t)) pi) f1)
  | (Fforall x TYint f1) => forall (n:Z), (eval_fmla sigma
      (Init.Datatypes.cons (x, (Vint n)) pi) f1)
  | (Fforall x TYbool f1) => forall (b:bool), (eval_fmla sigma
      (Init.Datatypes.cons (x, (Vbool b)) pi) f1)
  | (Fforall x TYunit f1) => (eval_fmla sigma (Init.Datatypes.cons (x,
      Vvoid) pi) f1)
  end.

(* Why3 assumption *)
Definition valid_fmla (p:fmla): Prop := forall (sigma:(mident -> value))
  (pi:(list (ident* value)%type)), (eval_fmla sigma pi p).

(* Why3 assumption *)
Inductive one_step: (mident -> value) -> (list (ident* value)%type) ->
  stmt -> (mident -> value) -> (list (ident* value)%type) -> stmt -> Prop :=
  | one_step_assign : forall (sigma:(mident -> value)) (sigma':(mident ->
      value)) (pi:(list (ident* value)%type)) (x:mident) (t:term),
      (sigma' = (map.Map.set sigma x (eval_term sigma pi t))) -> (one_step
      sigma pi (Sassign x t) sigma' pi Sskip)
  | one_step_seq_noskip : forall (sigma:(mident -> value)) (sigma':(mident ->
      value)) (pi:(list (ident* value)%type)) (pi':(list (ident*
      value)%type)) (s1:stmt) (s1':stmt) (s2:stmt), (one_step sigma pi s1
      sigma' pi' s1') -> (one_step sigma pi (Sseq s1 s2) sigma' pi' (Sseq s1'
      s2))
  | one_step_seq_skip : forall (sigma:(mident -> value)) (pi:(list (ident*
      value)%type)) (s:stmt), (one_step sigma pi (Sseq Sskip s) sigma pi s)
  | one_step_if_true : forall (sigma:(mident -> value)) (pi:(list (ident*
      value)%type)) (t:term) (s1:stmt) (s2:stmt), ((eval_term sigma pi
      t) = (Vbool true)) -> (one_step sigma pi (Sif t s1 s2) sigma pi s1)
  | one_step_if_false : forall (sigma:(mident -> value)) (pi:(list (ident*
      value)%type)) (t:term) (s1:stmt) (s2:stmt), ((eval_term sigma pi
      t) = (Vbool false)) -> (one_step sigma pi (Sif t s1 s2) sigma pi s2)
  | one_step_assert : forall (sigma:(mident -> value)) (pi:(list (ident*
      value)%type)) (f:fmla), (eval_fmla sigma pi f) -> (one_step sigma pi
      (Sassert f) sigma pi Sskip)
  | one_step_while_true : forall (sigma:(mident -> value)) (pi:(list (ident*
      value)%type)) (cond:term) (inv:fmla) (body:stmt), ((eval_fmla sigma pi
      inv) /\ ((eval_term sigma pi cond) = (Vbool true))) -> (one_step sigma
      pi (Swhile cond inv body) sigma pi (Sseq body (Swhile cond inv body)))
  | one_step_while_false : forall (sigma:(mident -> value)) (pi:(list (ident*
      value)%type)) (cond:term) (inv:fmla) (body:stmt), ((eval_fmla sigma pi
      inv) /\ ((eval_term sigma pi cond) = (Vbool false))) -> (one_step sigma
      pi (Swhile cond inv body) sigma pi Sskip).

(* Why3 assumption *)
Inductive many_steps: (mident -> value) -> (list (ident* value)%type) ->
  stmt -> (mident -> value) -> (list (ident* value)%type) -> stmt -> Z ->
  Prop :=
  | many_steps_refl : forall (sigma:(mident -> value)) (pi:(list (ident*
      value)%type)) (s:stmt), (many_steps sigma pi s sigma pi s 0%Z)
  | many_steps_trans : forall (sigma1:(mident -> value)) (sigma2:(mident ->
      value)) (sigma3:(mident -> value)) (pi1:(list (ident* value)%type))
      (pi2:(list (ident* value)%type)) (pi3:(list (ident* value)%type))
      (s1:stmt) (s2:stmt) (s3:stmt) (n:Z), (one_step sigma1 pi1 s1 sigma2 pi2
      s2) -> ((many_steps sigma2 pi2 s2 sigma3 pi3 s3 n) -> (many_steps
      sigma1 pi1 s1 sigma3 pi3 s3 (n + 1%Z)%Z)).

Axiom steps_non_neg : forall (sigma1:(mident -> value)) (sigma2:(mident ->
  value)) (pi1:(list (ident* value)%type)) (pi2:(list (ident* value)%type))
  (s1:stmt) (s2:stmt) (n:Z), (many_steps sigma1 pi1 s1 sigma2 pi2 s2 n) ->
  (0%Z <= n)%Z.

(* Why3 assumption *)
Definition reductible (sigma:(mident -> value)) (pi:(list (ident*
  value)%type)) (s:stmt): Prop := exists sigma':(mident -> value),
  exists pi':(list (ident* value)%type), exists s':stmt, (one_step sigma pi s
  sigma' pi' s').

Axiom Cons_append : forall {a:Type} {a_WT:WhyType a}, forall (a1:a)
  (l1:(list a)) (l2:(list a)),
  ((Init.Datatypes.cons a1 (Init.Datatypes.app l1 l2)) = (Init.Datatypes.app (Init.Datatypes.cons a1 l1) l2)).

Axiom Append_nil_l : forall {a:Type} {a_WT:WhyType a}, forall (l:(list a)),
  ((Init.Datatypes.app Init.Datatypes.nil l) = l).

Parameter msubst_term: term -> mident -> ident -> term.

Axiom msubst_term_def : forall (t:term) (x:mident) (v:ident),
  match t with
  | ((Tvalue _)|(Tvar _)) => ((msubst_term t x v) = t)
  | (Tderef y) => ((x = y) -> ((msubst_term t x v) = (Tvar v))) /\
      ((~ (x = y)) -> ((msubst_term t x v) = t))
  | (Tbin t1 op t2) => ((msubst_term t x v) = (Tbin (msubst_term t1 x v) op
      (msubst_term t2 x v)))
  end.

(* Why3 assumption *)
Fixpoint msubst (f:fmla) (x:mident) (v:ident) {struct f}: fmla :=
  match f with
  | (Fterm e) => (Fterm (msubst_term e x v))
  | (Fand f1 f2) => (Fand (msubst f1 x v) (msubst f2 x v))
  | (Fnot f1) => (Fnot (msubst f1 x v))
  | (Fimplies f1 f2) => (Fimplies (msubst f1 x v) (msubst f2 x v))
  | (Flet y t f1) => (Flet y (msubst_term t x v) (msubst f1 x v))
  | (Fforall y ty f1) => (Fforall y ty (msubst f1 x v))
  end.

(* Why3 assumption *)
Fixpoint fresh_in_term (id:ident) (t:term) {struct t}: Prop :=
  match t with
  | ((Tvalue _)|(Tderef _)) => True
  | (Tvar i) => ~ (id = i)
  | (Tbin t1 _ t2) => (fresh_in_term id t1) /\ (fresh_in_term id t2)
  end.

(* Why3 assumption *)
Fixpoint fresh_in_fmla (id:ident) (f:fmla) {struct f}: Prop :=
  match f with
  | (Fterm e) => (fresh_in_term id e)
  | ((Fand f1 f2)|(Fimplies f1 f2)) => (fresh_in_fmla id f1) /\
      (fresh_in_fmla id f2)
  | (Fnot f1) => (fresh_in_fmla id f1)
  | (Flet y t f1) => (~ (id = y)) /\ ((fresh_in_term id t) /\ (fresh_in_fmla
      id f1))
  | (Fforall y _ f1) => (~ (id = y)) /\ (fresh_in_fmla id f1)
  end.

Axiom eval_msubst_term : forall (e:term) (sigma:(mident -> value))
  (pi:(list (ident* value)%type)) (x:mident) (v:ident), (fresh_in_term v
  e) -> ((eval_term sigma pi (msubst_term e x
  v)) = (eval_term (map.Map.set sigma x (get_stack v pi)) pi e)).

Axiom eval_msubst : forall (f:fmla) (sigma:(mident -> value))
  (pi:(list (ident* value)%type)) (x:mident) (v:ident), (fresh_in_fmla v
  f) -> ((eval_fmla sigma pi (msubst f x v)) <-> (eval_fmla
  (map.Map.set sigma x (get_stack v pi)) pi f)).

Axiom eval_swap_term : forall (t:term) (sigma:(mident -> value))
  (pi:(list (ident* value)%type)) (l:(list (ident* value)%type)) (id1:ident)
  (id2:ident) (v1:value) (v2:value), (~ (id1 = id2)) -> ((eval_term sigma
  (Init.Datatypes.app l (Init.Datatypes.cons (id1, v1) (Init.Datatypes.cons (
  id2, v2) pi))) t) = (eval_term sigma
  (Init.Datatypes.app l (Init.Datatypes.cons (id2, v2) (Init.Datatypes.cons (
  id1, v1) pi))) t)).

Axiom eval_swap_gen : forall (f:fmla) (sigma:(mident -> value))
  (pi:(list (ident* value)%type)) (l:(list (ident* value)%type)) (id1:ident)
  (id2:ident) (v1:value) (v2:value), (~ (id1 = id2)) -> ((eval_fmla sigma
  (Init.Datatypes.app l (Init.Datatypes.cons (id1, v1) (Init.Datatypes.cons (
  id2, v2) pi))) f) <-> (eval_fmla sigma
  (Init.Datatypes.app l (Init.Datatypes.cons (id2, v2) (Init.Datatypes.cons (
  id1, v1) pi))) f)).

Axiom eval_swap : forall (f:fmla) (sigma:(mident -> value)) (pi:(list (ident*
  value)%type)) (id1:ident) (id2:ident) (v1:value) (v2:value),
  (~ (id1 = id2)) -> ((eval_fmla sigma (Init.Datatypes.cons (id1,
  v1) (Init.Datatypes.cons (id2, v2) pi)) f) <-> (eval_fmla sigma
  (Init.Datatypes.cons (id2, v2) (Init.Datatypes.cons (id1, v1) pi)) f)).

Axiom eval_term_change_free : forall (t:term) (sigma:(mident -> value))
  (pi:(list (ident* value)%type)) (id:ident) (v:value), (fresh_in_term id
  t) -> ((eval_term sigma (Init.Datatypes.cons (id, v) pi)
  t) = (eval_term sigma pi t)).

Axiom eval_change_free : forall (f:fmla) (sigma:(mident -> value))
  (pi:(list (ident* value)%type)) (id:ident) (v:value), (fresh_in_fmla id
  f) -> ((eval_fmla sigma (Init.Datatypes.cons (id, v) pi) f) <-> (eval_fmla
  sigma pi f)).

Require Import Why3.
Ltac ae := why3 "Alt-Ergo,1.30," timelimit 3; admit.

(* Why3 goal *)
Theorem many_steps_seq : forall (sigma1:(mident -> value)) (sigma3:(mident ->
  value)) (pi1:(list (ident* value)%type)) (pi3:(list (ident* value)%type))
  (s1:stmt) (s2:stmt) (n:Z), (many_steps sigma1 pi1 (Sseq s1 s2) sigma3 pi3
  Sskip n) -> exists sigma2:(mident -> value), exists pi2:(list (ident*
  value)%type), exists n1:Z, exists n2:Z, (many_steps sigma1 pi1 s1 sigma2
  pi2 Sskip n1) /\ ((many_steps sigma2 pi2 s2 sigma3 pi3 Sskip n2) /\
  (n = ((1%Z + n1)%Z + n2)%Z)).
(* Why3 intros sigma1 sigma3 pi1 pi3 s1 s2 n h1. *)
intros sigma1 sigma3 pi1 pi3 s1 s2 n Hred.
generalize Hred.
generalize (steps_non_neg _ _ _ _ _ _ _ Hred).
clear Hred.
intros H.
generalize sigma1 pi1 s1; clear sigma1 pi1 s1.
pattern n; apply Z_lt_induction; auto.
intros.
inversion Hred; subst; clear Hred.
inversion H1; subst; clear H1.
(* case s1 <> Sskip *)
assert (h:(0 <= n0 < n0+1)%Z).
  generalize (steps_non_neg _ _ _ _ _ _ _ H2); omega.
generalize (H0 n0 h _ _ _ H2).
intros (s4 & p4 & n4 & n5 & h1 & h2 & h3).
exists s4.
exists p4.
exists (n4+1)%Z.
exists n5.
ae.

(* case s1 = Sskip *)
exists sigma2.
exists pi2.
exists 0%Z.
exists n0.
ae.
Admitted.

