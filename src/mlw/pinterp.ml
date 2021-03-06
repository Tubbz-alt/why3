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

open Format
open Wstdlib
open Term
open Ident
open Ty
open Pretty
open Ity
open Expr

let debug_trace_exec =
  Debug.register_info_flag "trace_exec"
    ~desc:"trace execution of code given by --exec or --eval"
(* print debug information during the interpretation of an expression *)

let debug_rac_values =
  Debug.register_info_flag "rac-values"
    ~desc:"print values that are taken into account during interpretation"
(* print debug information about the values that are imported during
   interpretation *)

let debug_rac_check_sat =
  Debug.register_info_flag "rac-check-term-sat"
    ~desc:"satisfiability of terms in rac"
(* print debug information when checking the satisfiability of terms
   during rac *)
let debug_rac_check_term_result =
  Debug.register_info_flag "rac-check-term-result"
    ~desc:"print the result when terms are checked for validity"

let pp_bindings ?(sep = Pp.semi) ?(pair_sep = Pp.arrow) ?(delims = Pp.(lbrace, rbrace))
    pp_key pp_value fmt l =
  let pp_binding fmt (k, v) =
    fprintf fmt "@[<h>%a%a%a@]" pp_key k pair_sep () pp_value v in
  fprintf fmt "%a%a%a" (fst delims) ()
    (Pp.print_list sep pp_binding)
    l (snd delims) ()

let pp_indent fmt =
  match Printexc.(backtrace_slots (get_callstack 100)) with
  | None -> ()
  | Some a ->
      let n = Pervasives.max 0 (Array.length a - 25) in
      let s = String.make (2 * n) ' ' in
      pp_print_string fmt s

(* Test for declarations program constants with logical counterparts. These values are
   kept in the [rsenv] environment *)
let is_prog_constant d =
  let open Pdecl in
  match d.pd_node with
  | PDlet (LDsym (_, {c_cty= {cty_args= []}})) -> true
  | _ -> false

let ity_components ity = match ity.ity_node with
  | Ityapp (ts, l1, l2)
  | Ityreg {reg_its= ts; reg_args= l1; reg_regs= l2} ->
      ts, l1, l2
  | _ -> failwith "ity_components"

let is_range_ty ty =
  let its, _, _ = ity_components (ity_of_ty ty) in
  Ty.is_range_type_def its.its_def

(* EXCEPTIONS *)

exception NoMatch
exception Undetermined
exception CannotCompute of {reason: string}
exception NotNum
exception CannotFind of (Env.pathname * string * string)

let cannot_compute f =
  kasprintf (fun reason -> raise (CannotCompute {reason})) f

(* VALUES *)

type float_mode = Mlmpfr_wrapper.mpfr_rnd_t

type big_float = Mlmpfr_wrapper.mpfr_float

let mode_to_string m =
  let open Mlmpfr_wrapper in
  match m with
  | To_Nearest -> "RNE"
  | Away_From_Zero -> "RNA"
  | Toward_Plus_Infinity -> "RTP"
  | Toward_Minus_Infinity -> "RTN"
  | Toward_Zero -> "RTZ"
  | Faithful -> assert false

module rec Value : sig
  type value = {v_desc: value_desc; v_ty: ty}
  and value_desc =
    | Vconstr of rsymbol * field list
    | Vnum of BigInt.t
    | Vreal of Big_real.real
    | Vfloat_mode of float_mode
    | Vfloat of big_float
    | Vstring of string
    | Vbool of bool
    | Vvoid
    | Vproj of lsymbol * value
    | Varray of value array
    | Vfun of value Mvs.t (* closure *) * vsymbol * expr
    | Vpurefun of ty (* keys *) * value Mv.t * value
    | Vterm of term (* ghost values *)
    | Vundefined
  and field = Field of value ref
  val compare_values : value -> value -> int
end = struct
  type value = {v_desc: value_desc; v_ty: ty}
  and value_desc =
    | Vconstr of rsymbol * field list
    | Vnum of BigInt.t
    | Vreal of Big_real.real
    | Vfloat_mode of float_mode
    | Vfloat of big_float
    | Vstring of string
    | Vbool of bool
    | Vvoid
    | Vproj of lsymbol * value
    | Varray of value array
    | Vfun of value Mvs.t (* closure *) * vsymbol * expr
    | Vpurefun of ty (* keys *) * value Mv.t * value
    | Vterm of term
    | Vundefined
  and field = Field of value ref

  open Util

  let rec compare_values v1 v2 =
    if v1.v_desc = Vundefined then
      cannot_compute "undefined value of type %a cannot be compared" print_ty v1.v_ty;
    if v2.v_desc = Vundefined then
      cannot_compute "undefined value of type %a cannot be compared" print_ty v2.v_ty;
    let v_ty v = v.v_ty and v_desc v = v.v_desc in
    cmp [cmptr v_ty ty_compare; cmptr v_desc compare_desc] v1 v2
  and compare_desc d1 d2 =
    match d1, d2 with
    | Vproj (ls1, v1), Vproj (ls2, v2) ->
        cmp [cmptr fst ls_compare; cmptr snd compare_values] (ls1, v1) (ls2, v2)
    | Vproj _, _ -> -1 | _, Vproj _ -> 1
    | Vconstr (rs1, fs1), Vconstr (rs2, fs2) ->
        let field_get (Field f) = !f in
        let cmp_fields = cmp_lists [cmptr field_get compare_values] in
        cmp [cmptr fst rs_compare; cmptr snd cmp_fields] (rs1, fs1) (rs2, fs2)
    | Vconstr _, _ -> -1 | _, Vconstr _ -> 1
    | Vnum i1, Vnum i2 ->
        BigInt.compare i1 i2
    | Vnum _, _ -> -1 | _, Vnum _ -> 1
    | Vreal r1, Vreal r2 ->
        Big_real.(if eq r1 r2 then 0 else if lt r1 r2 then -1 else 1)
    | Vreal _, _ -> -1 | _, Vreal _ -> 1
    | Vfloat_mode m1, Vfloat_mode m2 ->
        compare m1 m2
    | Vfloat_mode _, _ -> -1 | _, Vfloat_mode _ -> 1
    | Vfloat f1, Vfloat f2 ->
        Mlmpfr_wrapper.(if equal_p f1 f2 then 0 else if less_p f1 f2 then -1 else 1)
    | Vfloat _, _ -> -1 | _, Vfloat _ -> 1
    | Vstring s1, Vstring s2 ->
        String.compare s1 s2
    | Vstring _, _ -> -1 | _, Vstring _ -> 1
    | Vbool b1, Vbool b2 ->
        compare b1 b2
    | Vbool _, _ -> -1 | _, Vbool _ -> 1
    | Vvoid, Vvoid -> 0
    | Vvoid, _ -> -1 | _, Vvoid -> 1
    | Vfun _, Vfun _ ->
        failwith "Value.compare: Vfun"
    | Vfun _, _ -> -1 | _, Vfun _ -> 1
    | Vpurefun (ty1, mv1, v1), Vpurefun (ty2, mv2, v2) ->
        cmp [
          cmptr (fun (x,_,_) -> x) ty_compare;
          cmptr (fun (_,x,_) -> x) (Mv.compare compare_values);
          cmptr (fun (_,_,x) -> x) compare_values;
        ] (ty1, mv1, v1) (ty2, mv2, v2)
    | Vpurefun _, _ -> -1 | _, Vpurefun _ -> 1
    | Vterm t1, Vterm t2 ->
        t_compare t1 t2
    | Vterm _, _ -> -1 | _, Vterm _ -> 1
    | Varray a1, Varray a2 ->
        cmp [
          cmptr Array.length (-);
          cmptr Array.to_list (cmp_lists [cmptr (fun x -> x) compare_values]);
        ] a1 a2
    | Vundefined, _ | _, Vundefined -> assert false
end
and Mv : Extmap.S with type key = Value.value =
  Extmap.Make (struct
    type t = Value.value
    let compare = Value.compare_values
  end)

include Value

let value ty desc = {v_desc= desc; v_ty= ty}
let field v = Field (ref v)
let constr rs vl = Vconstr (rs, List.map field vl)
let v_desc v = v.v_desc
let v_ty v = v.v_ty
let field_get (Field r) = r.contents
let field_set (Field r) v = r := v

let int_value n = value ty_int (Vnum n)
let range_value ity n = value (ty_of_ity ity) (Vnum n)
let string_value s = value ty_str (Vstring s)
let bool_value b = value ty_bool (Vbool b)
let proj_value ity ls v =
  value (ty_of_ity ity) (Vproj (ls, v))
let constr_value ity rs vl =
  value (ty_of_ity ity) (Vconstr (rs, List.map field vl))
let purefun_value ~result_ity ~arg_ity mv v =
  value (ty_of_ity result_ity) (Vpurefun (ty_of_ity arg_ity, mv, v))

let rec print_value fmt v =
  match v.v_desc with
  | Vnum n ->
      if BigInt.ge n BigInt.zero then
        fprintf fmt "%s" (BigInt.to_string n)
      else
        fprintf fmt "(%s)" (BigInt.to_string n)
  | Vbool b -> fprintf fmt "%b" b
  | Vreal r -> Big_real.print_real fmt r
  | Vfloat f ->
      (* Getting "@" is intentional in mlmpfr library for bases higher than 10.
         So, we keep this notation. *)
      let hexadecimal = Mlmpfr_wrapper.get_formatted_str ~base:16 f in
      let decimal = Mlmpfr_wrapper.get_formatted_str ~base:10 f in
      fprintf fmt "%s (%s)" decimal hexadecimal
  | Vfloat_mode m -> fprintf fmt "%s" (mode_to_string m)
  | Vstring s -> Constant.print_string_def fmt s
  | Vvoid -> fprintf fmt "()"
  | Vfun (mvs, vs, e) ->
      fprintf fmt "(@[<v2>%tfun %a -> %a)@]"
        (fun fmt ->
           if not (Mvs.is_empty mvs) then
             fprintf fmt "%a " (pp_bindings print_vs print_value) (Mvs.bindings mvs))
        print_vs vs print_expr e
  | Vproj (ls, v) ->
      fprintf fmt "{%a => %a}" print_ls ls print_value v
  | Vconstr (rs, vl) when is_rs_tuple rs ->
      fprintf fmt "(@[%a)@]" (Pp.print_list Pp.comma print_field) vl
  | Vconstr (rs, []) -> fprintf fmt "@[%a@]" print_rs rs
  | Vconstr (rs, vl) ->
      fprintf fmt "(@[%a %a)@]" print_rs rs
        (Pp.print_list Pp.space print_field)
        vl
  | Varray a ->
      fprintf fmt "@[[%a]@]"
        (Pp.print_list Pp.semi print_value)
        (Array.to_list a)
  | Vpurefun (_, mv, v) ->
      fprintf fmt "@[[|%a; _ -> %a|]@]" (pp_bindings ~delims:Pp.(nothing,nothing) print_value print_value)
        (Mv.bindings mv) print_value v
  | Vterm t ->
      print_term fmt t
  | Vundefined -> fprintf fmt "UNDEFINED"

and print_field fmt f = print_value fmt (field_get f)

let rec snapshot v =
  let v_desc = match v.v_desc with
    | Vconstr (rs, fs) -> Vconstr (rs, List.map snapshot_field fs)
    | Vfun (cl, vs, e) -> Vfun (Mvs.map snapshot cl, vs, e)
    | Vpurefun (ty, mv, v) ->
        let mv = Mv.(fold (fun k v -> add (snapshot k) (snapshot v)) mv empty) in
        Vpurefun (ty, mv, snapshot v)
    | Vproj (rs, v) -> Vproj (rs, snapshot v)
    | Varray a -> Varray (Array.map snapshot a)
    | Vfloat _ | Vstring _ | Vterm _ | Vbool _ | Vreal _
    | Vfloat_mode _ | Vvoid | Vnum _ | Vundefined as vd -> vd in
  {v with v_desc}

and snapshot_field f =
  field (snapshot (field_get f))

let ls_undefined =
  let ty_a = ty_var (create_tvsymbol (id_fresh "a")) in
  create_fsymbol (id_fresh "undefined") [] ty_a

(** [ty_app_arg ts nth ty] returns the nth argument in the type application [ty]. Fails
   when ty is not a type application of [ts] *)
