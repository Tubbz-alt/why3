(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2020   --   Inria - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

(** {2 Interpretation of Why3 programs} *)

open Wstdlib
open Ident
open Term
open Ity
open Expr

(** {2 Interpreter values} *)

type value

module Mv : Extmap.S with type key = value

val v_ty : value -> Ty.ty

(** non defensive API for building [value]s: there are no checks that
   [ity] is compatible with the [value] being built *)

(* TODO: make it defensive? *)
val int_value : BigInt.t -> value
val range_value : ity -> BigInt.t -> value
val string_value : string -> value
val bool_value : bool -> value
val proj_value : ity -> lsymbol -> value -> value
val constr_value : ity -> rsymbol -> value list -> value
val purefun_value : result_ity:ity -> arg_ity:ity -> value Mv.t -> value -> value

val default_value_of_type : Env.env -> Pdecl.known_map -> ity -> value

val print_value : Format.formatter -> value -> unit

(** {2 Interpreter log} *)

module type Log = sig
  type exec_kind = ExecAbstract | ExecConcrete

  type log_entry_desc = private
    | Val_assumed of (ident * value)
    | Const_init of ident
    | Exec_call of (rsymbol option * value Mvs.t  * exec_kind)
    | Exec_pure of (lsymbol * exec_kind)
    | Exec_any of (rsymbol option * value Mvs.t)
    | Exec_loop of exec_kind
    | Exec_main of (rsymbol * value Mvs.t * value Mrs.t)
    | Exec_stucked of (string * value Mid.t)
    | Exec_failed of (string * value Mid.t)
    | Exec_ended

  type log_entry = private {
    log_desc : log_entry_desc;
    log_loc  : Loc.position option;
  }

  type exec_log
  type log_uc

  val log_val : log_uc -> ident -> value -> Loc.position option -> unit
  val log_const : log_uc -> ident -> Loc.position option -> unit
  val log_call : log_uc -> rsymbol option -> value Mvs.t ->
                 exec_kind -> Loc.position option -> unit
  val log_pure_call : log_uc -> lsymbol -> exec_kind ->
                      Loc.position option -> unit
  val log_any_call : log_uc -> rsymbol option -> value Mvs.t
                     -> Loc.position option -> unit
  val log_exec_loop : log_uc -> exec_kind -> Loc.position option -> unit
  val log_exec_main : log_uc -> rsymbol -> value Mvs.t -> value Mrs.t ->
                      Loc.position option -> unit
  val log_failed : log_uc -> string -> value Mid.t ->
                   Loc.position option -> unit
  val log_stucked : log_uc -> string -> value Mid.t ->
                    Loc.position option -> unit
  val log_exec_ended : log_uc -> Loc.position option -> unit
  val empty_log_uc : unit -> log_uc
  val empty_log : exec_log
  val close_log : log_uc -> exec_log
  val sort_log_by_loc : exec_log -> log_entry list Mint.t Mstr.t
  val print_log : ?verb_lvl:int -> json:bool -> exec_log Pp.pp
end

module Log : Log

(** {2 Interpreter configuration} *)

val init_real : int * int * int -> unit
(** Give a precision on real computation. *)

type rac_prover
(** The configuration of the prover used for reducing terms in RAC *)

val rac_prover : command:string -> Driver.driver -> Call_provers.resource_limit -> rac_prover

type rac_reduce_config
(** The configuration for RAC, including (optionally) a transformation for reducing terms
   (usually: compute_in_goal), and a prover to be used if the transformation does not
   yield a truth value. When neither transformation nor prover are defined, then RAC does
   not progress. *)

val rac_reduce_config :
  ?trans:Task.task Trans.tlist ->
  ?prover:rac_prover ->
  unit -> rac_reduce_config

(** [rac_reduce_config_lit cnf env ?trans ?prover ()] configures the term reduction of
   RAC. [trans] is the name of a transformation (usually "compute_in_goal"). [prover] is a
   prover string with optional, space-sparated time limit and memory limit. *)
val rac_reduce_config_lit :
  Whyconf.config -> Env.env -> ?trans:string -> ?prover:string ->
  unit -> rac_reduce_config

type import_value = ?name:string -> ?loc:Loc.position -> ity -> value option

type rac_config = private {
  do_rac : bool;
  (** check assertions *)
  rac_abstract : bool;
  (** interpret abstractly *)
  skip_cannot_compute : bool;
  (** continue when term cannot be checked *)
  rac_reduce : rac_reduce_config;
  (** configuration for reducing terms *)
  get_value : import_value;
  (** import values when they are needed *)
  log_uc : Log.log_uc;
  (** log *)
}

val rac_config :
  do_rac:bool ->
  abstract:bool ->
  ?skip_cannot_compute:bool ->
  ?reduce:rac_reduce_config ->
  ?get_value:(?name:string -> ?loc:Loc.position -> ity -> value option) ->
  unit -> rac_config

(** {2 Interpreter environment and results} *)

(** Context for the interpreter *)
type env = private {
  mod_known   : Pdecl.known_map;
  th_known    : Decl.known_map;
  funenv      : cexp Mrs.t;
  vsenv       : value Mvs.t;
  rsenv       : value Mrs.t; (* global constants *)
  env         : Env.env;
  rac         : rac_config;
}

(** Result of the interpreter **)
type result = private
  | Normal of value
  | Excep of xsymbol * value
  | Irred of expr

(** Context of a contradiction during RAC *)
type cntr_ctx = private {
  c_desc: string;
  c_trigger_loc: Loc.position option;
  c_env: env
}

exception CannotCompute of {reason: string}
(** raised when interpretation cannot continue due to unsupported
   feature *)
exception Contr of cntr_ctx * term
(** raised when a contradiction is detected during RAC. *)
exception RACStuck of env * Loc.position option
(** raised when an assumed property is not satisfied *)

(** {2 Interpreter} *)

val eval_global_fundef :
  rac_config ->
  Env.env ->
  Pdecl.known_map ->
  Decl.known_map ->
  (rsymbol * cexp) list ->
  expr ->
  result * value Mvs.t * value Mrs.t
(** [eval_global_fundef ~rac env pkm dkm rcl e] evaluates [e] and
   returns an evaluation result and a final variable environment (for
   both local and global variables).

   During RAC, annotations are first reduced by applying
   transformation [rac.rac_trans], and if the transformation doesn't
   return to a trivial formula ([true]/[false]), the prover
   [rac.rac_prover] is applied. Pure expressions and pure executions
   are reduced only using [rac.rac_trans]. When neither [ra.rac_trans]
   or [rac.rac_prover] are defined, RAC does not progress.

   raises [Contr _] if [rac.rac] and a an assertion was violated.

   raises [CannotCompute _] if some term could not be reduced due to
   unsopported feature.

   raises [Failure _] if there is an unsopported feature.

   raises [RACStuck _] if a property that should be assumed is not
   satisfied in the current enviroment. *)

val report_cntr : Format.formatter -> cntr_ctx * term -> unit
val report_cntr_body : Format.formatter -> cntr_ctx * term -> unit
(** Report a contradiction context and term *)

val report_eval_result :
  expr -> Format.formatter -> result * value Mvs.t * value Mrs.t -> unit
(** Report an evaluation result *)

val eval_rs : rac_config -> Env.env -> Pmodule.pmodule -> rsymbol -> result * env
(** [eval_rs ~rac env pm rs] evaluates the definition of [rs] and
   returns an evaluation result and a final environment.

  raises [Contr _] if [rac.rac] and a an assertion was violated.

  raises [CannotCompute _] if some term could not be reduced due to
   unsopported feature.

  raises [Failure _] if there is an unsopported feature.

  raises [RACStuck _] if a property that should be assumed is not
   satisfied in the current enviroment. *)

(**/**)

(** {2 Some auxilaries that are shared with module [Counterexample]} *)

(** [ty_app_arg ts n ty] returns the [n]-th argument of the type application of [ts] in
   [ty]. Fails if [ty] is not an type application of [ts] *)
val ty_app_arg : Ty.tysymbol -> int -> Ty.ty -> Ty.ty

(** Gets the components of an ity *)
val ity_components : Ity.ity -> Ity.itysymbol * Ity.ity list * Ity.ity list

(** Checks if the argument is a range type *)
val is_range_ty : Ty.ty -> bool
