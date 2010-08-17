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
open Why
open Util
open Whyconf
open Theory
open Task
open Driver
open Trans

let usage_msg =
  sprintf
  "Usage: %s [options] [[file|-] \
   [-a <transform> -T <theory> [-G <goal>]...]...]..."
  (Filename.basename Sys.argv.(0))

let opt_queue = Queue.create ()

let opt_input = ref None
let opt_theory = ref None
let opt_trans = ref []
let opt_metas = ref []

let add_opt_file x =
  let tlist = Queue.create () in
  Queue.push (Some x, tlist,!opt_trans) opt_queue;
  opt_input := Some tlist

let add_opt_theory =
  let rdot = (Str.regexp "\\.") in fun x ->
  let l = Str.split rdot x in
  let p, t = match List.rev l with
    | t::p -> List.rev p, t
    | _ -> assert false
  in
  match !opt_input, p with
  | None, [] ->
      eprintf "Option '-T'/'--theory' with a non-qualified \
        argument requires an input file.@.";
      exit 1
  | Some tlist, [] ->
      let glist = Queue.create () in
      Queue.push (x, p, t, glist, !opt_trans) tlist;
      opt_theory := Some glist
  | _ ->
      let tlist = Queue.create () in
      Queue.push (None, tlist, !opt_trans) opt_queue;
      opt_input := None;
      let glist = Queue.create () in
      Queue.push (x, p, t, glist, !opt_trans) tlist;
      opt_theory := Some glist

let add_opt_goal x = match !opt_theory with
  | None ->
      eprintf "Option '-G'/'--goal' requires a theory.@.";
      exit 1
  | Some glist ->
      let l = Str.split (Str.regexp "\\.") x in
      Queue.push (x, l, !opt_trans) glist

let add_opt_trans x = opt_trans := x::!opt_trans

let add_opt_meta meta =
  let meta_name, meta_arg =
    let index = String.index meta '=' in
    (String.sub meta 0 index),
    (String.sub meta (index+1) (String.length meta - (index + 1))) in
  opt_metas := (meta_name,meta_arg)::!opt_metas

let opt_config = ref None
let opt_parser = ref None
let opt_prover = ref None
let opt_loadpath = ref []
let opt_driver = ref None
let opt_output = ref None
let opt_timelimit = ref None
let opt_memlimit = ref None
let opt_command = ref None
let opt_task = ref None

let opt_print_theory = ref false
let opt_print_namespace = ref false
let opt_list_transforms = ref false
let opt_list_printers = ref false
let opt_list_provers = ref false
let opt_list_formats = ref false
let opt_list_metas = ref false

let opt_parse_only = ref false
let opt_type_only = ref false
let opt_debug = ref false

