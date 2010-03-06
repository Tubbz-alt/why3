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

open Format
open Pp
open Util
open Ident
open Ty
open Term
open Theory

let printer =
  let bl = ["theory"; "type"; "logic"; "inductive";
            "axiom"; "lemma"; "goal"; "use"; "clone";
            "namespace"; "import"; "export"; "end";
            "forall"; "exists"; "and"; "or"; "not";
            "true"; "false"; "if"; "then"; "else";
            "let"; "in"; "match"; "with"; "as"]
  in
  let sanitize = sanitizer char_to_alpha char_to_alnumus in
  create_printer bl ~sanitizer:sanitize

let print_id fmt id = Format.fprintf fmt "%s" (id_unique printer id)

(* some idents must be put in upper case *)
let print_uc fmt id =
  let sanitize = String.capitalize in
  let n = id_unique printer ~sanitizer:sanitize id in
  fprintf fmt "%s" n

(* and some in lower *)
let print_lc fmt id =
  let sanitize = String.uncapitalize in
  let n = id_unique printer ~sanitizer:sanitize id in
  fprintf fmt "%s" n

(* type variables always start with a quote *)
let print_tv fmt v =
  let sanitize n = String.concat "" ["'"; n] in
  let n = id_unique printer ~sanitizer:sanitize v in
  fprintf fmt "%s" n

let print_ts fmt ts = print_lc fmt ts.ts_name
let print_vs fmt vs = print_lc fmt vs.vs_name

let print_ls fmt ls =
  if ls.ls_constr then print_uc fmt ls.ls_name
                  else print_lc fmt ls.ls_name

let forget_var v = forget_id printer v.vs_name
let forget_tv v  = forget_id printer v

(** Types *)

let rec print_ty fmt ty = match ty.ty_node with
  | Tyvar v -> print_tv fmt v
  | Tyapp (ts, []) -> print_ts fmt ts
  | Tyapp (ts, [t]) -> fprintf fmt "%a %a" print_ty t print_ts ts
  | Tyapp (ts, l) -> fprintf fmt "(%a) %a"
      (print_list comma print_ty) l print_ts ts

let print_const fmt = function
  | ConstInt s -> fprintf fmt "%s" s
  | ConstReal (RConstDecimal (i,f,None)) -> fprintf fmt "%s.%s" i f
  | ConstReal (RConstDecimal (i,f,Some e)) -> fprintf fmt "%s.%se%s" i f e
  | ConstReal (RConstHexa (i,f,e)) -> fprintf fmt "0x%s.%sp%s" i f e

(* can the type of a value be derived from the type of the arguments? *)
let unambig_fs fs =
  let rec lookup v ty = match ty.ty_node with
    | Tyvar u when u == v -> true
    | _ -> ty_any (lookup v) ty
  in
  let lookup v = List.exists (lookup v) fs.ls_args in
  let rec inspect ty = match ty.ty_node with
    | Tyvar u when not (lookup u) -> false
    | _ -> ty_all inspect ty
  in
  inspect (of_option fs.ls_value)

(** Patterns, terms, and formulas *)

let lparen_l fmt () = fprintf fmt "@ ("
let lparen_r fmt () = fprintf fmt "(@,"
let print_paren_l fmt x = print_list_delim lparen_l rparen comma fmt x
let print_paren_r fmt x = print_list_delim lparen_r rparen comma fmt x

let rec print_pat fmt p = match p.pat_node with
  | Pwild -> fprintf fmt "_"
  | Pvar v -> print_vs fmt v
  | Pas (p,v) -> fprintf fmt "%a as %a" print_pat p print_vs v
  | Papp (cs,pl) -> fprintf fmt "%a%a"
      print_ls cs (print_paren_r print_pat) pl

let print_vsty fmt v =
  fprintf fmt "%a:@,%a" print_vs v print_ty v.vs_ty

let print_quant fmt = function
  | Fforall -> fprintf fmt "forall"
  | Fexists -> fprintf fmt "exists"

