(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require bool.Bool.
Require map.Map.
Require set.Set.

(* Why3 assumption *)
Definition unit := unit.

Axiom qtmark : Type.
Parameter qtmark_WhyType : WhyType qtmark.
Existing Instance qtmark_WhyType.

(* Why3 assumption *)
Inductive datatype :=
  | Tint : datatype
  | Tbool : datatype.
Axiom datatype_WhyType : WhyType datatype.
Existing Instance datatype_WhyType.

(* Why3 assumption *)
Inductive operator :=
  | Oplus : operator
  | Ominus : operator
  | Omult : operator
  | Ole : operator.
Axiom operator_WhyType : WhyType operator.
Existing Instance operator_WhyType.

(* Why3 assumption *)
Definition ident := Z.

(* Why3 assumption *)
Inductive term :=
  | Tconst : Z -> term
  | Tvar : Z -> term
  | Tderef : Z -> term
  | Tbin : term -> operator -> term -> term.
Axiom term_WhyType : WhyType term.
Existing Instance term_WhyType.

(* Why3 assumption *)
Inductive fmla :=
  | Fterm : term -> fmla
  | Fand : fmla -> fmla -> fmla
  | Fnot : fmla -> fmla
  | Fimplies : fmla -> fmla -> fmla
  | Flet : Z -> term -> fmla -> fmla
  | Fforall : Z -> datatype -> fmla -> fmla.
Axiom fmla_WhyType : WhyType fmla.
Existing Instance fmla_WhyType.

(* Why3 assumption *)
Inductive value :=
  | Vint : Z -> value
  | Vbool : bool -> value.
Axiom value_WhyType : WhyType value.
Existing Instance value_WhyType.

(* Why3 assumption *)
Definition env := (map.Map.map Z value).

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
  | (_, _) => ((eval_bin x op y) = (Vbool false))
  end.

(* Why3 assumption *)
Fixpoint eval_term (sigma:(map.Map.map Z value)) (pi:(map.Map.map Z value))
  (t:term) {struct t}: value :=
  match t with
  | (Tconst n) => (Vint n)
  | (Tvar id) => (map.Map.get pi id)
  | (Tderef id) => (map.Map.get sigma id)
  | (Tbin t1 op t2) => (eval_bin (eval_term sigma pi t1) op (eval_term sigma
      pi t2))
  end.

(* Why3 assumption *)
Fixpoint eval_fmla (sigma:(map.Map.map Z value)) (pi:(map.Map.map Z value))
  (f:fmla) {struct f}: Prop :=
  match f with
  | (Fterm t) => ((eval_term sigma pi t) = (Vbool true))
  | (Fand f1 f2) => (eval_fmla sigma pi f1) /\ (eval_fmla sigma pi f2)
  | (Fnot f1) => ~ (eval_fmla sigma pi f1)
  | (Fimplies f1 f2) => (eval_fmla sigma pi f1) -> (eval_fmla sigma pi f2)
  | (Flet x t f1) => (eval_fmla sigma (map.Map.set pi x (eval_term sigma pi
      t)) f1)
  | (Fforall x Tint f1) => forall (n:Z), (eval_fmla sigma (map.Map.set pi x
      (Vint n)) f1)
  | (Fforall x Tbool f1) => forall (b:bool), (eval_fmla sigma (map.Map.set pi
      x (Vbool b)) f1)
  end.

Parameter subst_term: term -> Z -> Z -> term.

Axiom subst_term_def : forall (e:term) (r:Z) (v:Z),
  match e with
  | (Tconst _) => ((subst_term e r v) = e)
  | (Tvar _) => ((subst_term e r v) = e)
  | (Tderef x) => ((r = x) -> ((subst_term e r v) = (Tvar v))) /\
      ((~ (r = x)) -> ((subst_term e r v) = e))
  | (Tbin e1 op e2) => ((subst_term e r v) = (Tbin (subst_term e1 r v) op
      (subst_term e2 r v)))
  end.

(* Why3 assumption *)
Fixpoint fresh_in_term (id:Z) (t:term) {struct t}: Prop :=
  match t with
  | (Tconst _) => True
  | (Tvar v) => ~ (id = v)
  | (Tderef _) => True
  | (Tbin t1 _ t2) => (fresh_in_term id t1) /\ (fresh_in_term id t2)
  end.

Axiom eval_subst_term : forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map
  Z value)) (e:term) (x:Z) (v:Z), (fresh_in_term v e) -> ((eval_term sigma pi
  (subst_term e x v)) = (eval_term (map.Map.set sigma x (map.Map.get pi v))
  pi e)).