let option_list = Arg.align [
  "-", Arg.Unit (fun () -> add_opt_file "-"),
      " Read the input file from stdin";
  "-T", Arg.String add_opt_theory,
      "<theory> Select <theory> in the input file or in the library";
  "--theory", Arg.String add_opt_theory,
      " same as -T";
  "-G", Arg.String add_opt_goal,
      "<goal> Select <goal> in the last selected theory";
  "--goal", Arg.String add_opt_goal,
      " same as -G";
  "-C", Arg.String (fun s -> opt_config := Some s),
      "<file> Read configuration from <file>";
  "--config", Arg.String (fun s -> opt_config := Some s),
      " same as -C";
  "-L", Arg.String (fun s -> opt_loadpath := s :: !opt_loadpath),
      "<dir> Add <dir> to the library search path";
  "--library", Arg.String (fun s -> opt_loadpath := s :: !opt_loadpath),
      " same as -L";
  "-I", Arg.String (fun s -> opt_loadpath := s :: !opt_loadpath),
      " same as -L (obsolete)";
  "-P", Arg.String (fun s -> opt_prover := Some s),
      "<prover> Prove or print (with -o) the selected goals";
  "--prover", Arg.String (fun s -> opt_prover := Some s),
      " same as -P";
  "-F", Arg.String (fun s -> opt_parser := Some s),
      "<format> Input format (default: \"why\")";
  "--format", Arg.String (fun s -> opt_parser := Some s),
      " same as -F";
  "-t", Arg.Int (fun i -> opt_timelimit := Some i),
      "<sec> Set the prover's time limit (default=10, no limit=0)";
  "--timelimit", Arg.Int (fun i -> opt_timelimit := Some i),
      " same as -t";
  "-m", Arg.Int (fun i -> opt_memlimit := Some i),
      "<MiB> Set the prover's memory limit (default: no limit)";
  "--memlimit", Arg.Int (fun i -> opt_timelimit := Some i),
      " same as -m";
  "-M", Arg.String add_opt_meta,
    "<meta_name>=<string> Add a meta option to each tasks";
  "-D", Arg.String (fun s -> opt_driver := Some s),
      "<file> Specify a prover's driver (conflicts with -P)";
  "--driver", Arg.String (fun s -> opt_driver := Some s),
      " same as -D";
  "-o", Arg.String (fun s -> opt_output := Some s),
      "<dir> Print the selected goals to separate files in <dir>";
  "--output", Arg.String (fun s -> opt_output := Some s),
      " same as -o";
  "--print-theory", Arg.Set opt_print_theory,
      " Print the selected theories";
  "--print-namespace", Arg.Set opt_print_namespace,
      " Print the namespaces of selected theories";
  "--list-transforms", Arg.Set opt_list_transforms,
      " List the registered transformations";
  "--list-printers", Arg.Set opt_list_printers,
      " List the registered printers";
  "--list-provers", Arg.Set opt_list_provers,
      " List the known provers";
  "--list-formats", Arg.Set opt_list_formats,
      " List the known input formats";
  "--list-metas", Arg.Set opt_list_metas,
    " List the known metas option (currently only with one string argument)";
  "--parse-only", Arg.Set opt_parse_only,
      " Stop after parsing";
  "--type-only", Arg.Set opt_type_only,
      " Stop after type checking";
  "--debug", Arg.Set opt_debug,
      " Set the debug flag";
  "-a", Arg.String add_opt_trans,
  "<transformation> Add a transformation to apply to the task" ;
  "--apply-transform", Arg.String add_opt_trans,
  " same as -a" ]