let print_binop fmt = function
  | Fand -> fprintf fmt "and"
  | For -> fprintf fmt "or"
  | Fimplies -> fprintf fmt "->"
  | Fiff -> fprintf fmt "<->"

let print_label fmt l = fprintf fmt "\"%s\"" l

let rec print_term fmt t = match t.t_label with
  | [] -> print_tnode fmt t
  | ll -> fprintf fmt "(%a %a)"
      (print_list space print_label) ll print_tnode t

and print_tnode fmt t = match t.t_node with
  | Tbvar _ ->
      assert false
  | Tvar v ->
      print_vs fmt v
  | Tconst c ->
      print_const fmt c
  | Tapp (fs, tl) when unambig_fs fs ->
      fprintf fmt "%a%a" print_ls fs
        (print_paren_r print_term) tl
  | Tapp (fs, tl) ->
      fprintf fmt "(%a%a:%a)" print_ls fs
        (print_paren_r print_term) tl print_ty t.t_ty
  | Tlet (t1,tb) ->
      let v,t2 = t_open_bound tb in
      fprintf fmt "@[<hov>let %a = %a in@ %a@]" print_vs v
        print_term t1 print_term t2;
      forget_var v
  | Tcase (t1,bl) ->
      fprintf fmt "@[<hov>match %a with@\n@[<hov>%a@]@]@\nend" print_term t1
        (print_list newline print_tbranch) bl
  | Teps fb ->
      let v,f = f_open_bound fb in
      fprintf fmt "@[<hov>epsilon %a in@ %a]" print_vs v print_fmla f;
      forget_var v

and print_tbranch fmt br =
  let pat,svs,t = t_open_branch br in
  fprintf fmt "@[<hov>| %a ->@ %a@]" print_pat pat print_term t;
  Svs.iter forget_var svs

and print_fmla fmt f = match f.f_label with
  | [] -> print_fnode fmt f
  | ll -> fprintf fmt "(%a %a)"
      (print_list space print_label) ll print_fnode f

and print_fnode fmt f = match f.f_node with
  | Fapp (ps,[t1;t2]) when ps = ps_equ ->
      fprintf fmt "%a = %a" print_term t1 print_term t2
  | Fapp (ps,tl) ->
      fprintf fmt "%a%a" print_ls ps
        (print_paren_r print_term) tl
  | Fquant (q,fq) ->
      let vl,tl,f = f_open_quant fq in
      fprintf fmt "(%a %a%a.@ %a)" print_quant q
        (print_list comma print_vsty) vl print_tl tl print_fmla f;
      List.iter forget_var vl
  | Ftrue ->
      fprintf fmt "true"
  | Ffalse ->
      fprintf fmt "false"
  | Fbinop (b,f1,f2) ->
      fprintf fmt "(%a %a@ %a)" print_fmla f1 print_binop b print_fmla f2
  | Fnot f ->
      fprintf fmt "not %a" print_fmla f
  | Flet (t,f) ->
      let v,f = f_open_bound f in
      fprintf fmt "@[<hov>let %a = %a in@ %a@]" print_vs v
        print_term t print_fmla f;
      forget_var v
  | Fcase (t,bl) ->
      fprintf fmt "@[<hov>match %a with@\n@[<hov>%a@]@]@\nend" print_term t
        (print_list newline print_fbranch) bl
  | Fif (f1,f2,f3) ->
      fprintf fmt "@[<hov>if %a@ then %a@ else %a@]"
        print_fmla f1 print_fmla f2 print_fmla f3

and print_fbranch fmt br =
  let pat,svs,f = f_open_branch br in
  fprintf fmt "@[<hov>| %a ->@ %a@]" print_pat pat print_fmla f;
  Svs.iter forget_var svs

and print_tl fmt tl =
  if tl = [] then () else fprintf fmt "@ [%a]"
    (print_list alt (print_list comma print_tr)) tl

