(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require list.List.
Require list.Length.
Require int.Int.
Require list.Mem.
Require map.Map.
Require list.Append.

(* Why3 assumption *)
Definition unit := unit.

Axiom set : forall (a:Type) {a_WT:WhyType a}, Type.
Parameter set_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (set a).
Existing Instance set_WhyType.

Parameter mem: forall {a:Type} {a_WT:WhyType a}, a -> (@set a a_WT) -> Prop.

(* Why3 assumption *)
Definition infix_eqeq {a:Type} {a_WT:WhyType a} (s1:(@set a a_WT)) (s2:(@set
  a a_WT)): Prop := forall (x:a), (mem x s1) <-> (mem x s2).

Axiom extensionality : forall {a:Type} {a_WT:WhyType a}, forall (s1:(@set
  a a_WT)) (s2:(@set a a_WT)), (infix_eqeq s1 s2) -> (s1 = s2).

(* Why3 assumption *)
Definition subset {a:Type} {a_WT:WhyType a} (s1:(@set a a_WT)) (s2:(@set
  a a_WT)): Prop := forall (x:a), (mem x s1) -> (mem x s2).

Axiom subset_refl : forall {a:Type} {a_WT:WhyType a}, forall (s:(@set
  a a_WT)), (subset s s).

Axiom subset_trans : forall {a:Type} {a_WT:WhyType a}, forall (s1:(@set
  a a_WT)) (s2:(@set a a_WT)) (s3:(@set a a_WT)), (subset s1 s2) -> ((subset
  s2 s3) -> (subset s1 s3)).

Parameter empty: forall {a:Type} {a_WT:WhyType a}, (@set a a_WT).

(* Why3 assumption *)
Definition is_empty {a:Type} {a_WT:WhyType a} (s:(@set a a_WT)): Prop :=
  forall (x:a), ~ (mem x s).

Axiom empty_def1 : forall {a:Type} {a_WT:WhyType a}, (is_empty (empty :(@set
  a a_WT))).

Axiom mem_empty : forall {a:Type} {a_WT:WhyType a}, forall (x:a), ~ (mem x
  (empty :(@set a a_WT))).

Parameter add: forall {a:Type} {a_WT:WhyType a}, a -> (@set a a_WT) -> (@set
  a a_WT).

Axiom add_def1 : forall {a:Type} {a_WT:WhyType a}, forall (x:a) (y:a),
  forall (s:(@set a a_WT)), (mem x (add y s)) <-> ((x = y) \/ (mem x s)).

Parameter remove: forall {a:Type} {a_WT:WhyType a}, a -> (@set a a_WT)
  -> (@set a a_WT).

Axiom remove_def1 : forall {a:Type} {a_WT:WhyType a}, forall (x:a) (y:a)
  (s:(@set a a_WT)), (mem x (remove y s)) <-> ((~ (x = y)) /\ (mem x s)).

Axiom subset_remove : forall {a:Type} {a_WT:WhyType a}, forall (x:a) (s:(@set
  a a_WT)), (subset (remove x s) s).

Parameter union: forall {a:Type} {a_WT:WhyType a}, (@set a a_WT) -> (@set
  a a_WT) -> (@set a a_WT).

Axiom union_def1 : forall {a:Type} {a_WT:WhyType a}, forall (s1:(@set
  a a_WT)) (s2:(@set a a_WT)) (x:a), (mem x (union s1 s2)) <-> ((mem x s1) \/
  (mem x s2)).

Parameter inter: forall {a:Type} {a_WT:WhyType a}, (@set a a_WT) -> (@set
  a a_WT) -> (@set a a_WT).

Axiom inter_def1 : forall {a:Type} {a_WT:WhyType a}, forall (s1:(@set
  a a_WT)) (s2:(@set a a_WT)) (x:a), (mem x (inter s1 s2)) <-> ((mem x s1) /\
  (mem x s2)).

Parameter diff: forall {a:Type} {a_WT:WhyType a}, (@set a a_WT) -> (@set
  a a_WT) -> (@set a a_WT).

Axiom diff_def1 : forall {a:Type} {a_WT:WhyType a}, forall (s1:(@set a a_WT))
  (s2:(@set a a_WT)) (x:a), (mem x (diff s1 s2)) <-> ((mem x s1) /\ ~ (mem x
  s2)).

Axiom subset_diff : forall {a:Type} {a_WT:WhyType a}, forall (s1:(@set
  a a_WT)) (s2:(@set a a_WT)), (subset (diff s1 s2) s1).

Parameter choose: forall {a:Type} {a_WT:WhyType a}, (@set a a_WT) -> a.

Axiom choose_def : forall {a:Type} {a_WT:WhyType a}, forall (s:(@set
  a a_WT)), (~ (is_empty s)) -> (mem (choose s) s).

Parameter cardinal: forall {a:Type} {a_WT:WhyType a}, (@set a a_WT) -> Z.

Axiom cardinal_nonneg : forall {a:Type} {a_WT:WhyType a}, forall (s:(@set
  a a_WT)), (0%Z <= (cardinal s))%Z.

Axiom cardinal_empty : forall {a:Type} {a_WT:WhyType a}, forall (s:(@set
  a a_WT)), ((cardinal s) = 0%Z) <-> (is_empty s).

Axiom cardinal_add : forall {a:Type} {a_WT:WhyType a}, forall (x:a),
  forall (s:(@set a a_WT)), (~ (mem x s)) -> ((cardinal (add x
  s)) = (1%Z + (cardinal s))%Z).

Axiom cardinal_remove : forall {a:Type} {a_WT:WhyType a}, forall (x:a),
  forall (s:(@set a a_WT)), (mem x s) ->
  ((cardinal s) = (1%Z + (cardinal (remove x s)))%Z).

Axiom cardinal_subset : forall {a:Type} {a_WT:WhyType a}, forall (s1:(@set
  a a_WT)) (s2:(@set a a_WT)), (subset s1 s2) ->
  ((cardinal s1) <= (cardinal s2))%Z.

Axiom cardinal1 : forall {a:Type} {a_WT:WhyType a}, forall (s:(@set a a_WT)),
  ((cardinal s) = 1%Z) -> forall (x:a), (mem x s) -> (x = (choose s)).

Axiom vertex : Type.
Parameter vertex_WhyType : WhyType vertex.
Existing Instance vertex_WhyType.

Parameter vertices: (@set vertex vertex_WhyType).

Parameter edges: (@set (vertex* vertex)%type _).

(* Why3 assumption *)
Definition edge (x:vertex) (y:vertex): Prop := (mem (x, y) edges).

Axiom edges_def : forall (x:vertex) (y:vertex), (mem (x, y) edges) -> ((mem x
  vertices) /\ (mem y vertices)).

Parameter s: vertex.

Axiom s_in_graph : (mem s vertices).

Axiom vertices_cardinal_pos : (0%Z < (cardinal vertices))%Z.

(* Why3 assumption *)
Inductive path : vertex -> (list vertex) -> vertex -> Prop :=
  | Path_empty : forall (x:vertex), (path x nil x)
  | Path_cons : forall (x:vertex) (y:vertex) (z:vertex) (l:(list vertex)),
      (edge x y) -> ((path y l z) -> (path x (cons x l) z)).

Axiom path_right_extension : forall (x:vertex) (y:vertex) (z:vertex)
  (l:(list vertex)), (path x l y) -> ((edge y z) -> (path x
  (List.app l (cons y nil)) z)).

Axiom path_right_inversion : forall (x:vertex) (z:vertex) (l:(list vertex)),
  (path x l z) -> (((x = z) /\ (l = nil)) \/ exists y:vertex,
  exists l':(list vertex), (path x l' y) /\ ((edge y z) /\
  (l = (List.app l' (cons y nil))))).

Axiom path_trans : forall (x:vertex) (y:vertex) (z:vertex) (l1:(list vertex))
  (l2:(list vertex)), (path x l1 y) -> ((path y l2 z) -> (path x
  (List.app l1 l2) z)).

Axiom empty_path : forall (x:vertex) (y:vertex), (path x nil y) -> (x = y).

Axiom path_decomposition : forall (x:vertex) (y:vertex) (z:vertex)
  (l1:(list vertex)) (l2:(list vertex)), (path x (List.app l1 (cons y l2))
  z) -> ((path x l1 y) /\ (path y (cons y l2) z)).

Parameter weight: vertex -> vertex -> Z.

(* Why3 assumption *)
Fixpoint path_weight (l:(list vertex)) (dst:vertex) {struct l}: Z :=
  match l with
  | nil => 0%Z
  | (cons x nil) => (weight x dst)
  | (cons x ((cons y _) as r)) => ((weight x y) + (path_weight r dst))%Z
  end.

Axiom path_weight_right_extension : forall (x:vertex) (y:vertex)
  (l:(list vertex)), ((path_weight (List.app l (cons x nil))
  y) = ((path_weight l x) + (weight x y))%Z).

Axiom path_weight_decomposition : forall (y:vertex) (z:vertex)
  (l1:(list vertex)) (l2:(list vertex)),
  ((path_weight (List.app l1 (cons y l2)) z) = ((path_weight l1
  y) + (path_weight (cons y l2) z))%Z).

Axiom path_in_vertices : forall (v1:vertex) (v2:vertex) (l:(list vertex)),
  (mem v1 vertices) -> ((path v1 l v2) -> (mem v2 vertices)).

(* Why3 assumption *)
Definition pigeon_set (s1:(@set vertex vertex_WhyType)): Prop :=
  forall (l:(list vertex)), (forall (e:vertex), (list.Mem.mem e l) -> (mem e
  s1)) -> (((cardinal s1) < (list.Length.length l))%Z -> exists e:vertex,
  exists l1:(list vertex), exists l2:(list vertex), exists l3:(list vertex),
  (l = (List.app l1 (cons e (List.app l2 (cons e l3)))))).

Axiom Induction : (forall (s1:(@set vertex vertex_WhyType)), (is_empty s1) ->
  (pigeon_set s1)) -> ((forall (s1:(@set vertex vertex_WhyType)), (pigeon_set
  s1) -> forall (t:vertex), (~ (mem t s1)) -> (pigeon_set (add t s1))) ->
  forall (s1:(@set vertex vertex_WhyType)), (pigeon_set s1)).

Axiom corner : forall (s1:(@set vertex vertex_WhyType)) (l:(list vertex)),
  ((list.Length.length l) = (cardinal s1)) -> ((forall (e:vertex),
  (list.Mem.mem e l) -> (mem e s1)) -> ((exists e:vertex,
  (exists l1:(list vertex), (exists l2:(list vertex),
  (exists l3:(list vertex),
  (l = (List.app l1 (cons e (List.app l2 (cons e l3))))))))) \/
  forall (e:vertex), (mem e s1) -> (list.Mem.mem e l))).

Axiom pigeon_0 : (pigeon_set (empty :(@set vertex vertex_WhyType))).

Axiom pigeon_1 : forall (s1:(@set vertex vertex_WhyType)), (pigeon_set s1) ->
  forall (t:vertex), (pigeon_set (add t s1)).

Axiom pigeon_2 : forall (s1:(@set vertex vertex_WhyType)), (pigeon_set s1).

Axiom pigeonhole : forall (s1:(@set vertex vertex_WhyType))
  (l:(list vertex)), (forall (e:vertex), (list.Mem.mem e l) -> (mem e s1)) ->
  (((cardinal s1) < (list.Length.length l))%Z -> exists e:vertex,
  exists l1:(list vertex), exists l2:(list vertex), exists l3:(list vertex),
  (l = (List.app l1 (cons e (List.app l2 (cons e l3)))))).

Axiom long_path_decomposition_pigeon1 : forall (l:(list vertex)) (v:vertex),
  (path s l v) -> ((~ (l = nil)) -> forall (v1:vertex), (list.Mem.mem v1
  (cons v l)) -> (mem v1 vertices)).

Axiom long_path_decomposition_pigeon2 : forall (l:(list vertex)) (v:vertex),
  (forall (v1:vertex), (list.Mem.mem v1 (cons v l)) -> (mem v1 vertices)) ->
  (((cardinal vertices) < (list.Length.length (cons v l)))%Z ->
  exists e:vertex, exists l1:(list vertex), exists l2:(list vertex),
  exists l3:(list vertex),
  ((cons v l) = (List.app l1 (cons e (List.app l2 (cons e l3)))))).

Axiom long_path_decomposition_pigeon3 : forall (l:(list vertex)) (v:vertex),
  (exists e:vertex, (exists l1:(list vertex), (exists l2:(list vertex),
  (exists l3:(list vertex),
  ((cons v l) = (List.app l1 (cons e (List.app l2 (cons e l3))))))))) ->
  ((exists l1:(list vertex), (exists l2:(list vertex),
  (l = (List.app l1 (cons v l2))))) \/ exists n:vertex,
  exists l1:(list vertex), exists l2:(list vertex), exists l3:(list vertex),
  (l = (List.app l1 (cons n (List.app l2 (cons n l3)))))).

Axiom long_path_decomposition : forall (l:(list vertex)) (v:vertex), (path s
  l v) -> (((cardinal vertices) <= (list.Length.length l))%Z ->
  ((exists l1:(list vertex), (exists l2:(list vertex),
  (l = (List.app l1 (cons v l2))))) \/ exists n:vertex,
  exists l1:(list vertex), exists l2:(list vertex), exists l3:(list vertex),
  (l = (List.app l1 (cons n (List.app l2 (cons n l3))))))).

Axiom simple_path : forall (v:vertex) (l:(list vertex)), (path s l v) ->
  exists l':(list vertex), (path s l' v) /\
  ((list.Length.length l') < (cardinal vertices))%Z.

(* Why3 assumption *)
Definition negative_cycle (v:vertex): Prop := (mem v vertices) /\
  ((exists l1:(list vertex), (path s l1 v)) /\ exists l2:(list vertex), (path
  v l2 v) /\ ((path_weight l2 v) < 0%Z)%Z).

Axiom key_lemma_1 : forall (v:vertex) (n:Z), (forall (l:(list vertex)), (path
  s l v) -> (((list.Length.length l) < (cardinal vertices))%Z ->
  (n <= (path_weight l v))%Z)) -> ((exists l:(list vertex), (path s l v) /\
  ((path_weight l v) < n)%Z) -> exists u:vertex, (negative_cycle u)).

(* Why3 assumption *)
Inductive t :=
  | Finite : Z -> t
  | Infinite : t.
Axiom t_WhyType : WhyType t.
Existing Instance t_WhyType.

(* Why3 assumption *)
Definition add1 (x:t) (y:t): t :=
  match x with
  | Infinite => Infinite
  | (Finite x1) =>
      match y with
      | Infinite => Infinite
      | (Finite y1) => (Finite (x1 + y1)%Z)
      end
  end.

(* Why3 assumption *)
Definition lt (x:t) (y:t): Prop :=
  match x with
  | Infinite => False
  | (Finite x1) =>
      match y with
      | Infinite => True
      | (Finite y1) => (x1 < y1)%Z
      end
  end.

(* Why3 assumption *)
Definition le (x:t) (y:t): Prop := (lt x y) \/ (x = y).

Axiom Refl : forall (x:t), (le x x).

Axiom Trans : forall (x:t) (y:t) (z:t), (le x y) -> ((le y z) -> (le x z)).

Axiom Antisymm : forall (x:t) (y:t), (le x y) -> ((le y x) -> (x = y)).

Axiom Total : forall (x:t) (y:t), (le x y) \/ (le y x).

(* Why3 assumption *)
Inductive ref (a:Type) {a_WT:WhyType a} :=
  | mk_ref : a -> ref a.
Axiom ref_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (ref a).
Existing Instance ref_WhyType.
Implicit Arguments mk_ref [[a] [a_WT]].

(* Why3 assumption *)
Definition contents {a:Type} {a_WT:WhyType a} (v:(@ref a a_WT)): a :=
  match v with
  | (mk_ref x) => x
  end.

(* Why3 assumption *)
Definition t1 (a:Type) {a_WT:WhyType a} := (@ref (@set a a_WT) (@set_WhyType
  a a_WT)).

(* Why3 assumption *)
Definition distmap := (@map.Map.map vertex vertex_WhyType t t_WhyType).

(* Why3 assumption *)
Definition inv1 (m:(@map.Map.map vertex vertex_WhyType t t_WhyType)) (pass:Z)
  (via:(@set (vertex* vertex)%type _)): Prop := forall (v:vertex), (mem v
  vertices) -> match (map.Map.get m
  v) with
  | (Finite n) => (exists l:(list vertex), (path s l v) /\ ((path_weight l
      v) = n)) /\ ((forall (l:(list vertex)), (path s l v) ->
      (((list.Length.length l) < pass)%Z -> (n <= (path_weight l v))%Z)) /\
      forall (u:vertex) (l:(list vertex)), (path s l u) ->
      (((list.Length.length l) < pass)%Z -> ((mem (u, v) via) ->
      (n <= ((path_weight l u) + (weight u v))%Z)%Z)))
  | Infinite => (forall (l:(list vertex)), (path s l v) ->
      (pass <= (list.Length.length l))%Z) /\ forall (u:vertex), (mem (u, v)
      via) -> forall (lu:(list vertex)), (path s lu u) ->
      (pass <= (list.Length.length lu))%Z
  end.

(* Why3 assumption *)
Definition inv2 (m:(@map.Map.map vertex vertex_WhyType t t_WhyType))
  (via:(@set (vertex* vertex)%type _)): Prop := forall (u:vertex) (v:vertex),
  (mem (u, v) via) -> (le (map.Map.get m v) (add1 (map.Map.get m u)
  (Finite (weight u v)))).

Axiom key_lemma_2 : forall (m:(@map.Map.map vertex vertex_WhyType
  t t_WhyType)), (inv1 m (cardinal vertices) (empty :(@set (vertex*
  vertex)%type _))) -> ((inv2 m edges) -> forall (v:vertex),
  ~ (negative_cycle v)).

Require Import Why3.
Ltac ae := why3 "alt-ergo" timelimit 30.

(* Why3 goal *)
Theorem WP_parameter_bellman_ford : let o := ((cardinal vertices) - 1%Z)%Z in
  (((1%Z < o)%Z \/ (1%Z = o)) -> forall (m:(@map.Map.map
  vertex vertex_WhyType t t_WhyType)), forall (i:Z), (((1%Z < i)%Z \/
  (1%Z = i)) /\ ((i < o)%Z \/ (i = o))) -> ((forall (v:vertex), (mem v
  vertices) -> match (map.Map.get m
  v) with
  | (Finite n) => (exists l:(list vertex), (path s l v) /\ ((path_weight l
      v) = n)) /\ ((forall (l:(list vertex)), (path s l v) ->
      (((list.Length.length l) < i)%Z -> (n <= (path_weight l v))%Z)) /\
      forall (u:vertex) (l:(list vertex)), (path s l u) ->
      (((list.Length.length l) < i)%Z -> ((mem (u, v) (empty :(@set (vertex*
      vertex)%type _))) -> (n <= ((path_weight l u) + (weight u v))%Z)%Z)))
  | Infinite => (forall (l:(list vertex)), (path s l v) ->
      (i <= (list.Length.length l))%Z) /\ forall (u:vertex), (mem (u, v)
      (empty :(@set (vertex* vertex)%type _))) -> forall (lu:(list vertex)),
      (path s lu u) -> (i <= (list.Length.length lu))%Z
  end) -> forall (es:(@set (vertex* vertex)%type _)), (es = edges) ->
  forall (es1:(@set (vertex* vertex)%type _)) (m1:(@map.Map.map
  vertex vertex_WhyType t t_WhyType)), ((forall (x:(vertex* vertex)%type),
  (mem x es1) -> (mem x edges)) /\ forall (v:vertex), (mem v vertices) ->
  match (map.Map.get m1
  v) with
  | (Finite n) => (exists l:(list vertex), (path s l v) /\ ((path_weight l
      v) = n)) /\ ((forall (l:(list vertex)), (path s l v) ->
      (((list.Length.length l) < i)%Z -> (n <= (path_weight l v))%Z)) /\
      forall (u:vertex) (l:(list vertex)), (path s l u) ->
      (((list.Length.length l) < i)%Z -> ((mem (u, v) (diff edges es1)) ->
      (n <= ((path_weight l u) + (weight u v))%Z)%Z)))
  | Infinite => (forall (l:(list vertex)), (path s l v) ->
      (i <= (list.Length.length l))%Z) /\ forall (u:vertex), (mem (u, v)
      (diff edges es1)) -> forall (lu:(list vertex)), (path s lu u) ->
      (i <= (list.Length.length lu))%Z
  end) -> forall (o1:bool), ((o1 = true) <-> forall (x:(vertex*
  vertex)%type), ~ (mem x es1)) -> ((o1 = true) -> ((forall (v:vertex), (mem
  v vertices) -> match (map.Map.get m1
  v) with
  | (Finite n) => (exists l:(list vertex), (path s l v) /\ ((path_weight l
      v) = n)) /\ ((forall (l:(list vertex)), (path s l v) ->
      (((list.Length.length l) < i)%Z -> (n <= (path_weight l v))%Z)) /\
      forall (u:vertex) (l:(list vertex)), (path s l u) ->
      (((list.Length.length l) < i)%Z -> ((mem (u, v) edges) ->
      (n <= ((path_weight l u) + (weight u v))%Z)%Z)))
  | Infinite => (forall (l:(list vertex)), (path s l v) ->
      (i <= (list.Length.length l))%Z) /\ forall (u:vertex), (mem (u, v)
      edges) -> forall (lu:(list vertex)), (path s lu u) ->
      (i <= (list.Length.length lu))%Z
  end) -> forall (v:vertex), (mem v vertices) -> match (map.Map.get m1
  v) with
  | (Finite n) => True
  | Infinite => forall (l:(list vertex)), (path s l v) ->
      ((i + 1%Z)%Z <= (list.Length.length l))%Z
  end)))).
(* Why3 intros o h1 m i (h2,h3) h4 es h5 es1 m1 (h6,h7) o1 h8 h9 h10 v h11. *)
intros.
destruct (Map.get m1 v) as [] _eqn; auto.
intros l hpath.
destruct (path_right_inversion s v l hpath) as [(h1,h2) | (y, (l', (h1, (h2, h3))))].
(* Nil *)
subst.
generalize (H6 s H7); clear H6.
ae.
(* s --l'--> y --> v *)
generalize (H6 v H7); clear H6.
rewrite Heqt0; simpl.
intros (hh1, hh2).
assert (i <= Length.length l')%Z by ae.
assert (Length.length l = Length.length l' + 1)%Z.
subst l. apply Append.Append_length.
ae.
Qed.