let () =
  Arg.parse option_list add_opt_file usage_msg;

  (* TODO? : Since drivers can dynlink ml code they can add printer,
     transformations, ... So drivers should be loaded before listing *)
  if !opt_list_transforms then begin
    printf "@[<hov 2>Transed non-splitting transformations:@\n%a@]@\n@."
      (Pp.print_list Pp.newline Pp.string)
      (List.sort String.compare (Trans.list_transforms ()));
    printf "@[<hov 2>Transed splitting transformations:@\n%a@]@\n@."
      (Pp.print_list Pp.newline Pp.string)
      (List.sort String.compare (Trans.list_transforms_l ()));
  end;
  if !opt_list_printers then begin
    printf "@[<hov 2>Transed printers:@\n%a@]@\n@."
      (Pp.print_list Pp.newline Pp.string)
      (List.sort String.compare (Printer.list_printers ()))
  end;
  if !opt_list_formats then begin
    let print1 fmt s = fprintf fmt "%S" s in
    let print fmt (p, l) =
      fprintf fmt "%s [%a]" p (Pp.print_list Pp.comma print1) l
    in
    printf "@[<hov 2>Known input formats:@\n%a@]@."
      (Pp.print_list Pp.newline print)
      (List.sort Pervasives.compare (Env.list_formats ()))
  end;
  if !opt_list_provers then begin
    let config = read_config !opt_config in
    let print fmt s prover = fprintf fmt "%s (%s)@\n" s prover.name in
    let print fmt m = Mstr.iter (print fmt) m in
    printf "@[<hov 2>Known provers:@\n%a@]@." print config.provers
  end;
  if !opt_list_metas then begin
    let metas = list_metas () in
    let fold acc m = match m.meta_type with
      | [MTstring] when m.meta_excl -> Smeta.add m acc
      | _ -> acc
    in
    let metas = List.fold_left fold Smeta.empty metas in
    printf "@[<hov 2>Known metas:@\n%a@]@\n@."
      (Pp.print_iter1 Smeta.iter Pp.newline
         (fun fmt m -> pp_print_string fmt m.meta_name))
      metas
  end;
  if !opt_list_transforms || !opt_list_printers || !opt_list_provers ||
     !opt_list_formats || !opt_list_metas
  then exit 0;

  if Queue.is_empty opt_queue then begin
    Arg.usage option_list usage_msg;
    exit 1
  end;

  if !opt_prover <> None && !opt_driver <> None then begin
    eprintf "Options '-P'/'--prover' and \
      '-D'/'--driver' cannot be used together.@.";
    exit 1
  end;

  if !opt_prover = None then begin
    if !opt_driver = None && !opt_output <> None then begin
      eprintf "Option '-o'/'--output' requires a prover or a driver.@.";
      exit 1
    end;
    if !opt_timelimit <> None then begin
      eprintf "Option '-t'/'--timelimit' requires a prover.@.";
      exit 1
    end;
    if !opt_memlimit <> None then begin
      eprintf "Option '-m'/'--memlimit' requires a prover.@.";
      exit 1
    end;
    if !opt_driver = None && not !opt_print_namespace then
      opt_print_theory := true
  end;

  let config = try read_config !opt_config with Not_found ->
    option_iter (eprintf "Config file '%s' not found.@.") !opt_config;
    option_iter
      (eprintf "No config file found (required by '-P %s').@.") !opt_prover;
    if !opt_config <> None || !opt_prover <> None then exit 1;
    { conf_file = "";
      loadpath  = [];
      timelimit = None;
      memlimit  = None;
      provers   = Mstr.empty }
  in

  opt_loadpath := List.rev_append !opt_loadpath config.loadpath;
  if !opt_timelimit = None then opt_timelimit := config.timelimit;
  if !opt_memlimit  = None then opt_memlimit  := config.memlimit;
  begin match !opt_prover with
  | Some s ->
      let prover = try Mstr.find s config.provers with
        | Not_found -> eprintf "Driver %s not found.@." s; exit 1
      in
      opt_command := Some prover.command;
      opt_driver := Some prover.driver
  | None ->
    () end;
  let add_meta task (meta,s) =
    let meta = lookup_meta meta in
    add_meta task meta [MAstr s] in
  opt_task := List.fold_left add_meta !opt_task !opt_metas

let timelimit = match !opt_timelimit with
  | None -> 10
  | Some i when i <= 0 -> 0
  | Some i -> i

let memlimit = match !opt_memlimit with
  | None -> 0
  | Some i when i <= 0 -> 0
  | Some i -> i

let debug = !opt_debug

let print_th_namespace fmt th =
  Pretty.print_namespace fmt th.th_name.Ident.id_string th

let fname_printer = ref (Ident.create_ident_printer [])

let do_task drv fname tname (th : Why.Theory.theory) (task : Task.task) =
  match !opt_output, !opt_command with
    | None, Some command ->
        let res =
          Driver.prove_task ~debug ~command ~timelimit ~memlimit drv task ()
        in
        printf "%s %s %s : %a@." fname tname
          (task_goal task).Decl.pr_name.Ident.id_string
          Call_provers.print_prover_result res
    | None, None ->
        Driver.print_task ~debug drv std_formatter task
    | Some dir, _ ->
        let fname = Filename.basename fname in
        let fname =
          try Filename.chop_extension fname with _ -> fname
        in
        let tname = th.th_name.Ident.id_string in
        let dest = Driver.file_of_task drv fname tname task in
        (* Uniquify the filename before the extension if it exists*)
        let i = try String.rindex dest '.' with _ -> String.length dest in
        let name = Ident.string_unique !fname_printer (String.sub dest 0 i) in
        let ext = String.sub dest i (String.length dest - i) in
        let cout = open_out (Filename.concat dir (name ^ ext)) in
        Driver.print_task ~debug drv (formatter_of_out_channel cout) task;
        close_out cout

