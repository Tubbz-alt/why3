(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-                                                   *)
(*    Francois Bobot                                                      *)
(*    Jean-Christophe Filliatre                                           *)
(*    Johannes Kanig                                                      *)
(*    Andrei Paskevich                                                    *)
(*                                                                        *)
(*  This software is free software; you can redistribute it and/or        *)
(*  modify it under the terms of the GNU Library General Public           *)
(*  License version 2.1, with the special exception on linking            *)
(*  described in file LICENSE.                                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  *)
(*                                                                        *)
(**************************************************************************)

open Ident
open Theory

(* Tranformation on context with some memoisations *)

(** General functions *)

(* The type of transformation from list of 'a to list of 'b *)
type 'a t
type ctxt_t = context t

(* compose two transformations, the underlying datastructures for
   the memoisation are shared *)
val compose : context t -> 'a t -> 'a t

(* apply a transformation and memoise *)
val apply : 'a t -> context -> 'a

(* clear the datastructures used to store the memoisation *)
val clear : 'a t -> unit

(** General constructors *)
(* create a transformation with only one memoisation *)
val register :
  ?clear:(unit -> unit) ->
  (context -> 'a) -> 'a t

(* Fold from the first declaration to the last with a memoisation at
   each step *)
val fold :
  ?clear:(unit -> unit) ->
  (context -> 'a -> 'a) -> 'a -> 'a t

val fold_map :
  ?clear:(unit -> unit) ->
  (context  -> 'a * context -> 'a * context) -> 'a -> 
  context t

val map :
  ?clear:(unit -> unit) ->
  (context -> context -> context) -> context t


val map_concat :
  ?clear:(unit -> unit) ->
  (context -> decl list) -> context t


(* map the element of the list without an environnment.
   A memoisation is performed at each step, and for each elements *)
val elt :
  ?clear:(unit -> unit) ->
  (decl -> decl list) -> context t


(** Utils *)
(*type odecl =
  | Otype of ty_decl
  | Ologic of logic_decl
  | Oprop of prop_decl
  | Ouse   of theory
  | Oclone of (ident * ident) list
*)
(*
val elt_of_oelt :
  ty:(ty_decl -> ty_decl) ->
  logic:(logic_decl -> logic_decl) ->
  ind:(ind_decl list -> decl list) ->
  prop:(prop_decl -> decl list) ->
  use:(theory -> decl list) ->
  clone:(theory -> (ident * ident) list -> decl list) ->
  (decl -> decl list)

val fold_context_of_decl:
  (context -> 'a -> decl -> 'a * decl list) ->
  context -> 'a -> context -> decl -> ('a * context)
*)

(* Utils *)

val split_goals : unit -> context list t

val identity : context t