and print_tr fmt = function
  | TrTerm t -> print_term fmt t
  | TrFmla f -> print_fmla fmt f


(** Declarations *)

let print_constr fmt cs =
  fprintf fmt "| %a%a" print_ls cs (print_paren_l print_ty) cs.ls_args

let print_ty_args fmt = function
  | [] -> ()
  | [tv] -> fprintf fmt " %a" print_tv tv
  | l -> print_paren_l print_tv fmt l

let print_type_decl fmt (ts,def) = match def with
  | Tabstract -> begin match ts.ts_def with
      | None ->
          fprintf fmt "@[<hov>type%a %a@]"
            print_ty_args ts.ts_args print_ts ts
      | Some ty ->
          fprintf fmt "@[<hov>type%a %a =@ @[<hov>%a@]@]"
            print_ty_args ts.ts_args print_ts ts print_ty ty
      end;
      List.iter forget_tv ts.ts_args
  | Talgebraic csl ->
      fprintf fmt "@[<hov>type%a %a =@\n@[<hov>%a@]@]"
        print_ty_args ts.ts_args print_ts ts
        (print_list newline print_constr) csl;
      List.iter forget_tv ts.ts_args

let print_indbr fmt (id,f) =
  fprintf fmt "| %a : %a" print_uc id print_fmla f

let print_logic_decl fmt = function
  | Lfunction  (fs,None) ->
      fprintf fmt "@[<hov 2>logic %a%a :@ %a@]"
        print_ls fs (print_paren_l print_ty) fs.ls_args
          print_ty (of_option fs.ls_value)
  | Lpredicate (ps,None) ->
      fprintf fmt "@[<hov 2>logic %a%a@]"
        print_ls ps (print_paren_l print_ty) ps.ls_args
  | Lfunction (fs,Some fd) ->
      let _,vl,t = open_fs_defn fd in
      fprintf fmt "@[<hov 2>logic %a%a :@ %a =@ %a@]"
        print_ls fs (print_paren_l print_vsty) vl
        print_ty t.t_ty print_term t;
      List.iter forget_var vl
  | Lpredicate (ps,Some fd) ->
      let _,vl,f = open_ps_defn fd in
      fprintf fmt "@[<hov 2>logic %a%a =@ %a@]"
        print_ls ps (print_paren_l print_vsty) vl print_fmla f;
      List.iter forget_var vl
  | Linductive (ps, bl) ->
      fprintf fmt "@[<hov 2>inductive %a@\n@[<hov>%a@]@]"
         print_ls ps (print_list newline print_indbr) bl

let print_pkind fmt = function
  | Paxiom -> fprintf fmt "axiom"
  | Plemma -> fprintf fmt "lemma"
  | Pgoal  -> fprintf fmt "goal"

let print_inst fmt (id1,id2) =
  fprintf fmt "%a = %a" print_id id1 print_id id2

let print_decl fmt d = match d.d_node with
  | Dtype tl  -> print_list newline2 print_type_decl  fmt tl
  | Dlogic ll -> print_list newline2 print_logic_decl fmt ll
  | Dprop (k,id,fmla) ->
      fprintf fmt "@[<hov 2>%a %a :@ %a@]"
        print_pkind k print_uc id print_fmla fmla
  | Duse th ->
      fprintf fmt "use export %a" print_id th.th_name
  | Dclone inst ->
      fprintf fmt "@[<hov 2>(* clone with@ %a *)@]"
      (print_list comma print_inst) inst

(* let print_decl fmt d = fprintf fmt "%a@\n" print_decl d *)

let print_decl_list fmt dl =
  fprintf fmt "@[<hov>%a@]" (print_list newline2 print_decl) dl

let print_context fmt ctxt =
  print_list newline2 print_decl fmt (Context.get_decls ctxt)

let print_theory fmt t =
  fprintf fmt "@[<hov 2>theory %a@\n%a@]@\nend@\n@."
    print_id t.th_name print_context t.th_ctxt

