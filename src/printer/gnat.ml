(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-2012                                               *)
(*    François Bobot                                                      *)
(*    Jean-Christophe Filliâtre                                           *)
(*    Claude Marché                                                       *)
(*    Guillaume Melquiond                                                 *)
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

(** Why3 printer *)

open Format
open Pp
open Util
open Ident
open Ty
open Term
open Decl
open Printer
open Theory

let iprinter,aprinter,tprinter,pprinter =
  let bl = ["theory"; "type"; "function"; "predicate"; "inductive";
            "axiom"; "lemma"; "goal"; "use"; "clone"; "prop"; "meta";
            "namespace"; "import"; "export"; "end";
            "forall"; "exists"; "not"; "true"; "false"; "if"; "then"; "else";
            "let"; "in"; "match"; "with"; "as"; "epsilon" ] in
  let isanitize = sanitizer char_to_alpha char_to_alnumus in
  let lsanitize = sanitizer char_to_lalpha char_to_alnumus in
  create_ident_printer bl ~sanitizer:isanitize,
  create_ident_printer bl ~sanitizer:lsanitize,
  create_ident_printer bl ~sanitizer:lsanitize,
  create_ident_printer bl ~sanitizer:isanitize

(* type variables always start with a quote *)
let print_tv fmt tv =
  fprintf fmt "'%s" (id_unique aprinter tv.tv_name)

(* logic variables always start with a lower case letter *)
let print_vs fmt vs =
  let sanitizer = String.uncapitalize in
  fprintf fmt "%s" (id_unique iprinter ~sanitizer vs.vs_name)

let forget_var vs = forget_id iprinter vs.vs_name

(* theory names always start with an upper case letter *)
let print_th fmt th =
  let sanitizer = String.capitalize in
  fprintf fmt "%s" (id_unique iprinter ~sanitizer th.th_name)

let print_ts fmt ts =
  fprintf fmt "%s" (id_unique tprinter ts.ts_name)

let print_ls fmt ls =
  fprintf fmt "%s" (id_unique iprinter ls.ls_name)

let print_cs fmt ls =
  let sanitizer = String.capitalize in
  fprintf fmt "%s" (id_unique iprinter ~sanitizer ls.ls_name)

let print_pr fmt pr =
  fprintf fmt "%s" (id_unique pprinter pr.pr_name)

(* info *)

type info = { info_syn : syntax_map }

let info = ref { info_syn = Mid.empty }

let query_syntax id = query_syntax !info.info_syn id
let query_remove id = Mid.mem id !info.info_syn

(** Types *)

let protect_on x s = if x then "(" ^^ s ^^ ")" else s

let rec print_ty_node inn fmt ty = match ty.ty_node with
  | Tyvar v -> print_tv fmt v
  | Tyapp (ts, tl) -> begin match query_syntax ts.ts_name with
      | Some s -> syntax_arguments s (print_ty_node false) fmt tl
      | None -> begin match tl with
          | [] -> print_ts fmt ts
          | tl -> fprintf fmt (protect_on inn "%a@ %a")
              print_ts ts (print_list space (print_ty_node true)) tl
          end
      end

let print_ty = print_ty_node false

(* can the type of a value be derived from the type of the arguments? *)
let unambig_fs fs =
  let rec lookup v ty = match ty.ty_node with
    | Tyvar u when tv_equal u v -> true
    | _ -> ty_any (lookup v) ty
  in
  let lookup v = List.exists (lookup v) fs.ls_args in
  let rec inspect ty = match ty.ty_node with
    | Tyvar u when not (lookup u) -> false
    | _ -> ty_all inspect ty
  in
  option_apply true inspect fs.ls_value

(** Patterns, terms, and formulas *)

let rec print_pat_node pri fmt p = match p.pat_node with
  | Pwild ->
      fprintf fmt "_"
  | Pvar v ->
      print_vs fmt v
  | Pas (p, v) ->
      fprintf fmt (protect_on (pri > 1) "%a as %a")
        (print_pat_node 1) p print_vs v
  | Por (p, q) ->
      fprintf fmt (protect_on (pri > 0) "%a | %a")
        (print_pat_node 0) p (print_pat_node 0) q
  | Papp (cs, pl) -> begin match query_syntax cs.ls_name with
      | Some s -> syntax_arguments s (print_pat_node 0) fmt pl
      | None -> begin match pl with
          | [] -> print_cs fmt cs
          | pl -> fprintf fmt (protect_on (pri > 1) "%a@ %a")
              print_cs cs (print_list space (print_pat_node 2)) pl
          end
      end

