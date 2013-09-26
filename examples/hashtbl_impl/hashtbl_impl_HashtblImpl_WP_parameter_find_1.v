(* This file is generated by Why3's Coq 8.4 driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require Import ZOdiv.
Require BuiltIn.
Require int.Int.
Require int.Abs.
Require int.ComputerDivision.
Require option.Option.
Require list.List.
Require list.Mem.
Require map.Map.

(* Why3 assumption *)
Definition unit := unit.

(* Why3 assumption *)
Inductive array
  (a:Type) {a_WT:WhyType a} :=
  | mk_array : Z -> (@map.Map.map Z _ a a_WT) -> array a.
Axiom array_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (array a).
Existing Instance array_WhyType.
Implicit Arguments mk_array [[a] [a_WT]].

(* Why3 assumption *)
Definition elts {a:Type} {a_WT:WhyType a} (v:(@array a a_WT)): (@map.Map.map
  Z _ a a_WT) := match v with
  | (mk_array x x1) => x1
  end.

(* Why3 assumption *)
Definition length {a:Type} {a_WT:WhyType a} (v:(@array a a_WT)): Z :=
  match v with
  | (mk_array x x1) => x
  end.

(* Why3 assumption *)
Definition get {a:Type} {a_WT:WhyType a} (a1:(@array a a_WT)) (i:Z): a :=
  (map.Map.get (elts a1) i).

(* Why3 assumption *)
Definition set {a:Type} {a_WT:WhyType a} (a1:(@array a a_WT)) (i:Z)
  (v:a): (@array a a_WT) := (mk_array (length a1) (map.Map.set (elts a1) i
  v)).

(* Why3 assumption *)
Definition make {a:Type} {a_WT:WhyType a} (n:Z) (v:a): (@array a a_WT) :=
  (mk_array n (map.Map.const v:(@map.Map.map Z _ a a_WT))).

Axiom key : Type.
Parameter key_WhyType : WhyType key.
Existing Instance key_WhyType.

Parameter hash: key -> Z.

Axiom hash_nonneg : forall (k:key), (0%Z <= (hash k))%Z.

(* Why3 assumption *)
Definition bucket (k:key) (n:Z): Z := (ZOmod (hash k) n).

Axiom bucket_bounds : forall (n:Z), (0%Z < n)%Z -> forall (k:key),
  (0%Z <= (bucket k n))%Z /\ ((bucket k n) < n)%Z.

(* Why3 assumption *)
Definition in_data {a:Type} {a_WT:WhyType a} (k:key) (v:a) (d:(@array
  (list (key* a)%type) _)): Prop := (list.Mem.mem (k, v) (get d (bucket k
  (length d)))).

(* Why3 assumption *)
Definition good_data {a:Type} {a_WT:WhyType a} (k:key) (v:a) (m:(@map.Map.map
  key key_WhyType (option a) _)) (d:(@array (list (key* a)%type) _)): Prop :=
  ((map.Map.get m k) = (Some v)) <-> (in_data k v d).

(* Why3 assumption *)
Definition good_hash {a:Type} {a_WT:WhyType a} (d:(@array (list (key*
  a)%type) _)) (i:Z): Prop := forall (k:key) (v:a), (list.Mem.mem (k, v)
  (get d i)) -> ((bucket k (length d)) = i).

(* Why3 assumption *)
Inductive t
  (a:Type) {a_WT:WhyType a} :=
  | mk_t : Z -> (@array (list (key* a)%type) _) -> (@map.Map.map
      key key_WhyType (option a) _) -> t a.
Axiom t_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (t a).
Existing Instance t_WhyType.
Implicit Arguments mk_t [[a] [a_WT]].

(* Why3 assumption *)
Definition view {a:Type} {a_WT:WhyType a} (v:(@t a a_WT)): (@map.Map.map
  key key_WhyType (option a) _) := match v with
  | (mk_t x x1 x2) => x2
  end.

(* Why3 assumption *)
Definition data {a:Type} {a_WT:WhyType a} (v:(@t a a_WT)): (@array
  (list (key* a)%type) _) := match v with
  | (mk_t x x1 x2) => x1
  end.

(* Why3 assumption *)
Definition size {a:Type} {a_WT:WhyType a} (v:(@t a a_WT)): Z :=
  match v with
  | (mk_t x x1 x2) => x
  end.

(* Why3 goal *)
Theorem WP_parameter_find : forall {a:Type} {a_WT:WhyType a}, forall (h:Z)
  (h1:(@map.Map.map Z _ (list (key* a)%type) _)) (h2:(@map.Map.map
  key key_WhyType (option a) _)) (k:key), ((((0%Z < h)%Z /\ forall (i:Z),
  ((0%Z <= i)%Z /\ (i < h)%Z) -> (good_hash (mk_array h h1) i)) /\
  forall (k1:key) (v:a), (good_data k1 v h2 (mk_array h h1))) /\
  (0%Z <= h)%Z) -> let i := (bucket k h) in (((0%Z <= i)%Z /\ (i < h)%Z) ->
  let o := (map.Map.get h1 i) in forall (result:(option a)),
  match result with
  | None => forall (v:a), ~ (list.Mem.mem (k, v) o)
  | (Some v) => (list.Mem.mem (k, v) o)
  end -> (result = (map.Map.get h2 k))).
intros a a_WT rho rho1 rho2 k (((h1,h2),h3),h4) i (h5,h6) o result h7.
subst i.
destruct result.
symmetry.
now apply h3.
specialize (h3 k).
unfold good_data in h3.
destruct (Map.get rho2 k).
elim (h7 a0).
now apply h3.
easy.
Qed.