Axiom eval_term_change_free : forall (t:term) (sigma:(map.Map.map Z value))
  (pi:(map.Map.map Z value)) (id:Z) (v:value), (fresh_in_term id t) ->
  ((eval_term sigma (map.Map.set pi id v) t) = (eval_term sigma pi t)).

(* Why3 assumption *)
Fixpoint fresh_in_fmla (id:Z) (f:fmla) {struct f}: Prop :=
  match f with
  | (Fterm e) => (fresh_in_term id e)
  | ((Fand f1 f2)|(Fimplies f1 f2)) => (fresh_in_fmla id f1) /\
      (fresh_in_fmla id f2)
  | (Fnot f1) => (fresh_in_fmla id f1)
  | (Flet y t f1) => (~ (id = y)) /\ ((fresh_in_term id t) /\ (fresh_in_fmla
      id f1))
  | (Fforall y _ f1) => (~ (id = y)) /\ (fresh_in_fmla id f1)
  end.

(* Why3 assumption *)
Fixpoint subst (f:fmla) (x:Z) (v:Z) {struct f}: fmla :=
  match f with
  | (Fterm e) => (Fterm (subst_term e x v))
  | (Fand f1 f2) => (Fand (subst f1 x v) (subst f2 x v))
  | (Fnot f1) => (Fnot (subst f1 x v))
  | (Fimplies f1 f2) => (Fimplies (subst f1 x v) (subst f2 x v))
  | (Flet y t f1) => (Flet y (subst_term t x v) (subst f1 x v))
  | (Fforall y ty f1) => (Fforall y ty (subst f1 x v))
  end.

Axiom eval_subst : forall (f:fmla) (sigma:(map.Map.map Z value))
  (pi:(map.Map.map Z value)) (x:Z) (v:Z), (fresh_in_fmla v f) -> ((eval_fmla
  sigma pi (subst f x v)) <-> (eval_fmla (map.Map.set sigma x (map.Map.get pi
  v)) pi f)).

Axiom eval_swap : forall (f:fmla) (sigma:(map.Map.map Z value))
  (pi:(map.Map.map Z value)) (id1:Z) (id2:Z) (v1:value) (v2:value),
  (~ (id1 = id2)) -> ((eval_fmla sigma (map.Map.set (map.Map.set pi id1 v1)
  id2 v2) f) <-> (eval_fmla sigma (map.Map.set (map.Map.set pi id2 v2) id1
  v1) f)).

Axiom eval_change_free : forall (f:fmla) (sigma:(map.Map.map Z value))
  (pi:(map.Map.map Z value)) (id:Z) (v:value), (fresh_in_fmla id f) ->
  ((eval_fmla sigma (map.Map.set pi id v) f) <-> (eval_fmla sigma pi f)).

(* Why3 assumption *)
Inductive stmt :=
  | Sskip : stmt
  | Sassign : Z -> term -> stmt
  | Sseq : stmt -> stmt -> stmt
  | Sif : term -> stmt -> stmt -> stmt
  | Sassert : fmla -> stmt
  | Swhile : term -> fmla -> stmt -> stmt.
Axiom stmt_WhyType : WhyType stmt.
Existing Instance stmt_WhyType.

Axiom check_skip : forall (s:stmt), (s = Sskip) \/ ~ (s = Sskip).