let print_pat = print_pat_node 0

let print_vsty fmt v =
  fprintf fmt "%a:@,%a" print_vs v print_ty v.vs_ty

let print_const = Pretty.print_const
let print_quant = Pretty.print_quant
let print_binop = Pretty.print_binop

let prio_binop = function
  | Tand -> 3
  | Tor -> 2
  | Timplies -> 1
  | Tiff -> 1

let rec print_term fmt t = print_tnode 0 fmt t

and print_app pri fs fmt tl =
  match query_syntax fs.ls_name with
    | Some s -> syntax_arguments s print_term fmt tl
    | None -> begin match tl with
        | [] -> print_ls fmt fs
        | tl -> fprintf fmt (protect_on (pri > 5) "%a@ %a")
            print_ls fs (print_list space (print_tnode 6)) tl
        end

and print_tnode pri fmt t = match t.t_node with
  | Tvar v ->
      print_vs fmt v
  | Tconst c ->
      print_const fmt c
  | Tapp (fs, tl) when unambig_fs fs ->
      print_app pri fs fmt tl
  | Tapp (fs, tl) ->
      fprintf fmt (protect_on (pri > 0) "%a:%a")
        (print_app 5 fs) tl print_ty (t_type t)
  | Tif (f,t1,t2) ->
      fprintf fmt (protect_on (pri > 0) "if @[%a@] then %a@ else %a")
        print_term f print_term t1 print_term t2
  | Tlet (t1,tb) ->
      let v,t2 = t_open_bound tb in
      fprintf fmt (protect_on (pri > 0) "let %a = @[%a@] in@ %a")
        print_vs v (print_tnode 4) t1 print_term t2;
      forget_var v
  | Tcase (t1,bl) ->
      fprintf fmt "match @[%a@] with@\n@[<hov>%a@]@\nend"
        print_term t1 (print_list newline print_tbranch) bl
  | Teps fb ->
      let v,f = t_open_bound fb in
      fprintf fmt (protect_on (pri > 0) "epsilon %a.@ %a")
        print_vsty v print_term f;
      forget_var v
  | Tquant (q,fq) ->
      let vl,tl,f = t_open_quant fq in
      fprintf fmt (protect_on (pri > 0) "%a %a%a.@ %a") print_quant q
        (print_list comma print_vsty) vl print_tl tl print_term f;
      List.iter forget_var vl
  | Ttrue ->
      fprintf fmt "true"
  | Tfalse ->
      fprintf fmt "false"
  | Tbinop (b,f1,f2) ->
      let asym = Slab.mem Term.asym_label f1.t_label in
      let p = prio_binop b in
      fprintf fmt (protect_on (pri > p) "%a %a@ %a")
        (print_tnode (p + 1)) f1 (print_binop ~asym) b (print_tnode p) f2
  | Tnot f ->
      fprintf fmt (protect_on (pri > 4) "not %a") (print_tnode 4) f

and print_tbranch fmt br =
  let p,t = t_open_branch br in
  fprintf fmt "@[<hov 4>| %a ->@ %a@]" print_pat p print_term t;
  Svs.iter forget_var p.pat_vars

and print_tl fmt tl =
  if tl = [] then () else fprintf fmt "@ [%a]"
    (print_list alt (print_list comma print_term)) tl

let rec print_right_most fmt t =
   match t.t_node with
   | Tquant (_,tq) ->
         let _,_,t = t_open_quant tq in
         print_right_most fmt t
   | Tlet (_,tb) ->
         let _, t = t_open_bound tb in
         print_right_most fmt t
   | Tbinop (Timplies,_,t2) ->
         print_right_most fmt t2
   | _ ->
         print_term fmt t


let print_task _env _ _ ?old:_ fmt task =
   (* only print the rightmost predicate *)
   let fml = Task.task_goal_fmla task in
   print_right_most fmt fml

let () = register_printer "gnat" print_task

