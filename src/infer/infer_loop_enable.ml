(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2019   --   Inria - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

#13 "src/mlw/infer_loop_enable.ml"
open Ident
open Term
open Ity
open Expr

let infer_flag =
  Debug.register_flag "infer-loop" ~desc:"Infer loop invariants"

let print_inferred_invs =
  Debug.register_flag "print-inferred-invs" ~desc:"Print inferred invariant"

let is_infer_attr s = Strings.has_prefix "infer" s || s = "infer"

let attrs_has_infer attrs =
  Sattr.exists (fun a -> is_infer_attr a.attr_string) attrs

let attrs_get_infer attrs =
  let s = Sattr.filter (fun a -> is_infer_attr a.attr_string) attrs in
  Sattr.choose s

type domain = Polyhedra | Box | Oct

let def_domain = Polyhedra
let def_wid = 3

(* operations from a certain Domain
   'a = context, 'b = D.man, 'c = cfg,
   'd = control_points, 'e = domain *)
type ('a,'b,'c,'d,'e) ai_ops = {
    domain_manager    : 'a -> 'b;
    empty_context     : unit -> 'a;
    start_cfg         : unit -> 'c;
    put_expr_in_cfg   : 'c -> 'a -> ?ret:vsymbol option -> expr -> 'd;
    put_expr_with_pre : 'c -> 'a -> expr -> term list -> 'd;
    eval_fixpoints    : 'c -> 'a -> (expr * 'e) list;
    domain_to_term    : 'c -> 'a -> 'e -> term;
    add_variable      : 'c -> 'a -> pvsymbol -> unit;
}

let ai_ops a b c d e f g h =
  {domain_manager  = a; empty_context     = b; start_cfg      = c;
   put_expr_in_cfg = d; put_expr_with_pre = e; eval_fixpoints = f;
   domain_to_term  = g; add_variable      = h}

let infer_with_ops ai_ops e cty =
  let cfg = ai_ops.start_cfg () in
  let context = ai_ops.empty_context () in
  List.iter (ai_ops.add_variable cfg context) cty.cty_args;
  ignore (ai_ops.put_expr_with_pre cfg context e cty.cty_pre);
  let fixp = ai_ops.eval_fixpoints cfg context in
  let domain2term (e,d) =
    let expl = "expl:infer-loop" in
    let t    = ai_ops.domain_to_term cfg context d in
    let t    = Term.t_attr_add (Ident.create_attribute expl) t in
    (e,t) in
  let invs = List.map domain2term fixp in
  if Debug.test_flag print_inferred_invs then begin
      Format.printf "### Debug: inferred invariants ###@\n";
      let print_i (_,t) = Format.printf "%a@\n" Pretty.print_term t in
      List.iter print_i invs;
      Format.printf "###@."
    end;
  invs

let infer_loops_for_dom ?(dom=def_domain) ?(wid=def_wid) env tkn mkn e cty =
  let module AI = Ai_cfg.Make (struct
       let env       = env
       let th_known  = tkn
       let mod_known = mkn
       let widening  = wid end) in
  match dom with
  | Polyhedra ->
     let module AI = AI(Domain.Polyhedra) in
     let ai_ops =
       ai_ops AI.domain_manager AI.empty_context AI.start_cfg
         AI.put_expr_in_cfg AI.put_expr_with_pre AI.eval_fixpoints
         AI.domain_to_term AI.add_variable in
     infer_with_ops ai_ops e cty
  | Box ->
     let module AI = AI(Domain.Box) in
     let ai_ops =
       ai_ops AI.domain_manager AI.empty_context AI.start_cfg
         AI.put_expr_in_cfg AI.put_expr_with_pre AI.eval_fixpoints
         AI.domain_to_term AI.add_variable in
     infer_with_ops ai_ops e cty
  | Oct ->
     let module AI = AI(Domain.Oct) in
     let ai_ops =
       ai_ops AI.domain_manager AI.empty_context AI.start_cfg
         AI.put_expr_in_cfg AI.put_expr_with_pre AI.eval_fixpoints
         AI.domain_to_term AI.add_variable in
     infer_with_ops ai_ops e cty

exception Parse_error

let parse_attr a =
  let parse_domain d =
    match String.lowercase_ascii d with
    | "polyhedra" -> Polyhedra
    | "box" -> Box
    | "oct" -> Oct
    | _ -> raise Parse_error in
  let parse_int i =
    try int_of_string i with
    | Failure _ (* "int_of_string" *) -> raise Parse_error in
  let al = String.split_on_char ':' a in
  match al with
  | ["infer"] -> def_domain, def_wid
  | ["infer";x] ->
     begin try parse_domain x, def_wid with
             Parse_error -> def_domain, parse_int x end
  | ["infer";x;y] ->
     begin try parse_domain x, parse_int y with
             Parse_error -> parse_domain y, parse_int x end
  | _ -> raise Parse_error

let infer_loops attrs env tkn mkn e cty =
  if attrs_has_infer attrs then
    let dom, wid =
      let attr = attrs_get_infer attrs in
      try parse_attr attr.attr_string with Parse_error ->
        Warning.emit ?loc:e.e_loc
          "invalid@ infer@ attribute@ (using@ default@ values)";
        def_domain, def_wid in
    infer_loops_for_dom ~dom ~wid env tkn mkn e cty
  else if Debug.test_flag infer_flag then
    infer_loops_for_dom env tkn mkn e cty
  else []