(* Why3 assumption *)
Inductive one_step: (map.Map.map Z value) -> (map.Map.map Z value) -> stmt ->
  (map.Map.map Z value) -> (map.Map.map Z value) -> stmt -> Prop :=
  | one_step_assign : forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map Z
      value)) (x:Z) (e:term), (one_step sigma pi (Sassign x e)
      (map.Map.set sigma x (eval_term sigma pi e)) pi Sskip)
  | one_step_seq : forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map Z
      value)) (sigma':(map.Map.map Z value)) (pi':(map.Map.map Z value))
      (i1:stmt) (i1':stmt) (i2:stmt), (one_step sigma pi i1 sigma' pi'
      i1') -> (one_step sigma pi (Sseq i1 i2) sigma' pi' (Sseq i1' i2))
  | one_step_seq_skip : forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map
      Z value)) (i:stmt), (one_step sigma pi (Sseq Sskip i) sigma pi i)
  | one_step_if_true : forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map
      Z value)) (e:term) (i1:stmt) (i2:stmt), ((eval_term sigma pi
      e) = (Vbool true)) -> (one_step sigma pi (Sif e i1 i2) sigma pi i1)
  | one_step_if_false : forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map
      Z value)) (e:term) (i1:stmt) (i2:stmt), ((eval_term sigma pi
      e) = (Vbool false)) -> (one_step sigma pi (Sif e i1 i2) sigma pi i2)
  | one_step_assert : forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map Z
      value)) (f:fmla), (eval_fmla sigma pi f) -> (one_step sigma pi
      (Sassert f) sigma pi Sskip)
  | one_step_while_true : forall (sigma:(map.Map.map Z value))
      (pi:(map.Map.map Z value)) (e:term) (inv:fmla) (i:stmt), (eval_fmla
      sigma pi inv) -> (((eval_term sigma pi e) = (Vbool true)) -> (one_step
      sigma pi (Swhile e inv i) sigma pi (Sseq i (Swhile e inv i))))
  | one_step_while_false : forall (sigma:(map.Map.map Z value))
      (pi:(map.Map.map Z value)) (e:term) (inv:fmla) (i:stmt), (eval_fmla
      sigma pi inv) -> (((eval_term sigma pi e) = (Vbool false)) -> (one_step
      sigma pi (Swhile e inv i) sigma pi Sskip)).

(* Why3 assumption *)
Inductive many_steps: (map.Map.map Z value) -> (map.Map.map Z value) ->
  stmt -> (map.Map.map Z value) -> (map.Map.map Z value) -> stmt -> Z ->
  Prop :=
  | many_steps_refl : forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map Z
      value)) (i:stmt), (many_steps sigma pi i sigma pi i 0%Z)
  | many_steps_trans : forall (sigma1:(map.Map.map Z value))
      (pi1:(map.Map.map Z value)) (sigma2:(map.Map.map Z value))
      (pi2:(map.Map.map Z value)) (sigma3:(map.Map.map Z value))
      (pi3:(map.Map.map Z value)) (i1:stmt) (i2:stmt) (i3:stmt) (n:Z),
      (one_step sigma1 pi1 i1 sigma2 pi2 i2) -> ((many_steps sigma2 pi2 i2
      sigma3 pi3 i3 n) -> (many_steps sigma1 pi1 i1 sigma3 pi3 i3
      (n + 1%Z)%Z)).

Axiom steps_non_neg : forall (sigma1:(map.Map.map Z value)) (pi1:(map.Map.map
  Z value)) (sigma2:(map.Map.map Z value)) (pi2:(map.Map.map Z value))
  (i1:stmt) (i2:stmt) (n:Z), (many_steps sigma1 pi1 i1 sigma2 pi2 i2 n) ->
  (0%Z <= n)%Z.

Axiom many_steps_seq : forall (sigma1:(map.Map.map Z value))
  (pi1:(map.Map.map Z value)) (sigma3:(map.Map.map Z value))
  (pi3:(map.Map.map Z value)) (i1:stmt) (i2:stmt) (n:Z), (many_steps sigma1
  pi1 (Sseq i1 i2) sigma3 pi3 Sskip n) -> exists sigma2:(map.Map.map Z
  value), exists pi2:(map.Map.map Z value), exists n1:Z, exists n2:Z,
  (many_steps sigma1 pi1 i1 sigma2 pi2 Sskip n1) /\ ((many_steps sigma2 pi2
  i2 sigma3 pi3 Sskip n2) /\ (n = ((1%Z + n1)%Z + n2)%Z)).

(* Why3 assumption *)
Definition valid_fmla (p:fmla): Prop := forall (sigma:(map.Map.map Z value))
  (pi:(map.Map.map Z value)), (eval_fmla sigma pi p).

(* Why3 assumption *)
Definition valid_triple (p:fmla) (i:stmt) (q:fmla): Prop :=
  forall (sigma:(map.Map.map Z value)) (pi:(map.Map.map Z value)), (eval_fmla
  sigma pi p) -> forall (sigma':(map.Map.map Z value)) (pi':(map.Map.map Z
  value)) (n:Z), (many_steps sigma pi i sigma' pi' Sskip n) -> (eval_fmla
  sigma' pi' q).