let do_tasks env drv fname tname th trans task =
  let lookup acc t =
    (try t, Trans.singleton (Trans.lookup_transform t env) with
       Trans.UnknownTrans _ -> t, Trans.lookup_transform_l t env) :: acc
  in
  let transl = List.fold_left lookup [] trans in
  let apply tasks (s, tr) =
    try
      if debug then Format.eprintf "apply transformation %s@." s;
      let l = List.fold_left
        (fun acc task ->
           List.rev_append (Trans.apply tr task) acc) [] tasks in
      List.rev l (* In order to keep the order for 1-1 transformation *)
    with e when not debug ->
      Format.eprintf "failure in transformation %s@." s;
      raise e
  in
  let tasks = List.fold_left apply [task] transl in
  List.iter (do_task drv fname tname th) tasks

let do_theory env drv fname tname th trans glist =
  if !opt_print_theory then
    printf "%a@." Pretty.print_theory th
  else if !opt_print_namespace then
    printf "%a@." print_th_namespace th
  else begin
    let add (accm,accs) (x,l,trans) =
      let pr = try ns_find_pr th.th_export l with Not_found ->
        eprintf "Goal '%s' not found in theory '%s'.@." x tname;
        exit 1
      in
      let accs = Decl.Spr.add pr accs in
      (pr,trans)::accm,accs
    in
    let drv = Util.of_option drv in
    if Queue.is_empty glist
    then
      let tasks = List.rev (split_theory th None !opt_task) in
      let do_tasks = do_tasks env drv fname tname th trans in
      List.iter do_tasks tasks
    else
      let prtrans,prs = Queue.fold add ([],Decl.Spr.empty) glist in
      let tasks = split_theory th (Some prs) !opt_task in
      let recover_pr mpr task =
        let pr = task_goal task in
        Decl.Mpr.add pr task mpr in
      let mpr = List.fold_left recover_pr Decl.Mpr.empty tasks in
      let do_tasks (pr,trans) =
        let task = Decl.Mpr.find pr mpr in
        do_tasks env drv fname tname th trans task in
      List.iter do_tasks (List.rev prtrans)
  end

let do_global_theory env drv (tname,p,t,glist,trans) =
  let th = try Env.find_theory env p t with Env.TheoryNotFound _ ->
    eprintf "Theory '%s' not found.@." tname;
    exit 1
  in
  do_theory env drv "lib" tname th trans glist

let do_local_theory env drv fname m (tname,_,t,glist,trans) =
  let th = try Mnm.find t m with Not_found ->
    eprintf "Theory '%s' not found in file '%s'.@." tname fname;
    exit 1
  in
  do_theory env drv fname tname th trans glist

let do_input env drv = function
  | None, _, _ when !opt_parse_only || !opt_type_only ->
      ()
  | None, tlist, _ ->
      Queue.iter (do_global_theory env drv) tlist
  | Some f, tlist, trans ->
      let fname, cin = match f with
        | "-" -> "stdin", stdin
        | f   -> f, open_in f
      in
      let report = Env.report ?name:!opt_parser fname in
      try
	let m =
	  Env.read_channel ?name:!opt_parser ~debug:!opt_debug
	    ~parse_only:!opt_parse_only ~type_only:!opt_type_only
	    env fname cin
	in
        close_in cin;
        if !opt_type_only then
	  ()
        else if Queue.is_empty tlist then
          let glist = Queue.create () in
          let add_th t th mi = Ident.Mid.add th.th_name (t,th) mi in
          let do_th _ (t,th) = do_theory env drv fname t th trans glist in
          Ident.Mid.iter do_th (Mnm.fold add_th m Ident.Mid.empty)
        else
          Queue.iter (do_local_theory env drv fname m) tlist
      with
	| Loc.Located (loc, e) ->
	    eprintf "@[%a%a@]@." Loc.report_position loc report e; exit 1
	| e ->
	    eprintf "@[%a@]@." report e; exit 1

let () =
  try
    let env = Env.create_env (Typing.retrieve !opt_loadpath) in
    let drv = Util.option_map (load_driver env) !opt_driver in
    Queue.iter (do_input env drv) opt_queue
  with e when not debug ->
    eprintf "%a@." Exn_printer.exn_printer e;
    exit 1

(*
Local Variables:
compile-command: "unset LANG; make -C .. byte"
End:
*)