let ty_app_arg ts ix ty = match ty.ty_node with
  | Tyapp (ts', ty_args) when ts_equal ts' ts ->
      List.nth ty_args ix
  | _ ->
      let s = Printexc.get_callstack 100 in
      Printexc.print_raw_backtrace stderr s;
      flush stderr;
      kasprintf failwith "@[<h>ty_arg: not a type application of %a: %a@]" print_ts ts print_ty ty

(* RESULT *)

type result =
  | Normal of value
  | Excep of xsymbol * value
  | Irred of expr

let print_logic_result fmt r =
  match r with
  | Normal v -> fprintf fmt "@[%a@]" print_value v
  | Excep (x, v) ->
      fprintf fmt "@[exception %s(@[%a@])@]" x.xs_name.id_string print_value v
  | Irred e -> fprintf fmt "@[Cannot execute expression@ @[%a@]@]" print_expr e

(* ENV *)

type rac_prover = Rac_prover of {
    command: string;
    driver: Driver.driver;
    limit: Call_provers.resource_limit;
  }

let rac_prover ~command driver limit =
  Rac_prover {command; driver; limit}

type rac_reduce_config = {
  rac_trans: Task.task Trans.tlist option;
  rac_prover: rac_prover option;
}

let rac_reduce_config ?trans:rac_trans ?prover:rac_prover () = {rac_trans; rac_prover}

let rac_reduce_config_lit config env ?trans ?prover () =
  let trans =
    let aux s = Trans.lookup_transform_l s env in
    Opt.map aux trans in
  let prover =
    let aux prover_string =
      let name, limit_time, limit_mem =
        match Strings.split ',' prover_string with
        | [name; limit_time; limit_mem] ->
            name, int_of_string limit_time, int_of_string limit_mem
        | [name; limit_time] ->
            name, int_of_string limit_time, 1000
        | [name] -> name, 1, 1000
        | _ -> failwith "RAC reduce prover config must have format <prover shortcut>[,<time limit>[,<mem limit>]]" in
      let prover = Whyconf.filter_one_prover config (Whyconf.parse_filter_prover name) in
      let command = String.concat " " (prover.Whyconf.command :: prover.Whyconf.extra_options) in
      let driver = Whyconf.load_driver (Whyconf.get_main config)
          env prover.Whyconf.driver prover.Whyconf.extra_drivers in
      let limit = Call_provers.{empty_limit with limit_time; limit_mem} in
      rac_prover ~command driver limit in
    Opt.map aux prover in
  rac_reduce_config ?trans ?prover ()

(* Interpretation log *)

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
  val log_any_call : log_uc -> rsymbol option -> value Mvs.t ->
                     Loc.position option -> unit
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

module Log : Log = struct
  type exec_kind = ExecAbstract | ExecConcrete

  type log_entry_desc =
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

  type log_entry = {
    log_desc : log_entry_desc;
    log_loc  : Loc.position option;
  }

  type log_uc = (log_entry list) ref
  (* new log elements are added to the head of the list *)

  type exec_log = log_entry list
  (* supposed to contain the reverse log_uc contents after close_log *)

  let empty_log_uc () = ref []

  let empty_log = []

  let log_entry log_uc log_desc log_loc =
    log_uc := {log_desc; log_loc} :: !log_uc

  let log_val log_uc id v loc =
    log_entry log_uc (Val_assumed (id,v)) loc

  let log_const log_uc id loc =
    log_entry log_uc (Const_init id) loc

  let log_call log_uc rs mvs kind loc =
    log_entry log_uc (Exec_call (rs,mvs,kind)) loc

  let log_pure_call log_uc ls kind loc =
    log_entry log_uc (Exec_pure (ls,kind)) loc

  let log_any_call log_uc rs mvs loc =
    log_entry log_uc (Exec_any (rs,mvs)) loc

  let log_exec_loop log_uc kind loc =
    log_entry log_uc (Exec_loop kind) loc

  let log_exec_main log_uc rs mvs mrs loc =
    log_entry log_uc (Exec_main (rs,mvs,mrs)) loc

  let log_failed log_uc s mvs loc =
    log_entry log_uc (Exec_failed (s,mvs)) loc

  let log_stucked log_uc s mvs loc =
    log_entry log_uc (Exec_stucked (s,mvs)) loc

  let log_exec_ended log_uc loc =
    log_entry log_uc Exec_ended loc

  let close_log log_uc = List.rev !log_uc

  let exec_kind_to_string ?(cap=true) = function
    | ExecAbstract -> if cap then "Abstract" else "abstract"
    | ExecConcrete -> if cap then "Concrete" else "concrete"

  (** Partition a list of elements into lists of pairs, of consecutive
      elements with the same value for f *)
  let rec consecutives key ?(sofar=[]) ?current xs =
    let to_list = function Some (k, xs) -> [Some k, List.rev xs] | None -> [] in
    match xs with
    | [] -> List.rev (to_list current @ sofar)
    | x :: xs -> match key x with
      | None -> consecutives key ~sofar:((None, [x]) :: to_list current @ sofar) xs
      | Some k -> match current with
        | None ->
            consecutives key ~sofar ~current:(k, [x]) xs
        | Some (k', xs') when k' = k ->
            consecutives key ~sofar ~current:(k, x::xs') xs
        | Some _ ->
            consecutives key ~sofar:(to_list current @ sofar) ~current:(k, [x]) xs

  let print_log_entry_desc fmt e =
    let print_assoc key2string fmt (k,v) =
      fprintf fmt "@[%a = %a@]"
        print_decoded (key2string k) print_value v in
    let print_list key2string =
      Pp.print_list_pre Pp.newline (print_assoc key2string) in
    let vs2string vs = vs.vs_name.id_string in
    let rs2string rs = rs.rs_name.id_string in
    let id2string id = id.id_string in
    match e.log_desc with
    | Val_assumed (id, v) ->
        fprintf fmt "@[<h2>%a = %a@]" print_decoded id.id_string print_value v;
    | Const_init id ->
        fprintf fmt "@[<h2>Constant %a initialization@]" print_decoded id.id_string;
    | Exec_call (None, mvs, k) ->
        fprintf fmt "@[<h2>%s execution of anonymous function with args:%a@]"
          (exec_kind_to_string k)
          (print_list vs2string) (Mvs.bindings mvs)
    | Exec_call (Some rs, mvs, k) ->
        fprintf fmt "@[<h2>%s execution of %a with args:%a@]"
          (exec_kind_to_string k)
          print_decoded rs.rs_name.id_string
          (print_list vs2string) (Mvs.bindings mvs)
    | Exec_pure (ls,k) ->
        fprintf fmt "@[<h2>%s execution of %a@]" (exec_kind_to_string k)
          print_decoded ls.ls_name.id_string
    | Exec_any (rs,mvs) ->
         fprintf fmt
           "@[<h2>(abstract) execution of any function%s%a%s%a@]"
           (if rs = None then "" else " ")
           (Pp.print_option Pp.string) (Opt.map (fun rs -> rs.rs_name.id_string) rs)
           (if Mvs.is_empty mvs then "" else " with args:")
           (print_list vs2string) (Mvs.bindings mvs)
    | Exec_loop k ->
        fprintf fmt "@[<h2>%s execution of loop@]" (exec_kind_to_string k)
    | Exec_main (rs, mvs, mrs) ->
        fprintf fmt "@[<h2>Execution of main function %a's body with env:%a%a@]"
          print_decoded rs.rs_name.id_string
          (print_list vs2string) (Mvs.bindings mvs)
          (print_list rs2string) (Mrs.bindings mrs)
    | Exec_failed (msg,mid) ->
       fprintf fmt "@[<h2>Property failure, %s with:%a@]"
         msg (print_list id2string) (Mid.bindings mid)
    | Exec_stucked (msg,mid) ->
       fprintf fmt "@[<h2>Execution got stuck, %s with:%a@]"
         msg (print_list id2string) (Mid.bindings mid)
    | Exec_ended ->
        fprintf fmt "@[<h2>Execution of main function terminated normally@]"

  (** verbosity level:
     1 : just imported values
     2 : + execution of function calls
     3 : + execution of loops
     4 : + termination of execution
     5 : + log information about initialization of global vars
   *)
  let print_log ?(verb_lvl=4) ~json fmt entry_log =
    if json then
      let open Json_base in
      let string f = kasprintf (fun s -> String s) f in
      let print_json_kind fmt = function
        | ExecAbstract -> print_json fmt (string "ABSTRACT")
        | ExecConcrete -> print_json fmt (string "CONCRETE") in
      let print_key_value key2string fmt (k,v) =
        fprintf fmt "@[@[<hv1>{%a;@ %a@]}@]"
          (print_json_field "name" print_json) (String (key2string k))
          (print_json_field "value" print_value) v in
      let vs2string vs = vs.vs_name.id_string in
      let id2string id = id.id_string in
      let print_log_entry fmt = function
        | Val_assumed (id, v) ->
            fprintf fmt "@[@[<hv1>{%a;@ %a;@ %a@]}@]"
              (print_json_field "kind" print_json) (string "VAL_ASSUMED")
              (print_json_field "vs" print_json)
              (string "%a" print_decoded id.id_string)
              (print_json_field "value" print_value) v
        | Const_init id ->
            fprintf fmt "@[@[<hv1>{%a;@ %a@]}@]"
              (print_json_field "kind" print_json) (string "CONST_INIT")
              (print_json_field "id" print_json)
              (string "%a" print_decoded id.id_string)
        | Exec_call (ors, mvs, kind) ->
            fprintf fmt "@[@[<hv1>{%a;@ %a;@ %a;@ %a@]}@]"
              (print_json_field "kind" print_json) (string "EXEC_CALL")
              (print_json_field "rs" print_json) (match ors with
                  | Some rs -> string "%a" print_decoded rs.rs_name.id_string
                  | None -> Null)
              (print_json_field "exec" print_json_kind) kind
              (print_json_field "args" (list (print_key_value vs2string)))
              (Mvs.bindings mvs)
        | Exec_pure (ls, kind) ->
            fprintf fmt "@[@[<hv1>{%a;@ %a;@ %a@]}@]"
              (print_json_field "kind" print_json) (string "EXEC_PURE")
              (print_json_field "ls" print_json) (string "%a" print_ls ls)
              (print_json_field "exec" print_json_kind) kind
        | Exec_any (ors,mvs) ->
            fprintf fmt "@[@[<hv1>{%a;@ %a;@ %a@]}@]"
              (print_json_field "kind" print_json) (string "EXEC_ANY")
              (print_json_field "rs" print_json) (match ors with
                  | Some rs -> string "%a" print_decoded rs.rs_name.id_string
                  | None -> Null)
              (print_json_field "args" (list (print_key_value vs2string)))
              (Mvs.bindings mvs)
        | Exec_loop kind ->
            fprintf fmt "@[@[<hv1>{%a;@ %a@]}@]"
          (print_json_field "kind" print_json) (string "EXEC_LOOP")
          (print_json_field "exec" print_json_kind) kind
        | Exec_main (rs,mvs,mrs) ->
           let mid = Mvs.fold (fun vs v mid -> Mid.add vs.vs_name v mid) mvs Mid.empty in
           let mid = Mrs.fold (fun rs v mid -> Mid.add rs.rs_name v mid) mrs mid in
           fprintf fmt "@[@[<hv1>{%a;@ %a;@ %a@]}@]"
             (print_json_field "kind" print_json) (string "EXEC_MAIN")
             (print_json_field "rs" print_json)
             (string "%a" print_decoded rs.rs_name.id_string)
             (print_json_field "env" (list (print_key_value id2string)))
             (Mid.bindings mid)
        | Exec_failed (reason,mid) ->
            fprintf fmt "@[@[<hv1>{%a;@ %a;@ %a@]}@]"
              (print_json_field "kind" print_json) (string "FAILED")
              (print_json_field "reason" print_json) (String reason)
              (print_json_field "state" (list (print_key_value id2string)))
              (Mid.bindings mid)
        | Exec_stucked (reason,mid) ->
            fprintf fmt "@[@[<hv1>{%a;@ %a;@ %a@]}@]"
              (print_json_field "kind" print_json) (string "STUCKED")
              (print_json_field "reason" print_json) (String reason)
              (print_json_field "state" (list (print_key_value id2string)))
              (Mid.bindings mid)
        | Exec_ended ->
            fprintf fmt "@[@[<hv1>{%a@]}@]"
              (print_json_field "kind" print_json) (string "ENDED") in
      let print_json_entry fmt e =
        fprintf fmt "@[@[<hv1>{@[<hv2>%a@];@ @[<hv2>%a@]@]}@]"
          (Pp.print_option_or_default "NOLOC"
             (print_json_field "loc" print_json_loc)) e.log_loc
          (print_json_field "entry" print_log_entry) e.log_desc in
      fprintf fmt "@[@[<hv1>[%a@]@]"
        Pp.(print_list comma print_json_entry) entry_log
    else
      let entry_log = List.filter (fun le ->
            match le.log_desc with
            | Val_assumed _ | Const_init _ | Exec_main _ -> true
            | Exec_call _ | Exec_pure _ | Exec_any _
                 when verb_lvl > 1 -> true
            | Exec_loop _ when verb_lvl > 2 -> true
            | Exec_failed _ | Exec_stucked _ | Exec_ended
                 when verb_lvl > 3 -> true
            | _ -> false) entry_log in
      (* if verb_lvl < 5 remove log about initialization of global vars *)
      let entry_log =
        if verb_lvl < 5 then
          Lists.drop_while (fun le ->
              match le.log_desc with
                Exec_main _ -> false | _ -> true) entry_log
        else entry_log in
      let entry_log =
        let on_file e = Opt.map (fun (f,_,_,_) -> f) (Opt.map Loc.get e.log_loc) in
        let on_line e = Opt.map (fun (_,l,_,_) -> l) (Opt.map Loc.get e.log_loc) in
        List.map (fun (f, es) -> f, consecutives on_line es)
          (consecutives on_file entry_log) in
      let pp_entries = Pp.(print_list newline print_log_entry_desc) in
      let pp_lines fmt (opt_line, entries) = match opt_line with
        | Some line -> fprintf fmt "@[<v2>Line %d:@\n%a@]" line pp_entries entries
        | None -> pp_entries fmt entries in
      let pp_files fmt (opt_file, l) = match opt_file with
        | Some file -> fprintf fmt "@[<v2>File %s:@\n%a@]" (Filename.basename file) Pp.(print_list newline pp_lines) l
        | None -> fprintf fmt "@[<v4>Unknown location:@\n%a@]" Pp.(print_list newline pp_lines) l in
      Pp.(print_list newline pp_files) fmt entry_log

  let sort_log_by_loc log =
    let insert f l e sofar =
      let insert_line opt_l =
        let l = Opt.get_def [] opt_l in
        Some (e :: l) in
      let insert_file opt_mf =
        let mf = Opt.get_def Mint.empty opt_mf in
        let res = Mint.change insert_line l mf in
        Some res in
      Mstr.change insert_file f sofar in
    let aux entry sofar = match entry.log_loc with
      | Some loc when not (Loc.equal loc Loc.dummy_position) ->
          let f, l, _, _ = Loc.get loc in
          insert f l entry sofar
      | _ -> sofar in
    Mstr.map (Mint.map List.rev)
      (List.fold_right aux log Mstr.empty)

end

(** RAC configuration  *)

type import_value = ?name:string -> ?loc:Loc.position -> ity -> value option

type rac_config = {
  do_rac              : bool;
  rac_abstract        : bool;
  skip_cannot_compute : bool; (* skip if it cannot compute, when possible *)
  rac_reduce          : rac_reduce_config;
  get_value           : import_value;
  log_uc              : Log.log_uc;
}

let default_get_value ?name:_ ?loc:_ _ = None

let rac_config ~do_rac ~abstract:rac_abstract
      ?(skip_cannot_compute=true)
      ?reduce:rac_reduce
      ?(get_value=default_get_value) () =
  let rac_reduce = match rac_reduce with
    | Some r -> r
    | None -> rac_reduce_config () in
  {do_rac; rac_abstract; rac_reduce; log_uc= Log.empty_log_uc ();
   get_value; skip_cannot_compute }

type env =
  { mod_known   : Pdecl.known_map;
    th_known    : Decl.known_map;
    funenv      : cexp Mrs.t;
    vsenv       : value Mvs.t;
    rsenv       : value Mrs.t; (* global constants *)
    env         : Env.env;
    rac         : rac_config;
  }

let default_env env rac mod_known th_known =
  { mod_known; th_known; rac; env; funenv= Mrs.empty; vsenv= Mvs.empty; rsenv= Mrs.empty }

let register_used_value env loc id value =
  Log.log_val env.rac.log_uc id (snapshot value) loc

let register_const_init env loc id =
  Log.log_const env.rac.log_uc id loc

let register_call env loc rs mvs kind =
  Log.log_call env.rac.log_uc rs mvs kind loc

let register_pure_call env loc ls kind =
  Log.log_pure_call env.rac.log_uc ls kind loc

let register_any_call env loc rs mvs =
  Log.log_any_call env.rac.log_uc rs mvs loc

let register_loop env loc kind =
  Log.log_exec_loop env.rac.log_uc kind loc

let register_exec_main env rs =
  Log.log_exec_main env.rac.log_uc rs env.vsenv env.rsenv rs.rs_name.id_loc

let register_failure env loc reason mvs =
  Log.log_failed env.rac.log_uc reason mvs loc

let register_stucked env loc reason mvs =
  Log.log_stucked env.rac.log_uc reason mvs loc

let register_ended env loc =
  Log.log_exec_ended env.rac.log_uc loc

let snapshot_env env = {env with vsenv= Mvs.map snapshot env.vsenv}

let add_local_funs locals env =
  let add acc (rs, ce) = Mrs.add rs ce acc in
  let funenv = List.fold_left add env.funenv locals in
  {env with funenv}

let bind_vs vs v env = {env with vsenv= Mvs.add vs v env.vsenv}
let bind_rs rs v env = {env with rsenv= Mrs.add rs v env.rsenv}
let bind_pvs ?register pv v_t env =
  let env = bind_vs pv.pv_vs v_t env in
  Opt.iter (fun r -> r pv.pv_vs.vs_name v_t) register;
  env
let multibind_pvs ?register l tl env =
  List.fold_left2 (fun env pv v -> bind_pvs ?register pv v env) env l tl

(* BUILTINS *)

let big_int_of_const i = i.Number.il_int
let big_int_of_value v = match v.v_desc with Vnum i -> i | _ -> raise NotNum

let eval_int_op op ls l =
  value (ty_of_ity ls.rs_cty.cty_result)
    ( match List.map v_desc l with
    | [Vnum i1; Vnum i2] -> (
      try Vnum (op i1 i2) with NotNum | Division_by_zero -> constr ls l )
    | _ -> constr ls l )

let eval_int_uop op ls l =
  let v_desc =
    match List.map v_desc l with
    | [Vnum i1] -> ( try Vnum (op i1) with NotNum -> constr ls l )
    | _ -> constr ls l in
  {v_desc; v_ty=ty_of_ity ls.rs_cty.cty_result}

let eval_int_rel op ls l =
  let v_desc =
    match List.map v_desc l with
    | [Vnum i1; Vnum i2] -> (
      try Vbool (op i1 i2) with NotNum -> constr ls l )
    | _ -> constr ls l in
  {v_desc; v_ty= ty_bool}

(* This initialize Mpfr for float32 behavior *)
let initialize_float32 () =
  let open Mlmpfr_wrapper in
  set_default_prec 24 ; set_emin (-148) ; set_emax 128

(* This initialize Mpfr for float64 behavior *)
let initialize_float64 () =
  let open Mlmpfr_wrapper in
  set_default_prec 53 ; set_emin (-1073) ; set_emax 1024

type 'a float_arity =
  | Mode1 : (float_mode -> big_float -> big_float) float_arity (* Unary op *)
  | Mode2 : (float_mode -> big_float -> big_float -> big_float) float_arity (* binary op *)
  | Mode3
      : (float_mode -> big_float -> big_float -> big_float -> big_float)
        float_arity (* ternary op *)
  | Mode_rel : (big_float -> big_float -> bool) float_arity (* binary predicates *)
  | Mode_rel1 : (big_float -> bool) float_arity

let use_float_format (float_format : int) =
  match float_format with
  | 32 -> initialize_float32 ()
  | 64 -> initialize_float64 ()
  | _ -> cannot_compute "float format is unknown: %d" float_format

let eval_float :
    type a.
    tysymbol -> int -> a float_arity -> a -> rsymbol -> value list -> value =
 fun tys_result float_format ty op ls l ->
  (* Set the exponent depending on Float type that are used: 32 or 64 *)
 let ty_result = ty_app tys_result [] in
  use_float_format float_format ;
  try
    let v_desc =
      let open Mlmpfr_wrapper in
      match ty, List.map v_desc l with
      | Mode1, [Vfloat_mode mode; Vfloat f] ->
          (* Subnormalize used to simulate IEEE behavior *)
          Vfloat (subnormalize ~rnd:mode (op mode f))
      | Mode2, [Vfloat_mode mode; Vfloat f1; Vfloat f2] ->
          Vfloat (subnormalize ~rnd:mode (op mode f1 f2))
      | Mode3, [Vfloat_mode mode; Vfloat f1; Vfloat f2; Vfloat f3] ->
          Vfloat (subnormalize ~rnd:mode (op mode f1 f2 f3))
      | Mode_rel, [Vfloat f1; Vfloat f2] -> Vbool (op f1 f2)
      | Mode_rel1, [Vfloat f] -> Vbool (op f)
      | _ -> constr ls l in
    {v_desc; v_ty= ty_result}
  with
  | Mlmpfr_wrapper.Not_Implemented ->
      cannot_compute "mlmpfr wrapper is not implemented"
  | _ -> assert false

type 'a real_arity =
  | Modeconst : Big_real.real real_arity
  | Mode1r : (Big_real.real -> Big_real.real) real_arity
  | Mode2r : (Big_real.real -> Big_real.real -> Big_real.real) real_arity
  | Mode_relr : (Big_real.real -> Big_real.real -> bool) real_arity

let eval_real : type a. a real_arity -> a -> rsymbol -> value list -> value
    =
 fun ty op ls l ->
  let v_desc =
    try
      match ty, List.map v_desc l with
      | Mode1r, [Vreal r] -> Vreal (op r)
      | Mode2r, [Vreal r1; Vreal r2] -> Vreal (op r1 r2)
      | Mode_relr, [Vreal r1; Vreal r2] -> Vbool (op r1 r2)
      | Modeconst, [] -> Vreal op
      | _ -> constr ls l
    with
    | Big_real.Undetermined ->
        (* Cannot decide interval comparison *)
        constr ls l
    | Mlmpfr_wrapper.Not_Implemented ->
        cannot_compute "mlmpfr wrapper is not implemented"
    | _ -> assert false in
  {v_desc; v_ty= ty_real}

let builtin_progs = Hrs.create 17

type builtin = Builtin_module of {
  path: string list;
  name: string;
  types: (string * (Pdecl.known_map -> itysymbol -> unit)) list;
  values: Pmodule.pmodule -> (string * (rsymbol -> value list -> value)) list;
}

let dummy_type (_:Pdecl.known_map) (_:itysymbol) = ()

let builtin path name values =
  Builtin_module {path; name; types=[]; values= fun _ -> values}

let builtin1t path name (type_name, type_def) values =
  let values = fun pm ->
    let its = Pmodule.(ns_find_its pm.mod_export [type_name]) in
    values its.its_ts in
  Builtin_module {path; name; types= [type_name, type_def]; values}

(* Described as a function so that this code is not executed outside of
   why3execute. *)

(** Description of modules *)
let built_in_modules () =
  let int_ops = [
    op_infix "+",      eval_int_op BigInt.add;
    (* defined as x+(-y)
       op_infix "-",   eval_int_op BigInt.sub; *)
    op_infix "*",      eval_int_op BigInt.mul;
    op_prefix "-",     eval_int_uop BigInt.minus;
    op_infix "=",      eval_int_rel BigInt.eq;
    op_infix "<",      eval_int_rel BigInt.lt;
    op_infix "<=",     eval_int_rel BigInt.le;
    op_infix ">",      eval_int_rel BigInt.gt;
    op_infix ">=",     eval_int_rel BigInt.ge;
  ] in
  let bounded_int_ops = int_ops @ [
    "of_int",          eval_int_uop (fun x -> x);
    "to_int",          eval_int_uop (fun x -> x);
    op_infix "-",      eval_int_op BigInt.sub;
    op_infix "/",      eval_int_op BigInt.computer_div;
    op_infix "%",      eval_int_op BigInt.computer_mod;
  ] in
  let open Mlmpfr_wrapper in
  let float_module tyb ~prec m = builtin1t ["ieee_float"] m ("t", dummy_type) (fun ts -> [
    "zeroF",           (fun _ _ -> value (ty_app ts []) (Vfloat (make_zero ~prec Positive)));
    "add",             eval_float ts tyb Mode2 (fun rnd -> add ~rnd ~prec);
    "sub",             eval_float ts tyb Mode2 (fun rnd -> sub ~rnd ~prec);
    "mul",             eval_float ts tyb Mode2 (fun rnd -> mul ~rnd ~prec);
    "div",             eval_float ts tyb Mode2 (fun rnd -> div ~rnd ~prec);
    "abs",             eval_float ts tyb Mode1 (fun rnd -> abs ~rnd ~prec);
    "neg",             eval_float ts tyb Mode1 (fun rnd -> neg ~rnd ~prec);
    "fma",             eval_float ts tyb Mode3 (fun rnd -> fma ~rnd ~prec);
    "sqrt",            eval_float ts tyb Mode1 (fun rnd -> sqrt ~rnd ~prec);
    "roundToIntegral", eval_float ts tyb Mode1 (fun rnd -> rint ~rnd ~prec);
    (* Intentionnally removed from programs
       "min",          eval_float_minmax min;
       "max",          eval_float_minmax max; *)
    "le",              eval_float ts_bool tyb Mode_rel lessequal_p;
    "lt",              eval_float ts_bool tyb Mode_rel less_p;
    "eq",              eval_float ts_bool tyb Mode_rel equal_p;
    "is_zero",         eval_float ts_bool tyb Mode_rel1 zero_p;
    "is_infinite",     eval_float ts_bool tyb Mode_rel1 inf_p;
    "is_nan",          eval_float ts_bool tyb Mode_rel1 nan_p;
    "is_positive",     eval_float ts_bool tyb Mode_rel1 (fun s -> signbit s = Positive);
    "is_negative",     eval_float ts_bool tyb Mode_rel1 (fun s -> signbit s = Negative);
  ]) in
  [
    builtin ["bool"] "Bool" [
      "True",          (fun _ _ -> value ty_bool (Vbool true));
      "False",         (fun _ _ -> value ty_bool (Vbool false));
    ];
    builtin ["int"] "Int" int_ops;
    builtin ["int"] "MinMax" [
      "min",           eval_int_op BigInt.min;
      "max",           eval_int_op BigInt.max
    ];
    builtin ["int"] "ComputerDivision" [
      "div",           eval_int_op BigInt.computer_div;
      "mod",           eval_int_op BigInt.computer_mod
    ];
    builtin ["int"] "EuclideanDivision" [
      "div",           eval_int_op BigInt.euclidean_div;
      "mod",           eval_int_op BigInt.euclidean_mod
    ];
    builtin ["mach"; "int"] "Byte" bounded_int_ops;
    builtin ["mach"; "int"] "Int31" bounded_int_ops;
    builtin ["mach"; "int"] "Int63" bounded_int_ops;
    builtin1t ["ieee_float"] "RoundingMode" ("mode", dummy_type) (fun ts -> [
      "RNE",           (fun _ _ -> value (ty_app ts []) (Vfloat_mode To_Nearest));
      "RNA",           (fun _ _ -> value (ty_app ts []) (Vfloat_mode Away_From_Zero));
      "RTP",           (fun _ _ -> value (ty_app ts []) (Vfloat_mode Toward_Plus_Infinity));
      "RTN",           (fun _ _ -> value (ty_app ts []) (Vfloat_mode Toward_Minus_Infinity));
      "RTZ",           (fun _ _ -> value (ty_app ts []) (Vfloat_mode Toward_Zero));
    ]);
    builtin ["real"] "Real" [
      op_infix "=",    eval_real Mode_relr Big_real.eq;
      op_infix "<",    eval_real Mode_relr Big_real.lt;
      op_infix "<=",   eval_real Mode_relr Big_real.le;
      op_prefix "-",   eval_real Mode1r Big_real.neg;
      op_infix "+",    eval_real Mode2r Big_real.add;
      op_infix "*",    eval_real Mode2r Big_real.mul;
      op_infix "/",    eval_real Mode2r Big_real.div
    ];
    builtin ["real"] "Square" [
      "sqrt",          eval_real Mode1r Big_real.sqrt
    ];
    builtin ["real"] "Trigonometry" [
      "pi",            eval_real Modeconst (Big_real.pi ())
    ];
    builtin ["real"] "ExpLog" [
      "exp",           eval_real Mode1r Big_real.exp;
      "log",           eval_real Mode1r Big_real.log;
    ];
    builtin1t ["array"] "Array" ("array", dummy_type) (fun ts -> [
      "make", (fun _ args -> match args with
          | [{v_desc= Vnum n}; def] -> (
              try
                let n = BigInt.to_int n in
                let ty = ty_app ts [def.v_ty] in
                value ty (Varray (Array.make n def))
              with e -> cannot_compute "array could not be made: %a" Exn_printer.exn_printer e )
          | _ -> assert false);
      "empty", (fun _ args -> match args with
          | [{v_desc= Vconstr(_, [])}] ->
              (* we know by typing that the constructor
                  will be the Tuple0 constructor *)
              let ty = ty_app ts [ty_var (tv_of_string "a")] in
              value ty (Varray [||])
          | _ -> assert false);
      "length", (fun _ args -> match args with
          | [{v_desc= Varray a}] ->
              value ty_int (Vnum (BigInt.of_int (Array.length a)))
          | _ -> assert false) ;
      op_get "", (fun _ args -> match args with
          | [{v_desc= Varray a}; {v_desc= Vnum i}] -> (
              try a.(BigInt.to_int i)
              with e -> cannot_compute "array element could not be retrieved: %a" Exn_printer.exn_printer e )
          | _ -> assert false);
      op_set "", (fun _ args -> match args with
          | [{v_desc= Varray a}; {v_desc= Vnum i}; v] -> (
              try
                a.(BigInt.to_int i) <- v;
                value ty_unit Vvoid
              with e -> cannot_compute "array element could not be set: %a" Exn_printer.exn_printer e )
          | _ -> assert false) ;
        ]);
    float_module 32 ~prec:24 "Float32";
    float_module 64 ~prec:53 "Float64";
  ]

let add_builtin_mo env (Builtin_module {path; name; types; values}) =
  let open Pmodule in
  let pm = read_module env path name in
  List.iter
    (fun (id, r) ->
      let its =
        try Pmodule.ns_find_its pm.mod_export [id]
        with Not_found -> raise (CannotFind (path, name, id)) in
      r pm.mod_known its)
    types ;
  List.iter
    (fun (id, f) ->
      let ps =
        try Pmodule.ns_find_rs pm.mod_export [id]
        with Not_found -> raise (CannotFind (path, name, id)) in
      Hrs.add builtin_progs ps f)
    (values pm)

let get_builtin_progs env =
  List.iter (add_builtin_mo env) (built_in_modules ())

let get_vs env vs =
  try Mvs.find vs env.vsenv
  with Not_found ->
    ksprintf failwith "program variable %s not found in env"
      vs.vs_name.id_string

let get_pvs env pvs =
  get_vs env pvs.pv_vs

(* DEFAULTS *)

let is_array_its env its =
  let pm = Pmodule.read_module env ["array"] "Array" in
  let array_its = Pmodule.ns_find_its pm.Pmodule.mod_export ["array"] in
  its_equal its array_its

(* TODO Remove argument [env] after replacing Varray by model substitution *)
let rec default_value_of_type env known ity : value =
  let ty = ty_of_ity ity in
  match ity.ity_node with
  | Ityvar _ -> failwith "default_value_of_type: type variable"
  | Ityapp (ts, _, _) when its_equal ts its_int -> value ty (Vnum BigInt.zero)
  | Ityapp (ts, _, _) when its_equal ts its_real -> assert false (* TODO *)
  | Ityapp (ts, _, _) when its_equal ts its_bool -> value ty (Vbool false)
  | Ityapp (ts, _, _) when its_equal ts its_str -> value ty (Vstring "")
  | Ityapp(ts,ityl1,_) when is_ts_tuple ts.its_ts ->
     let fields = List.map (fun ity ->
       Field (ref (default_value_of_type env known ity))) ityl1 in
     let v = Vconstr (rs_tuple (List.length ityl1), fields) in
     value ty v
  | Ityapp (its, l1, l2)
  | Ityreg {reg_its= its; reg_args= l1; reg_regs= l2} ->
      if is_array_its env its then
        value ty (Varray (Array.init 0 (fun _ -> assert false)))
      else
        let itd = Pdecl.find_its_defn known its in
        match itd.Pdecl.itd_its.its_def with
        | Range r ->
            let zero_in_range = BigInt.(le r.Number.ir_lower zero && le zero r.Number.ir_upper) in
            let n = if zero_in_range then BigInt.zero else r.Number.ir_lower in
            value ty (Vnum n)
        | _ -> match itd.Pdecl.itd_constructors with
          | rs :: _ ->
              let subst = its_match_regs its l1 l2 in
              let ityl = List.map (fun pv -> pv.pv_ity) rs.rs_cty.cty_args in
              let tyl = List.map (ity_full_inst subst) ityl in
              let fl = List.map (fun ity -> field (default_value_of_type env known ity)) tyl in
              value ty (Vconstr (rs, fl))
          | [] ->
              (* if its.its_private then
               *   (\* There is no constructor so we can just invent a Vconstr,
               *      but we will have to axiomatize the corresponding term *\)
               *   let itys = List.map (fun rs -> (Opt.get rs.rs_field).pv_ity) itd.Pdecl.itd_fields in
               *   let fl = List.map (fun ity -> field (default_value_of_type env known ity)) itys in
               *   value ty (Vconstr (None, fl))
               * else *)
              value ty Vundefined

(* ROUTINE DEFINITIONS *)

type routine_defn =
  | Builtin of (rsymbol -> value list -> value)
  | LocalFunction of (rsymbol * cexp) list * cexp
  | Constructor of Pdecl.its_defn
  | Projection of Pdecl.its_defn

let rec find_def rs = function
  | d :: _ when rs_equal rs d.rec_sym ->
      d.rec_fun (* TODO : put rec_rsym in local env *)
  | _ :: l -> find_def rs l
  | [] -> raise Not_found

let rec find_constr_or_proj dl rs =
  match dl with
  | [] -> raise Not_found
  | d :: rem ->
      if List.mem rs d.Pdecl.itd_constructors then (
        Debug.dprintf debug_trace_exec "@[<hov 2>[interp] found constructor:@ %s@]@."
          rs.rs_name.id_string ;
        Constructor d )
      else if List.mem rs d.Pdecl.itd_fields then (
        Debug.dprintf debug_trace_exec "@[<hov 2>[interp] found projection:@ %s@]@."
          rs.rs_name.id_string ;
        Projection d )
      else
        find_constr_or_proj rem rs

let find_global_definition kn rs =
  match (Mid.find rs.rs_name kn).Pdecl.pd_node with
  | Pdecl.PDtype dl -> find_constr_or_proj dl rs
  | Pdecl.PDlet (LDvar _) -> raise Not_found
  | Pdecl.PDlet (LDsym (_, ce)) -> LocalFunction ([], ce)
  | Pdecl.PDlet (LDrec dl) ->
      let locs = List.map (fun d -> d.rec_rsym, d.rec_fun) dl in
      LocalFunction (locs, find_def rs dl)
  | Pdecl.PDexn _ -> raise Not_found
  | Pdecl.PDpure -> raise Not_found

let find_definition env (rs: rsymbol) =
  (* then try if it is a built-in symbol *)
  try Builtin (Hrs.find builtin_progs rs) with Not_found ->
  (* then try if it is a local function *)
  try LocalFunction ([], Mrs.find rs env.funenv) with Not_found ->
  (* else look for a global function *)
  find_global_definition env.mod_known rs

(** Convert a value into a term. The first component of the result are additional bindings
   from closures. *)
let rec term_of_value ?(ty_mt=Mtv.empty) env vsenv v : (vsymbol * term) list * term =
  let v_ty = ty_inst ty_mt v.v_ty in
  match v.v_desc with
  | Vundefined ->
      (* TODO Replace ls_undefined by fs_any_function when branch
       * fun-lits-noptree is merged:
       * env, fs_app fs_any_function [t_tuple []] v_ty *)
      vsenv, fs_app ls_undefined [] v_ty
  | Vnum i ->
      if ty_equal v_ty ty_int || is_range_ty v_ty then
        vsenv, t_const (Constant.int_const i) v_ty
      else
        kasprintf failwith "term_of_value: value type not int or range but %a"
          print_ty v_ty
  | Vstring s ->
      ty_equal_check v_ty ty_str;
      vsenv, t_const (Constant.ConstStr s) ty_str
  | Vbool b ->
      ty_equal_check v_ty ty_bool;
      vsenv, if b then t_bool_true else t_bool_false
  | Vvoid ->
      ty_equal_check v_ty ty_unit;
      vsenv, t_tuple []
  | Vterm t ->
      Opt.iter (ty_equal_check v_ty) t.t_ty;
      vsenv, t
  | Vreal _ | Vfloat _ | Vfloat_mode _ -> (* TODO *)
      Format.kasprintf failwith "term_of_value: %a" print_value v
  | Vproj (ls, x) ->
      (* TERM: epsilon v. rs v = x *)
      let vs = create_vsymbol (id_fresh "v") v_ty in
      let vsenv, t_x = term_of_value ~ty_mt env vsenv x in
      let ty_x = ty_inst ty_mt x.v_ty in
      let t = t_equ (fs_app ls [t_var vs] ty_x) t_x in
      vsenv, t_eps (t_close_bound vs t)
  | Vconstr (rs, fs) ->
      if rs_kind rs = RKfunc then
        let term_of_field vsenv f = term_of_value ~ty_mt env vsenv (field_get f) in
        let vsenv, fs = Lists.map_fold_left term_of_field vsenv fs in
        vsenv, fs_app (ls_of_rs rs) fs v_ty
      else (* TODO bench/ce/{record_one_field,record_inv}.mlw/CVC4/WP *)
        kasprintf failwith "Cannot construct term for constructor \
                            %a that is not a function" print_rs rs
  | Vfun (cl, arg, e) ->
      (* TERM: fun arg -> t *)
      let t = Opt.get_exn (Failure "Cannot convert function body to term")
          (term_of_expr ~prop:false e) in
      (* Rebind values from closure *)
      let bind_cl vs v (mt, mv, vsenv) =
        let vs' = create_vsymbol (id_clone vs.vs_name) v.v_ty in
        let mt = ty_match mt vs.vs_ty v.v_ty in
        let mv = Mvs.add vs (t_var vs') mv in
        let vsenv, t = term_of_value ~ty_mt env vsenv v in
        let vsenv = (vs', t) :: vsenv in
        mt, mv, vsenv in
      let mt, mv, vsenv = Mvs.fold bind_cl cl (Mtv.empty, Mvs.empty, vsenv) in
      (* Substitute argument type *)
      let ty_arg = ty_app_arg ts_func 0 v_ty in
      let vs_arg = create_vsymbol (id_clone arg.vs_name) ty_arg in
      let mv = Mvs.add arg (t_var vs_arg) mv in
      let mt = ty_match mt arg.vs_ty ty_arg in
      let t = t_ty_subst mt mv t in
      vsenv, t_lambda [vs_arg] [] t
  | Varray arr ->
      let open Pmodule in
      (* TERM: epsilon v. v.length = length arr /\ v[0] = arr.(ix) /\ ... *)
      let {mod_theory= {Theory.th_export= ns}} = read_module env.env ["array"] "Array" in
      let ts_array = Theory.ns_find_ts ns ["array"] in
      let ls_length = Theory.ns_find_ls ns ["length"] in
      let ls_get = Theory.ns_find_ls ns [op_get ""] in
      let v = create_vsymbol (id_fresh "a") v_ty in
      let t_eq_length = (* v.length = length arr *)
        t_equ (fs_app ls_length [t_var v] ty_int)
          (t_nat_const (Array.length arr)) in
      let elt_ty = ty_app_arg ts_array 0 v_ty in
      let rec loop vsenv sofar ix = (* v[ix] = arr.(ix) *)
        if ix = Array.length arr then vsenv, List.rev sofar else
          let vsenv, t_a_ix = term_of_value ~ty_mt env vsenv arr.(ix) in
          let t_eq_ix = t_equ (fs_app ls_get [t_var v; t_nat_const ix] elt_ty) t_a_ix in
          loop vsenv (t_eq_ix :: sofar) (succ ix) in
      let vsenv, t_eq_ixs = loop vsenv [] 0 in
      let t = t_and_l (t_eq_length :: t_eq_ixs) in
      vsenv, t_eps (t_close_bound v t)
  | Vpurefun (ty, m, def) ->
      (* TERM: fun x -> if x = k0 then v0 else ... else def *)
      let vs_arg = create_vsymbol (id_fresh "x") ty in
      let mk_case key value (vsenv, t) =
        let vsenv, key = term_of_value ~ty_mt env vsenv key in      (* k_i *)
        let vsenv, value = term_of_value ~ty_mt env vsenv value in  (* v_i *)
        let t = t_if (t_equ (t_var vs_arg) key) value t in (* if arg = k_i then v_i else ... *)
        vsenv, t in
      let vsenv, t = Mv.fold mk_case m (term_of_value ~ty_mt env vsenv def) in
      vsenv, t_lambda [vs_arg] [] t

(* and try_fix_projection env vsenv v v_ty =
 *   let its, _, _ = ity_components (ity_of_ty v_ty) in
 *   let itd = Pdecl.find_its_defn env.mod_known its in
 *   let rs, rs_field = match itd.Pdecl.itd_constructors, itd.Pdecl.itd_fields with
 *     | [rs], [rs_field] -> rs, rs_field
 *     | _ -> failwith "term_of_value: complex vnum" in
 *   let v' = {v with v_ty= ty_of_ity rs_field.rs_cty.cty_result} in
 *   let vsenv, t_field = term_of_value env vsenv v' in
 *   vsenv, fs_app (ls_of_rs rs) [t_field] v.v_ty *)

(* CONTRADICTION CONTEXT *)

type cntr_ctx = {
  c_desc: string;
  c_trigger_loc: Loc.position option;
  c_env: env;
}

exception Contr of cntr_ctx * term

let cntr_desc_str str1 str2 = str1 ^ " of " ^ str2

let cntr_desc str id =
  asprintf "%s of %a" str print_decoded id.id_string

let report_cntr_title fmt (ctx, msg) =
  fprintf fmt "%s %s" ctx.c_desc msg

let report_cntr_head fmt (ctx, msg, term) =
  fprintf fmt "@[<v>%a%t@]" report_cntr_title (ctx, msg)
    (fun fmt ->
       match ctx.c_trigger_loc, term.t_loc with
       | Some t1, Some t2 ->
           fprintf fmt " at %a@,- Defined at %a" print_loc' t1 print_loc' t2
       | Some t, None | None, Some t ->
           fprintf fmt " at %a" print_loc' t
       | None, None -> () )

let env_sep = Pp.comma

let pp_env pp_key pp_value fmt =
  let delims = Pp.nothing, Pp.nothing in
  fprintf fmt "%a" (pp_bindings ~delims ~sep:env_sep pp_key pp_value)

let report_cntr_body fmt (ctx, term) =
  let cmp_vs (vs1, _) (vs2, _) =
    String.compare vs1.vs_name.id_string vs2.vs_name.id_string in
  let mvs = t_freevars Mvs.empty term in
  fprintf fmt "@[<hv2>- Term: %a@]@," print_term term ;
  fprintf fmt "@[<hv2>- Variables: %a@]" (pp_env print_vs print_value)
    (List.sort cmp_vs
       (Mvs.bindings
          (Mvs.filter (fun vs _ -> Mvs.contains mvs vs) ctx.c_env.vsenv)))

let report_cntr fmt (ctx, msg, term) =
  fprintf fmt "@[<v>%a@,%a@]"
    report_cntr_head (ctx, msg, term)
    report_cntr_body (ctx, term)

let cntr_ctx desc ?trigger_loc env =
  { c_desc= desc;
    c_trigger_loc= trigger_loc;
    c_env= snapshot_env env}

(* TERM EVALUATION *)

(* Add declarations for additional term bindings in [vsenv] *)
let bind_term (vs, t) (task, ls_mt, ls_mv) =
  let ty = Opt.get t.t_ty in
  let ls = create_fsymbol (id_clone vs.vs_name) [] ty in
  let ls_mt = ty_match ls_mt vs.vs_ty ty in
  let ls_mv = Mvs.add vs (fs_app ls [] ty) ls_mv in
  let t = t_ty_subst ls_mt ls_mv t in
  let defn = Decl.make_ls_defn ls [] t in
  let task = Task.add_logic_decl task [defn] in
  task, ls_mt, ls_mv

(* Add declarations for value bindings in [env.vsenv] *)
let bind_value env vs v (task, ls_mt, ls_mv) =
  let ty, ty_mt, ls_mt =
    (* [ty_mt] is a type substitution for [v],
       [ls_mt] is a type substitution for the remaining task *)
    if ty_closed v.v_ty then
      v.v_ty, Mtv.empty, ty_match ls_mt vs.vs_ty v.v_ty
    else
      vs.vs_ty, ty_match Mtv.empty v.v_ty vs.vs_ty, ls_mt in
  let ls = create_fsymbol (id_clone vs.vs_name) [] ty in
  let ls_mv = Mvs.add vs (fs_app ls [] ty) ls_mv in
  let vsenv, t = term_of_value ~ty_mt env [] v in
  let task, ls_mt, ls_mv = List.fold_right bind_term vsenv (task, ls_mt, ls_mv) in
  let t = t_ty_subst ls_mt ls_mv t in
  let defn = Decl.make_ls_defn ls [] t in
  let task = Task.add_logic_decl task [defn] in
  task, ls_mt, ls_mv

(* Create and open a formula `p t` where `p` refers to a predicate without definition, to
   use the reduction engine to evaluate `t` *)
let undef_pred_decl, undef_pred_app, undef_pred_app_arg =
  let ls = let tv = create_tvsymbol (id_fresh "a") in
    create_psymbol (id_fresh "p") [ty_var tv] in
  let decl = Decl.create_param_decl ls in
  let app t = t_app ls [t] None in
  let app_arg t = match t with
    | {t_node= Tapp (ls, [t])} when ls_equal ls ls -> t
    | _ -> failwith "open_app" in
  decl, app, app_arg

(* Add declarations from local functions in [env.funenv] *)
let bind_fun rs cexp (task, ls_mv) =
  try
    let t = match cexp.c_node with
      | Cfun e -> Opt.get_exn Exit (term_of_expr ~prop:false e)
      | _ -> raise Exit in
    let ty_args = List.map (fun pv -> ty_of_ity pv.pv_ity) rs.rs_cty.cty_args in
    let ty_res = ty_of_ity rs.rs_cty.cty_result in
    let ls, ls_mv = match rs.rs_logic with
      | RLlemma | RLnone -> raise Exit
      | RLls ls -> ls, ls_mv
      | RLpv {pv_vs= vs} ->
          let ls = create_fsymbol (id_clone rs.rs_name) ty_args ty_res in
          let vss = List.map (fun pv -> pv.pv_vs) rs.rs_cty.cty_args in
          let ts = List.map t_var vss in
          let t0 = fs_app ls ts ty_res in
          let t = t_lambda vss [] t0 in
          let ls_mv = Mvs.add vs t ls_mv in
          ls, ls_mv in
    let vs_args = List.map (fun pv -> pv.pv_vs) rs.rs_cty.cty_args in
    let decl = Decl.make_ls_defn ls vs_args t in
    let task = Task.add_logic_decl task [decl] in
    task, ls_mv
  with Exit -> task, ls_mv

let task_of_term ?(vsenv=[]) env t =
  let open Task in let open Decl in
  let task, ls_mt, ls_mv = None, Mtv.empty, Mvs.empty in
  let task = List.fold_left use_export task Theory.[builtin_theory; bool_theory; highord_theory] in
  let task = add_param_decl task ls_undefined in
  let lsenv =
    let aux1 rs v mls =
      match rs.rs_logic with
      | RLls ls -> Mls.add ls v mls
      | _ -> mls in
    Mrs.fold aux1 env.rsenv Mls.empty in
  (* Add known declarations *)
  let add_known _ decl task =
    match decl.d_node with
    | Dprop (Pgoal, _, _) -> task
    | Dprop (Plemma, prs, t) ->
        add_decl task (create_prop_decl Paxiom prs t)
    | Dparam ls when Mls.contains lsenv ls ->
        (* Take value from lsenv (i.e. env.rsenv) for declaration *)
        let vsenv, t = term_of_value env [] (Mls.find ls lsenv) in
        let task, ls_mt, ls_mv = List.fold_right bind_term vsenv (task, ls_mt, ls_mv) in
        let t = t_ty_subst ls_mt ls_mv t in
        let decl = Decl.make_ls_defn ls [] t in
        add_decl task (create_logic_decl [decl])
    | _ -> add_decl task decl in
  let task = Mid.fold add_known env.th_known task in
  let task, ls_mv = Mrs.fold bind_fun env.funenv (task, ls_mv) in
  let task, ls_mt, ls_mv = List.fold_right bind_term vsenv (task, ls_mt, ls_mv) in
  let task, ls_mt, ls_mv = Mvs.fold (bind_value env) env.vsenv (task, ls_mt, ls_mv) in
  let t = t_ty_subst ls_mt ls_mv t in
  let task =
    if t.t_ty = None then (* Add a formula as goal directly ... *)
      let prs = create_prsymbol (id_fresh "goal") in
      add_prop_decl task Pgoal prs t
    else (* ... and wrap a non-formula in a call to a predicate with no definition *)
      let task = add_decl task undef_pred_decl in
      let prs = create_prsymbol (id_fresh "goal") in
      add_prop_decl task Pgoal prs (undef_pred_app t) in
  task, ls_mv

(* Parameters for binding universally quantified variables to a value
   obtained with rac_config.get_value or the default value *)
let bind_univ_quant_vars = false
let bind_univ_quant_vars_default = false

let string_or_model_trace id =
  Ident.get_model_trace_string ~name:id.id_string ~attrs:id.id_attrs

(* Get the value of a vsymbol with env.rac.get_value or a default value *)
let get_value_for_quant_var env vs =
  match vs.vs_name.id_loc with
  | None -> None
  | Some loc ->
      let value =
        if bind_univ_quant_vars then
          let name = string_or_model_trace vs.vs_name in
          let v = env.rac.get_value ~name ~loc (ity_of_ty vs.vs_ty) in
          (Opt.iter (fun v ->
               Debug.dprintf debug_rac_values
                 "Bind all-quantified variable %a to %a@."
                 print_vs vs print_value v) v; v)
        else None in
      let value =
        if value <> None then value else
          if bind_univ_quant_vars_default then (
            let v = default_value_of_type env.env env.mod_known (ity_of_ty vs.vs_ty) in
            Debug.dprintf debug_rac_values
              "Use default value for all-quantified variable %a: %a@."
              print_vs vs print_value v;
            Some v
          ) else None in
      Opt.iter (fun v ->
          register_used_value env (Some loc) vs.vs_name v) value;
      value

(** When the task goal is [forall vs* . t], add declarations to the
   task that bind the variables [vs*] to concrete values (with
   env.rac.get_value or default values), and make [t] the new goal. *)
let bind_univ_quant_vars env task =
  try match (Task.task_goal_fmla task).t_node with
    | Tquant (Tforall, tq) ->
        let vs, _, t = t_open_quant tq in
        let values = List.map (fun vs -> Opt.get_exn Exit (get_value_for_quant_var env vs)) vs in
        let _, task = Task.task_separate_goal task in
        let task, ls_mt, ls_mv = List.fold_right2 (bind_value env) vs values (task, Mtv.empty, Mvs.empty) in
        let prs = Decl.create_prsymbol (id_fresh "goal") in
        let t = t_ty_subst ls_mt ls_mv t in
        Task.add_prop_decl task Decl.Pgoal prs t
    | _ -> raise Exit
  with Exit -> task

let task_hd_equal t1 t2 = let open Task in let open Theory in let open Decl in
  (* Task.task_hd_equal is too strict: it requires physical equality between
     {t1,t2}.task_prev *)
  match t1.task_decl.td_node, t2.task_decl.td_node with
  | Decl {d_node = Dprop (Pgoal,p1,g1)}, Decl {d_node = Dprop (Pgoal,p2,g2)} ->
      pr_equal p1 p2 && t_equal_strict g1 g2
  | _ -> t1 == t2

(** Apply the (reduction) transformation and fill universally quantified variables
    in the head of the task by values obtained with env.rac.get_value, recursively. *)
let rec trans_and_bind_quants env trans task =
  let task = bind_univ_quant_vars env task in
  let tasks = Trans.apply trans task in
  let task_unchanged = match tasks with
    | [task'] -> Opt.equal task_hd_equal task' task
    | _ -> false in
  if task_unchanged then
    tasks
  else
    List.flatten (List.map (trans_and_bind_quants env trans) tasks)

(** Compute the value of a term by using the (reduction) transformation *)
let compute_term env t =
  match env.rac.rac_reduce.rac_trans with
  | None -> t
  | Some trans ->
      let task, ls_mv = task_of_term env t in
      if t.t_ty = None then (* [t] is a formula *)
        match List.map Task.task_goal_fmla (trans_and_bind_quants env trans task) with
        | [] -> t_true
        | t :: ts -> List.fold_left t_and t ts
      else (* [t] is not a formula *)
        let t = match Trans.apply trans task with
          | [task] -> undef_pred_app_arg (Task.task_goal_fmla task)
          | _ -> failwith "compute_term" in
        (* Free vsymbols in the original [t] have been substituted in by fresh lsymbols
           (actually: ls @ []) to bind them to declarations in the task. Now we have to
           reverse these substitution to ensures that the reduced term is valid in the
           original environment of [t]. *)
        let reverse vs t' t = t_replace t' (t_var vs) t in
        Mvs.fold reverse ls_mv t

(** Check the validiy of a term that has been encoded in a task by the (reduction) transformation *)
let check_term_compute env trans task =
  let is_false = function
    | Some {Task.task_decl= Theory.{
        td_node= Decl Decl.{
            d_node= Dprop (Pgoal, _, {t_node= Tfalse})}}} ->
        true
    | _ -> false in
  match trans_and_bind_quants env trans task with
  | [] -> Some true
  | tasks ->
      Debug.dprintf debug_rac_check_sat "Transformation produced %d tasks@." (List.length tasks);
      if List.exists is_false tasks then
        Some false
      else (
        List.iter (Debug.dprintf debug_rac_check_sat "- %a@." print_tdecl)
          (Lists.map_filter (Opt.map (fun t -> t.Task.task_decl)) tasks);
        None )

(** Check the validiy of a term that has been encoded in a task by dispatching it to a prover *)
let check_term_dispatch (Rac_prover {command; driver; limit}) task =
  let open Call_provers in
  let call = Driver.prove_task ~command ~limit driver task in
  let res = wait_on_call call in
  Debug.dprintf debug_rac_check_sat "Check term dispatch answer: %a@."
    print_prover_answer res.pr_answer;
  match res.pr_answer with
  | Valid -> Some true
  | Invalid -> Some false
  | _ -> None

let check_term ?vsenv ctx t =
  Debug.dprintf debug_rac_check_sat "@[<hv2>Check term: %a@]@." print_term t;
  let task, _ = task_of_term ?vsenv ctx.c_env t in
  let res = (* Try checking the term using computation first ... *)
    Opt.map (fun b -> Debug.dprintf debug_rac_check_sat "Computed %b.@." b; b)
      (Opt.bind ctx.c_env.rac.rac_reduce.rac_trans
         (fun trans -> check_term_compute ctx.c_env trans task)) in
  let res =
    if res = None then (* ... then try solving using a prover *)
      Opt.map (fun b -> Debug.dprintf debug_rac_check_sat "Dispatched: %b.@." b; b)
        (Opt.bind ctx.c_env.rac.rac_reduce.rac_prover
           (fun rp -> check_term_dispatch rp task))
    else res in
  match res with
  | Some true ->
      Debug.dprintf debug_rac_check_term_result "%a@." report_cntr_head (ctx, "is ok", t)
  | Some false ->
      Debug.dprintf debug_rac_check_term_result "%a@." report_cntr_head (ctx, "has failed", t);
      raise (Contr (ctx, t))
  | None ->
      let msg = "cannot be evaluated" in
      Debug.dprintf debug_rac_check_term_result "%a: %a@." report_cntr_title (ctx, msg) print_term t;
      if not ctx.c_env.rac.skip_cannot_compute then
        cannot_compute "%a" report_cntr_title (ctx, msg)

let check_terms ctx = List.iter (check_term ctx)

(* Check a post-condition [t] by binding the result variable to
   the term [vt] representing the result value. *)
let check_post ctx v post =
  let vs, t = open_post post in
  let vsenv = Mvs.add vs v ctx.c_env.vsenv in
  let ctx = {ctx with c_env= {ctx.c_env with vsenv}} in
  check_term ctx t

let check_posts desc loc env v posts =
  let ctx = cntr_ctx desc ?trigger_loc:loc env in
  List.iter (check_post ctx v) posts

exception RACStuck of env * Loc.position option
(* The execution goes into RACStuck when a property that should be
   assumed is not satisfied. E.g. when executing a function, if the
   environment does not satisfy the precondition, the execution ends
   with RACStuck. *)

let value_of_free_vars env t =
  let get_value get_value get_ty env x =
    let def = {v_desc= Vundefined; v_ty= get_ty x} in
    snapshot (Opt.get_def def (get_value x env))  in
  let mid = t_v_fold (fun mvs vs ->
    let get_ty vs = vs.vs_ty in
    let value = get_value Mvs.find_opt get_ty env.vsenv vs in
    Mid.add vs.vs_name value mvs) Mid.empty t in
  t_app_fold (fun mrs ls tyl ty ->
      let get_ty rs = ty_of_ity rs.rs_cty.cty_result in
      if tyl = [] && ty <> None then
        try let rs = restore_rs ls in
            let value = get_value Mrs.find_opt get_ty env.rsenv rs in
            Mid.add rs.rs_name value mrs
        with Not_found -> mrs
      else mrs
    ) mid t

let check_assume_term ctx t =
  try check_term ctx t with Contr (ctx,t) ->
    let mid = value_of_free_vars ctx.c_env t in
    register_stucked ctx.c_env t.t_loc ctx.c_desc mid;
    raise (RACStuck (ctx.c_env, t.t_loc))

let check_assume_terms ctx tl =
  try check_terms ctx tl with Contr (ctx,t) ->
    let mid = value_of_free_vars ctx.c_env t in
    register_stucked ctx.c_env t.t_loc ctx.c_desc mid;
    raise (RACStuck (ctx.c_env, t.t_loc))

let check_assume_posts ctx v posts =
  try check_posts ctx.c_desc ctx.c_trigger_loc ctx.c_env v posts with Contr (ctx,t) ->
    let mid = value_of_free_vars ctx.c_env t in
    register_stucked ctx.c_env t.t_loc ctx.c_desc mid;
    raise (RACStuck (ctx.c_env,t.t_loc))

let check_term ?vsenv ctx t =
  try check_term ?vsenv ctx t with (Contr (ctx,t)) as e ->
    let mid = value_of_free_vars ctx.c_env t in
    register_failure ctx.c_env t.t_loc ctx.c_desc mid;
    raise e

let check_terms ctx tl =
  try check_terms ctx tl with (Contr (ctx,t)) as e ->
    let mid = value_of_free_vars ctx.c_env t in
    register_failure ctx.c_env t.t_loc ctx.c_desc mid;
    raise e

let check_posts desc loc env v posts =
  try check_posts desc loc env v posts with (Contr (ctx,t)) as e ->
    let mid = value_of_free_vars ctx.c_env t in
    register_failure ctx.c_env t.t_loc ctx.c_desc mid;
    raise e

(* EXPRESSION EVALUATION *)

(* Assuming the real is given in pow2 and pow5 *)
let compute_fraction {Number.rv_sig= i; Number.rv_pow2= p2; Number.rv_pow5= p5}
  =
  let p2_val = BigInt.pow_int_pos_bigint 2 (BigInt.abs p2) in
  let p5_val = BigInt.pow_int_pos_bigint 5 (BigInt.abs p5) in
  let num = ref BigInt.one in
  let den = ref BigInt.one in
  num := BigInt.mul i !num ;
  if BigInt.ge p2 BigInt.zero then
    num := BigInt.mul p2_val !num
  else
    den := BigInt.mul p2_val !den ;
  if BigInt.ge p5 BigInt.zero then
    num := BigInt.mul p5_val !num
  else
    den := BigInt.mul p5_val !den ;
  !num, !den

let rec matching env (v : value) p =
  match p.pat_node with
  | Pwild -> env
  | Pvar vs -> bind_vs vs v env
  | Por (p1, p2) -> (
      try matching env v p1 with NoMatch -> matching env v p2 )
  | Pas (p, vs) -> matching (bind_vs vs v env) v p
  | Papp (ls, pl) -> (
      match v.v_desc with
      | Vconstr ({rs_logic= RLls ls2}, tl) ->
          if ls_equal ls ls2 then
            List.fold_left2 matching env (List.map field_get tl) pl
          else if ls2.ls_constr > 0 then
            raise NoMatch
          else
            raise Undetermined
      | Vbool b ->
          let ls2 = if b then fs_bool_true else fs_bool_false in
          if ls_equal ls ls2 then env else raise NoMatch
      | _ -> raise Undetermined )

let is_true v = match v.v_desc with
  | Vbool true | Vterm {t_node= Ttrue} -> true
  | Vterm t when t_equal t t_bool_true -> true
  | _ -> false

let is_false v = match v.v_desc with
  | Vbool false | Vterm {t_node= Tfalse} -> true
  | Vterm t when t_equal t t_bool_false -> true
  | _ -> false

let fix_boolean_term t =
  if t_equal t t_true then t_bool_true else
  if t_equal t t_false then t_bool_false else t

let exec_pure ~loc env ls pvs =
  register_pure_call env loc ls Log.ExecConcrete;
  if ls_equal ls ps_equ then
    (* TODO (?) Add more builtin logical symbols *)
    let pv1, pv2 = match pvs with [pv1; pv2] -> pv1, pv2 | _ -> assert false in
    let v1 = Mvs.find pv1.pv_vs env.vsenv and v2 = Mvs.find pv2.pv_vs env.vsenv in
    Normal (value ty_bool (Vbool (compare_values v1 v2 = 0)))
  else if ls_equal ls fs_func_app then
    failwith "Pure function application not yet implemented"
  else
    match Decl.find_logic_definition env.th_known ls with
    | Some defn ->
        let vs, t = Decl.open_ls_defn defn in
        let args = List.map (get_pvs env) pvs in
        let vsenv = List.fold_right2 Mvs.add vs args env.vsenv in
        let t = compute_term {env with vsenv} t in
        (* TODO A variable x binding the result of exec pure are used as (x = True) in
           subsequent terms, so we map true/false to True/False here. Is this reasonable? *)
        let t = fix_boolean_term t in
        Normal (value (Opt.get_def ty_bool t.t_ty) (Vterm t))
    | None ->
        kasprintf failwith "No logic definition for %a" print_ls ls

let pp_limited ?(n=100) pp fmt x =
  let s = asprintf "%a" pp x in
  let s = String.map (function '\n' -> ' ' | c -> c) s in
  let s = String.(if length s > n then sub s 0 (Pervasives.min n (length s)) ^ "..." else s) in
  pp_print_string fmt s

let print_result fmt = function
  | Normal v -> print_value fmt v
  | Excep (xs, v) -> fprintf fmt "EXC %a: %a" print_xs xs print_value v
  | Irred e -> fprintf fmt "IRRED: %a" (pp_limited print_expr) e

let get_and_register_value env ?def ?ity vs loc =
  let ity = match ity with None -> ity_of_ty vs.vs_ty | Some ity -> ity in
  let name = string_or_model_trace vs.vs_name in
  let value = match env.rac.get_value ~name ~loc ity with
    | Some v ->
       Debug.dprintf debug_rac_values
         "@[<h>Value imported for %a at %a: %a@]@."
         print_decoded name
         print_loc' loc
         print_value v; v
    | None ->
       let v = match def with
         | None -> default_value_of_type env.env env.mod_known ity
         | Some v -> v in
       Debug.dprintf debug_rac_values
         "@[<h>No value for %s at %a, taking default%t.@]@." name print_loc' loc
         (fun fmt -> if def <> None then fprintf fmt " %a" print_value v);
       v in
  register_used_value env (Some loc) vs.vs_name value;
  value

let rec set_fields fs1 fs2 =
  let set_field f1 f2 =
    match (field_get f1).v_desc, (field_get f2).v_desc with
    | Vconstr (rs1, fs1), Vconstr (rs2, fs2) ->
        assert (rs_equal rs1 rs2);
        set_fields fs1 fs2
    | _ -> field_set f1 (field_get f2) in
  List.iter2 set_field fs1 fs2

let set_constr v1 v2 =
  (match v1.v_desc, v2.v_desc with
   | Vconstr (rs1, fs1), Vconstr (rs2, fs2) ->
       assert (rs_equal rs1 rs2);
       set_fields fs1 fs2;
   | _ -> failwith "set_constr")

let assign_written_vars ?(vars_map=Mpv.empty) wrt loc env vs =
  let pv = restore_pv vs in
  if pv_affected wrt pv then (
    Debug.dprintf debug_trace_exec "@[<h>%tVAR %a is written in loop %a@]@."
      pp_indent print_pv pv
      (Pp.print_option print_loc') pv.pv_vs.vs_name.id_loc;
    let pv = Mpv.find_def pv pv vars_map in
    let value = get_and_register_value ~ity:pv.pv_ity env pv.pv_vs loc in
    set_constr (get_vs env vs) value )

let rec eval_expr env e =
  Debug.dprintf debug_trace_exec "@[<h>%t%sEVAL EXPR: %a@]@." pp_indent
    (if env.rac.rac_abstract then "Abs. " else "")
    (pp_limited print_expr) e;
  let res = eval_expr' env e in
  Debug.dprintf debug_trace_exec "@[<h>%t -> %a@]@." pp_indent (print_result) res;
  res

(* abs = abstractly - do not execute loops and function calls - use
   instead invariants and function contracts to guide execution. *)
and eval_expr' env e =
  let loc_or_dummy = Opt.get_def Loc.dummy_position e.e_loc in
  match e.e_node with
  | Evar pvs ->
      let v = get_pvs env pvs in
      Debug.dprintf debug_trace_exec "[interp] reading var %s from env -> %a@\n"
        pvs.pv_vs.vs_name.id_string print_value v ;
      Normal v
  | Econst (Constant.ConstInt c) ->
      Normal (value (ty_of_ity e.e_ity) (Vnum (big_int_of_const c)))
  | Econst (Constant.ConstReal r) ->
      (* ConstReal can be float or real *)
      if ity_equal e.e_ity ity_real then
        let p, q = compute_fraction r.Number.rl_real in
        let sp, sq = BigInt.to_string p, BigInt.to_string q in
        try Normal (value ty_real (Vreal (Big_real.real_from_fraction sp sq)))
        with Mlmpfr_wrapper.Not_Implemented ->
          cannot_compute "mlmpfr wrapper is not implemented"
      else
        let c = Constant.ConstReal r in
        let s = Format.asprintf "%a" Constant.print_def c in
        Normal (value ty_real (Vfloat (Mlmpfr_wrapper.make_from_str s)))
  | Econst (Constant.ConstStr s) -> Normal (value ty_str (Vstring s))
  | Eexec (ce, cty) -> begin
      (* TODO (When) do we have to check the contracts in cty? When ce <> Capp? *)
      (* check_terms (cntr_ctx "Exec precondition" env) cty.cty_pre; *)
      match ce.c_node with
      | Cpur (ls, pvs) ->
          Debug.dprintf debug_trace_exec "@[<h>%tEVAL EXPR: EXEC PURE %a %a@]@." pp_indent print_ls ls
            (Pp.print_list Pp.comma print_value) (List.map (get_pvs env) pvs);
          exec_pure ~loc:e.e_loc env ls pvs
      | Cfun e' ->
        Debug.dprintf debug_trace_exec "@[<h>%tEVAL EXPR EXEC FUN: %a@]@." pp_indent print_expr e';
        let add_free pv = Mvs.add pv.pv_vs (Mvs.find pv.pv_vs env.vsenv) in
        let cl = Spv.fold add_free ce.c_cty.cty_effect.eff_reads Mvs.empty in
        let mvs = Mvs.map snapshot cl in
        ( match ce.c_cty.cty_args with
          | [] ->
             if env.rac.rac_abstract then begin
                 register_call env e.e_loc None mvs Log.ExecAbstract;
                 exec_call_abstract ?loc:e.e_loc env ce.c_cty [] e.e_ity
               end
             else begin
                 register_call env e.e_loc None mvs Log.ExecConcrete;
                 eval_expr env e'
               end
          | [arg] ->
              let match_free pv mt =
                let v = Mvs.find pv.pv_vs env.vsenv in
                ty_match mt pv.pv_vs.vs_ty v.v_ty in
              let mt = Spv.fold match_free cty.cty_effect.eff_reads Mtv.empty in
              let ty = ty_inst mt (ty_of_ity e.e_ity) in
              Normal (value ty (Vfun (cl, arg.pv_vs, e')))
          | _ -> failwith "many args for exec fun" (* TODO *) )
      | Cany ->
         register_any_call env e.e_loc None Mvs.empty;
         exec_call_abstract ?loc:e.e_loc env cty [] e.e_ity
      | Capp (rs, pvsl) when Opt.map is_prog_constant (Mid.find_opt rs.rs_name env.mod_known) = Some true ->
          assert (cty.cty_args = [] && pvsl = []);
          let v = Mrs.find rs env.rsenv in
          (* check_posts "Exec postcondition" e.e_loc env v cty.cty_post; *)
          Normal v
      | Capp (rs, pvsl) ->
          if cty.cty_args <> [] then cannot_compute "function cannot be applied partially";
          exec_call ?loc:e.e_loc env rs pvsl e.e_ity
    end
  | Eassign l ->
      List.iter
        (fun (pvs, rs, value) ->
          let cstr, args =
            match (get_pvs env pvs).v_desc with
            | Vconstr (cstr, args) -> cstr, args
            | _ -> assert false in
          let rec search_and_assign constr_args args =
            match constr_args, args with
            | pv :: pvl, Field r :: vl ->
                if pv_equal pv (fd_of_rs rs) then
                  r := get_pvs env value
                else
                  search_and_assign pvl vl
            | _ -> assert false in
          search_and_assign cstr.rs_cty.cty_args args)
        l ;
      Normal (value ty_unit Vvoid)
  | Elet (ld, e2) -> (
    match ld with
    | LDvar (pvs, e1) -> (
      match eval_expr env e1 with
      | Normal v ->
        let env = bind_pvs pvs v env in
        eval_expr env e2
      | r -> r )
    | LDsym (rs, ce) ->
        let env = {env with funenv= Mrs.add rs ce env.funenv} in
        eval_expr env e2
    | LDrec l ->
        let env' =
          { env with
            funenv=
              List.fold_left
                (fun acc d ->
                  Mrs.add d.rec_sym d.rec_fun (Mrs.add d.rec_rsym d.rec_fun acc))
                env.funenv l } in
        eval_expr env' e2 )
  | Eif (e1, e2, e3) -> (
    match eval_expr env e1 with
    | Normal v ->
      if is_true v then
        eval_expr env e2
      else if is_false v then
        eval_expr env e3
      else (
        Warning.emit "@[[Exec] Cannot decide condition of if: @[%a@]@]@." print_value v ;
        Irred e )
    | r -> r )
  | Ewhile (cond, inv, _var, e1) when env.rac.rac_abstract -> begin
      (* arbitrary execution of an iteartion taken from the counterexample

        while e1 do invariant {I} e2 done
        ~>
        assert1 {I};
        assign_written_vars_with_ce;
        assert2* {I};
        if e1 then (e2;assert3 {I}; abort* ) else ()

        1 - if assert1 fails, then we have a real couterexample
            (invariant init doesn't hold)
        2 - if assert2 fails, then we have a false counterexample
            (invariant does not hold at beginning of execution)
        3 - if assert3 fails, then we have a real counterexample
            (invariant does not hold after iteration)
        * stop the interpretation here - raise RACStuck *)
      (* assert1 *)
      register_loop env e.e_loc Log.ExecAbstract;
      if env.rac.do_rac then
        check_terms (cntr_ctx "Loop invariant initialization" env) inv;
      List.iter (assign_written_vars e.e_effect.eff_writes loc_or_dummy env)
        (Mvs.keys env.vsenv);
      (* assert2 *)
      check_assume_terms (cntr_ctx "Assume loop invariant" env) inv;
      match eval_expr env cond with
      | Normal v ->
         if is_true v then begin
             match eval_expr env e1 with
             | Normal _ ->
                if env.rac.do_rac then
                  check_terms (cntr_ctx "Loop invariant preservation" env) inv;
                (* the execution cannot continue from here *)
                register_stucked env e.e_loc "Cannot continue after arbitrary iteration" Mid.empty;
                raise (RACStuck (env,e.e_loc))
             | r -> r
           end
         else if is_false v then
           Normal (value ty_unit Vvoid)
         else (
           Warning.emit "@[[Exec] Cannot decide condition of while: @[%a@]@]@."
             print_value v ;
           Irred e )
      | r -> r
    end
  | Ewhile (cond, inv, _var, e1) -> begin
      register_loop env e.e_loc Log.ExecConcrete;
      (* TODO variants *)
      if env.rac.do_rac then
        check_terms (cntr_ctx "Loop invariant initialization" env) inv ;
      match eval_expr env cond with
      | Normal v ->
          if is_true v then (
            match eval_expr env e1 with
            | Normal _ ->
                if env.rac.do_rac then
                  check_terms (cntr_ctx "Loop invariant preservation" env) inv ;
                eval_expr env e
            | r -> r )
          else if is_false v then
            Normal (value ty_unit Vvoid)
          else (
            Warning.emit "@[[Exec] Cannot decide condition of while: @[%a@]@]@."
              print_value v ;
            Irred e )
      | r -> r end
  | Efor (i, (pvs1, dir, pvs2), _ii, inv, e1) when env.rac.rac_abstract -> begin
      (* TODO what to do with _ii? *)
      (* arbitrary execution of an iteartion taken from the counterexample
        for i = e1 to e2 do invariant {I} e done
        ~>
        let a = eval_expr e1 in
        let b = eval_expr e2 in
        if a <= b + 1 then begin
          (let i = a in assert1 {I});
          assign_written_vars_with_ce;
          let i = get_and_register_value ~def:(b+1) i in
          if not (a <= i <= b + 1) then abort1;
          if a <= i <= b then begin
            assert2* { I };
            eval_expr e;
            let i = i + 1 in
            assert3 {I};
            abort2
          end else begin
            assert4* {I} (* i is already equal to 'b + 1' *)
          end
        end else ()

        1 - if assert1 fails, then we have a real counterexample
            (invariant init doesn't hold)
        2 - if assert2 fails, then we have a false counterexample
            (invariant does not hold at beginning of execution)
        3 - if assert3 fails, then we have a real counterexample
            (invariant does not hold after iteration)
        4 - if assert4 fails, then we have a false counterexample
            (invariant does not hold for the execution to continue)
        5 - abort1: we have a false counterexample
            (value assigned to i is not compatible with loop range)
        6 - abort2: we have a false counterexample
            (the abstract rac cannot continue from this state) *)
      register_loop env e.e_loc Log.ExecAbstract;
      try
  let a = big_int_of_value (get_pvs env pvs1) in
  let b = big_int_of_value (get_pvs env pvs2) in
  let le, suc = match dir with
    | To -> BigInt.le, BigInt.succ
    | DownTo -> BigInt.ge, BigInt.pred in
  (* assert1 *)
  if le a (suc b) then begin
    if env.rac.do_rac then begin
      let env = bind_vs i.pv_vs (value ty_int (Vnum a)) env in
      check_terms (cntr_ctx "Loop invariant initialization" env) inv end;
    List.iter (assign_written_vars e.e_effect.eff_writes loc_or_dummy env)
      (Mvs.keys env.vsenv);
    let def = value ty_int (Vnum (suc b)) in
    let i_val = get_and_register_value ~def ~ity:i.pv_ity env i.pv_vs
                  (Opt.get i.pv_vs.vs_name.id_loc) in
    let env = bind_vs i.pv_vs i_val env in
    let i_bi = big_int_of_value i_val in
    if not (le a i_bi && le i_bi (suc b)) then begin
        let msg = asprintf "Iterating variable not in bounds" in
        let mid = Mid.singleton i.pv_vs.vs_name i_val in
        register_stucked env e.e_loc msg mid;
        raise (RACStuck (env,e.e_loc)) end;
    if le a i_bi && le i_bi b then begin
      (* assert2 *)
      let ctx = cntr_ctx "Assume loop invariant" env in
      check_assume_terms ctx inv;
      match eval_expr env e1 with
      | Normal _ ->
         let env = bind_vs i.pv_vs (value ty_int (Vnum (suc i_bi))) env in
         (* assert3 *)
         if env.rac.do_rac then
           check_terms (cntr_ctx "Loop invariant preservation" env) inv;
         register_stucked env e.e_loc
           "Cannot continue after arbitrary iteration" Mid.empty;
         raise (RACStuck (env,e.e_loc))
      | r -> r
      end
    else begin
      (* assert4 *)
      (* i is already equal to b + 1 *)
      let ctx = cntr_ctx "Invariant after last iteration" env in
      check_assume_terms ctx inv;
      Normal (value ty_unit Vvoid)
      end
    end
  else Normal (value ty_unit Vvoid)
      with NotNum -> Irred e
    end
  | Efor (pvs, (pvs1, dir, pvs2), _i, inv, e1) -> (
    register_loop env e.e_loc Log.ExecConcrete;
    try
      let a = big_int_of_value (get_pvs env pvs1) in
      let b = big_int_of_value (get_pvs env pvs2) in
      let le, suc =
        match dir with
        | To -> BigInt.le, BigInt.succ
        | DownTo -> BigInt.ge, BigInt.pred in
      let rec iter i =
        Debug.dprintf debug_trace_exec "[interp] for loop with index = %s@."
          (BigInt.to_string i) ;
        if le i b then
          let env' = bind_vs pvs.pv_vs (value ty_int (Vnum i)) env in
          match eval_expr env' e1 with
          | Normal _ ->
              if env.rac.do_rac then
                check_terms (cntr_ctx "Loop invariant preservation" env') inv ;
              iter (suc i)
          | r -> r
        else
          Normal (value ty_unit Vvoid) in
      ( if env.rac.do_rac then
          let env' = bind_vs pvs.pv_vs (value ty_int (Vnum a)) env in
          check_terms (cntr_ctx "Loop invariant initialization" env') inv ) ;
      iter a
    with NotNum -> Irred e )
  | Ematch (e0, ebl, el) -> (
      let r = eval_expr env e0 in
      match r with
      | Normal t -> (
          if ebl = [] then
            r
          else
            try exec_match env t ebl with Undetermined -> Irred e )
      | Excep (ex, t) -> (
        match Mxs.find ex el with
        | [], e2 ->
            (* assert (t = Vvoid); *)
            eval_expr env e2
        | [v], e2 ->
            let env' = bind_vs v.pv_vs t env in
            eval_expr env' e2
        | _ -> assert false (* TODO ? *)
        | exception Not_found -> r )
      | _ -> r )
  | Eraise (xs, e1) -> (
      let r = eval_expr env e1 in
      match r with Normal t -> Excep (xs, t) | _ -> r )
  | Eexn (_, e1) -> eval_expr env e1
  | Eassert (kind, t) ->
      if env.rac.do_rac then begin
          match kind with
          | Assert -> check_term (cntr_ctx "Assertion" env) t
          | Assume -> check_assume_term (cntr_ctx "Assumption" env) t
          | Check -> check_term (cntr_ctx "Check" env) t
        end;
      Normal (value ty_unit Vvoid)
  | Eghost e1 ->
      Debug.dprintf debug_trace_exec "@[<h>%tEVAL EXPR: GHOST %a@]@." pp_indent print_expr e1;
      (* TODO: do not eval ghost if no assertion check *)
      eval_expr env e1
  | Epure t ->
      Debug.dprintf debug_trace_exec "@[<h>%tEVAL EXPR: PURE %a@]@." pp_indent print_term t;
      let t = compute_term env t in
      Normal (value (Opt.get t.t_ty) (Vterm t))
  | Eabsurd ->
      Warning.emit "@[[Exec] unsupported expression: @[%a@]@]@."
        print_expr e ;
      Irred e

and exec_match env t ebl =
  let rec iter ebl =
    match ebl with
    | [] ->
        Warning.emit "[Exec] Pattern matching not exhaustive in evaluation@." ;
        assert false
    | (p, e) :: rem -> (
      try
        let env' = matching env t p.pp_pat in
        eval_expr env' e
      with NoMatch -> iter rem ) in
  iter ebl

and exec_call ?(main_function=false) ?loc env rs arg_pvs ity_result =
  let arg_vs = List.map (get_pvs env) arg_pvs in
  Debug.dprintf debug_trace_exec "@[<h>%tExec call %a %a@]@."
    pp_indent print_rs rs Pp.(print_list space print_value) arg_vs;
  let env = multibind_pvs rs.rs_cty.cty_args arg_vs env in
  let oldies =
    let snapshot_oldie old_pv pv =
      Mvs.add old_pv.pv_vs (snapshot (Mvs.find pv.pv_vs env.vsenv)) in
    Mpv.fold snapshot_oldie rs.rs_cty.cty_oldies Mvs.empty in
  let env =
    let vsenv = Mvs.union (fun _ _ v -> Some v) env.vsenv oldies in
    {env with vsenv} in
  let exec_kind =
    let can_interpret_abstractly =
      if rs_equal rs rs_func_app then false else
        match find_definition env rs with
        | LocalFunction _ -> true | _ -> false in
    if env.rac.rac_abstract && can_interpret_abstractly && not main_function
    then Log.ExecAbstract
    else Log.ExecConcrete in
  let mvs = let aux pv v = pv.pv_vs, snapshot v in
    Mvs.of_list (List.map2 aux rs.rs_cty.cty_args arg_vs) in
  let check_pre_and_register_call ?(any_function=false) exec_kind =
    if not main_function then
      if any_function then
        register_any_call env loc (Some rs) mvs
      else
        register_call env loc (Some rs) mvs exec_kind;
    if env.rac.do_rac then (
      let desc = cntr_desc "Precondition" rs.rs_name in
      let ctx = cntr_ctx desc ?trigger_loc:loc env in
      if main_function then check_assume_terms ctx rs.rs_cty.cty_pre
      else check_terms ctx rs.rs_cty.cty_pre ) in
  match exec_kind with
  | Log.ExecAbstract ->
      check_pre_and_register_call Log.ExecAbstract;
      let rs_name,cty = rs.rs_name, rs.rs_cty in
      exec_call_abstract ?loc ~rs_name env cty arg_pvs ity_result
  | Log.ExecConcrete ->
      let res =
        if rs_equal rs rs_func_app then begin
          check_pre_and_register_call Log.ExecConcrete;
          match arg_vs with
          | [{v_desc= Vfun (cl, arg, e)}; value] ->
              let env =
                let vsenv = Mvs.union (fun _ _ v -> Some v) env.vsenv cl in
                {env with vsenv} in
              let env = bind_vs arg value env in
              eval_expr env e
          | [{v_desc= Vpurefun (_, bindings, default)}; value] ->
              let v = try Mv.find value bindings with Not_found -> default in
              Normal v
          | _ -> assert false
          end
        else
          match rs, arg_vs with
          | {rs_logic= RLls ls}, [{v_desc= Vproj (ls', v)}]
            when ls_equal ls ls' -> (* Projection of a projection value *)
              check_pre_and_register_call Log.ExecConcrete;
              Normal v
          | _ -> match find_definition env rs with
            | LocalFunction (locals, ce) -> (
                let env = add_local_funs locals env in
                match ce.c_node with
                | Capp (rs', pvl) ->
                    check_pre_and_register_call Log.ExecConcrete;
                    Debug.dprintf debug_trace_exec "@[<h>%tEXEC CALL %a: Capp %a]@."
                      pp_indent print_rs rs print_rs rs';
                    exec_call ?loc env rs' (pvl @ arg_pvs) ity_result
                | Cfun body ->
                    check_pre_and_register_call Log.ExecConcrete;
                    Debug.dprintf debug_trace_exec "@[<hv2>%tEXEC CALL %a: FUN/%d %a@]@."
                      pp_indent print_rs rs (List.length ce.c_cty.cty_args) (pp_limited print_expr) body;
                    let env' = multibind_pvs ce.c_cty.cty_args arg_vs env in
                    eval_expr env' body
                | Cany ->
                    check_pre_and_register_call ~any_function:true Log.ExecAbstract;
                    let rs_name,cty = rs.rs_name, rs.rs_cty in
                    exec_call_abstract ?loc ~rs_name env cty arg_pvs ity_result
                | Cpur _ -> assert false (* TODO ? *) )
            | Builtin f ->
                check_pre_and_register_call Log.ExecConcrete;
                Debug.dprintf debug_trace_exec "@[<hv2>%tEXEC CALL %a: BUILTIN@]@." pp_indent print_rs rs;
                Normal (f rs arg_vs)
            | Constructor _ ->
                check_pre_and_register_call Log.ExecConcrete;
                Debug.dprintf debug_trace_exec "@[<hv2>%tEXEC CALL %a: CONSTRUCTOR@]@." pp_indent print_rs rs;
                let mt = List.fold_left2 ty_match Mtv.empty
                    (List.map (fun pv -> pv.pv_vs.vs_ty) rs.rs_cty.cty_args) (List.map v_ty arg_vs) in
                let ty = ty_inst mt (ty_of_ity ity_result) in
                let fs = List.map field arg_vs in
                Normal (value ty (Vconstr (rs, fs)))
            | Projection _d -> (
                check_pre_and_register_call Log.ExecConcrete;
                Debug.dprintf debug_trace_exec "@[<hv2>%tEXEC CALL %a: PROJECTION@]@." pp_indent print_rs rs;
                match rs.rs_field, arg_vs with
                | Some pv, [{v_desc= Vconstr (cstr, args)}] ->
                    let rec search constr_args args =
                      match constr_args, args with
                      | pv2 :: pvl, v :: vl ->
                          if pv_equal pv pv2 then
                            Normal (field_get v)
                          else search pvl vl
                      | _ -> assert false in
                    search cstr.rs_cty.cty_args args
                | _ -> assert false )
            | exception Not_found ->
                cannot_compute "definition of routine %s could not be found"
                  rs.rs_name.id_string in
      ( match res with
        | Normal v ->
            let desc = cntr_desc "Postcondition" rs.rs_name in
            check_posts desc loc env v rs.rs_cty.cty_post
        | Excep (xs, v) ->
            let desc = cntr_desc "Exceptional postcondition" rs.rs_name in
            let posts = Mxs.find xs rs.rs_cty.cty_xpost in
            check_posts desc loc env v posts
        | _ -> () );
      res

and exec_call_abstract ?loc ?rs_name env cty arg_pvs ity_result =
  (* let f (x1: ...) ... (xn: ...) = e
     ~>
     assert1 {f_pre};
     assign_written_vars_with_ce;
     assert2* {f_post};

     1 - if assert1 fails, then we have a real counterexample
     (precondition doesn't hold)
     2 - if assert2 fails, then we have a false counterexample
     (postcondition does not hold with the values obtained
     from the counterexample)
   *)
  let loc_or_dummy = Opt.get_def Loc.dummy_position loc in
  (* assert1 is already done above *)
  let res = match cty.cty_post with
    | p :: _ -> let (vs,_) = open_post p in
                id_clone vs.vs_name
    | _ -> id_fresh "result" in
  let res = create_vsymbol res (ty_of_ity ity_result) in
  let vars_map = Mpv.of_list (List.combine cty.cty_args arg_pvs) in
  let asgn_wrt = assign_written_vars ~vars_map
                   cty.cty_effect.eff_writes loc_or_dummy env in
  List.iter asgn_wrt (Mvs.keys env.vsenv);
  let res_v = get_and_register_value ~ity:ity_result env res
                loc_or_dummy in
  (* assert2 *)
  let msg = "Assume postcondition" in
  let msg = match rs_name with
    | None -> cntr_desc_str msg "anonymous function"
    | Some name -> cntr_desc msg name in
  let ctx = cntr_ctx msg ?trigger_loc:loc env in
  check_assume_posts ctx res_v cty.cty_post;
  Normal res_v

(* GLOBAL EVALUATION *)

let init_real (emin, emax, prec) = Big_real.init emin emax prec

let bind_globals ?rs_main mod_known env =
  let get_value id opt_e ity =
    let name = string_or_model_trace id in
    match env.rac.get_value ~name ?loc:id.id_loc ity with
    | Some v -> register_used_value env id.id_loc id v; v
    | None ->
       match opt_e with
       | None ->
          let v = default_value_of_type env.env mod_known ity in
          register_used_value env id.id_loc id v; v
       | Some e ->
          let env' = {env with rac= {env.rac with rac_abstract= false}} in
          register_const_init env id.id_loc id;
          match eval_expr env' e with
          | Normal v -> v
          | Excep _ -> cannot_compute "initialization of global variable %a raised an exception"
                         print_decoded id.id_string
          | Irred _ -> cannot_compute "initialization of global variable %a is irreducible"
                         print_decoded id.id_string
  in
  let open Pdecl in
  let eval_global _ d env =
    match d.pd_node with
    | PDlet (LDvar (pv, e)) ->
        let v = get_value pv.pv_vs.vs_name (Some e) e.e_ity in
        bind_vs pv.pv_vs v env
    | PDlet (LDsym (rs, ce)) when is_prog_constant d -> (
        assert (ce.c_cty.cty_args = []);
        let opt_e = match ce.c_node with
          | Cany -> None | Cfun e -> Some e
          | _ -> failwith "eval_globals: program constant cexp" in
        let v = get_value rs.rs_name opt_e ce.c_cty.cty_result in
        check_assume_posts (cntr_ctx "Any postcondition" env) v ce.c_cty.cty_post;
        bind_rs rs v env )
    | _ -> env in
  let is_before id d (env, found_rs) =
    let found_rs_here = match d.pd_node with
      | PDlet (LDsym (rs, _)) -> Opt.equal rs_equal (Some rs) rs_main
      | PDlet (LDrec ds) -> List.exists (fun d -> Opt.equal rs_equal (Some d.rec_sym) rs_main) ds
      | _ -> false in
    let found_rs = found_rs || found_rs_here in
    let env = if found_rs then env else Mid.add id d env in
    env, found_rs in
  let mod_known, _ = Mid.fold is_before mod_known (Mid.empty, false) in
  Mid.fold eval_global mod_known env

let eval_global_fundef rac env mod_known th_known locals e =
  get_builtin_progs env ;
  let env = default_env env rac mod_known th_known in
  let env = bind_globals mod_known env in
  let env = add_local_funs locals env in
  let res = eval_expr env e in
  res, env.vsenv, env.rsenv

let eval_rs rac env pm rs =
  let open Pmodule in
  let mod_known = pm.mod_known in
  let th_known = pm.mod_theory.Theory.th_known in
  let get_value (pv: pvsymbol) =
    let id = pv.pv_vs.vs_name in
    let name = string_or_model_trace id in
    match rac.get_value ~name ?loc:id.id_loc pv.pv_ity with
    | Some v -> v
    | None ->
       let v = default_value_of_type env mod_known pv.pv_ity in
       Debug.dprintf debug_rac_values
         "@[<h>Missing value for parameter %a, continue with default value %a.@]@."
         print_pv pv print_value v;
       v in
  get_builtin_progs env ;
  let env = default_env env rac mod_known th_known in
  let env = bind_globals ~rs_main:rs mod_known env in
  let env = multibind_pvs ~register:(register_used_value env rs.rs_name.id_loc)
      rs.rs_cty.cty_args (List.map get_value rs.rs_cty.cty_args) env in
  register_exec_main env rs;
  let e_loc = Opt.get_def Loc.dummy_position rs.rs_name.id_loc in
  let res = exec_call ~main_function:true ~loc:e_loc env rs rs.rs_cty.cty_args rs.rs_cty.cty_result in
  register_ended env rs.rs_name.id_loc;
  res, env

let report_eval_result body fmt (res, vsenv, rsenv) =
  let print_envs fmt =
    pp_env print_vs print_value fmt (Mvs.bindings vsenv);
    (* if not (Mvs.is_empty vsenv) && not (Mrs.is_empty rsenv) then
     *   fprintf fmt "%a" env_sep ();
     * pp_env print_rs print_value fmt (Mrs.bindings rsenv) *)
    ignore rsenv
  in
  match res with
  | Normal _ ->
      fprintf fmt "@[<hov2>result:@ %a@ =@ %a@]@,"
        print_ity body.e_ity print_logic_result res;
      fprintf fmt "@[<hov2>globals:@ %t@]" print_envs
  | Excep _ ->
      fprintf fmt "@[<hov2>exceptional result:@ %a@]@,"
        print_logic_result res;
      fprintf fmt "@[<hov2>globals:@ %t@]" print_envs
  | Irred _ ->
      fprintf fmt "@[<hov2>Execution error: %a@]@," print_logic_result res ;
      fprintf fmt "@[globals:@ %t@]" print_envs

let report_cntr fmt (ctx, term) =
  report_cntr fmt (ctx, "has failed", term)