(* Why3 assumption *)
Definition assigns (sigma:(map.Map.map Z value)) (a:(set.Set.set Z))
  (sigma':(map.Map.map Z value)): Prop := forall (i:Z), (~ (set.Set.mem i
  a)) -> ((map.Map.get sigma i) = (map.Map.get sigma' i)).

Axiom assigns_refl : forall (sigma:(map.Map.map Z value)) (a:(set.Set.set
  Z)), (assigns sigma a sigma).

Axiom assigns_trans : forall (sigma1:(map.Map.map Z value))
  (sigma2:(map.Map.map Z value)) (sigma3:(map.Map.map Z value))
  (a:(set.Set.set Z)), ((assigns sigma1 a sigma2) /\ (assigns sigma2 a
  sigma3)) -> (assigns sigma1 a sigma3).

Axiom assigns_union_left : forall (sigma:(map.Map.map Z value))
  (sigma':(map.Map.map Z value)) (s1:(set.Set.set Z)) (s2:(set.Set.set Z)),
  (assigns sigma s1 sigma') -> (assigns sigma (set.Set.union s1 s2) sigma').

Axiom assigns_union_right : forall (sigma:(map.Map.map Z value))
  (sigma':(map.Map.map Z value)) (s1:(set.Set.set Z)) (s2:(set.Set.set Z)),
  (assigns sigma s2 sigma') -> (assigns sigma (set.Set.union s1 s2) sigma').

(* Why3 assumption *)
Fixpoint stmt_writes (i:stmt) (w:(set.Set.set Z)) {struct i}: Prop :=
  match i with
  | (Sskip|(Sassert _)) => True
  | (Sassign id _) => (set.Set.mem id w)
  | ((Sseq s1 s2)|(Sif _ s1 s2)) => (stmt_writes s1 w) /\ (stmt_writes s2 w)
  | (Swhile _ _ s) => (stmt_writes s w)
  end.

Axiom consequence_rule : forall (p:fmla) (p':fmla) (q:fmla) (q':fmla)
  (i:stmt), (valid_fmla (Fimplies p' p)) -> ((valid_triple p i q) ->
  ((valid_fmla (Fimplies q q')) -> (valid_triple p' i q'))).

Axiom skip_rule : forall (q:fmla), (valid_triple q Sskip q).

Axiom assign_rule : forall (q:fmla) (x:Z) (id:Z) (e:term), (fresh_in_fmla id
  q) -> (valid_triple (Flet id e (subst q x id)) (Sassign x e) q).

Axiom seq_rule : forall (p:fmla) (q:fmla) (r:fmla) (i1:stmt) (i2:stmt),
  ((valid_triple p i1 r) /\ (valid_triple r i2 q)) -> (valid_triple p
  (Sseq i1 i2) q).

Axiom if_rule : forall (e:term) (p:fmla) (q:fmla) (i1:stmt) (i2:stmt),
  ((valid_triple (Fand p (Fterm e)) i1 q) /\ (valid_triple (Fand p
  (Fnot (Fterm e))) i2 q)) -> (valid_triple p (Sif e i1 i2) q).

Axiom assert_rule : forall (f:fmla) (p:fmla), (valid_fmla (Fimplies p f)) ->
  (valid_triple p (Sassert f) p).

Axiom assert_rule_ext : forall (f:fmla) (p:fmla), (valid_triple (Fimplies f
  p) (Sassert f) p).

Axiom while_rule : forall (e:term) (inv:fmla) (i:stmt), (valid_triple
  (Fand (Fterm e) inv) i inv) -> (valid_triple inv (Swhile e inv i)
  (Fand (Fnot (Fterm e)) inv)).

Axiom while_rule_ext : forall (e:term) (inv:fmla) (inv':fmla) (i:stmt),
  (valid_fmla (Fimplies inv' inv)) -> ((valid_triple (Fand (Fterm e) inv') i
  inv') -> (valid_triple inv' (Swhile e inv i) (Fand (Fnot (Fterm e))
  inv'))).

(* Why3 goal *)
Theorem WP_parameter_wp : forall (i:stmt) (q:fmla), forall (x:term) (x1:stmt)
  (x2:stmt), (i = (Sif x x1 x2)) -> forall (o:fmla), (valid_triple o x2 q) ->
  forall (o1:fmla), (valid_triple o1 x1 q) -> (valid_triple
  (Fand (Fimplies (Fterm x) o1) (Fimplies (Fnot (Fterm x)) o)) i q).
(* Why3 intros i q x x1 x2 h1 o h2 o1 h3. *)
intros i q x x1 x2 H_;rewrite H_;intros.
apply if_rule.
split.
apply consequence_rule with (2:=H0).
unfold valid_fmla; simpl; tauto.
unfold valid_fmla; simpl; tauto.
apply consequence_rule with (2:=H).
unfold valid_fmla; simpl; tauto.
unfold valid_fmla; simpl; tauto.
Qed.
