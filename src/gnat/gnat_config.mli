open Why3

(* Configuration settings given more or less by the why3.conf file *)

val config : Whyconf.config
val env : Env.env
val prover_driver : Driver.driver
val prover : Whyconf.config_prover

(* Configuration settings given or determined by the command line *)

val timeout : int
(* value of the -t/--timeout option, default value 10 *)

val verbose : bool
(* true if option -v/--verbose was present *)

type report_mode = Fail | Verbose | Detailed
(* In mode fail, only print failed proof objectives.
   In mode verbose, print all proof objectives.
   In mode detailed, additionally print if VC was timeout or if prover stopped.
   *)

val report : report_mode
(* true if option --report was present *)

val debug : bool
(* true if option --debug was present *)

val force : bool
(* true of option --force/-f was present *)

(* Configuration settings related to input and output *)

val filename : string
(* the name of the input file *)

val noproof : bool
(* true if option --no-proof was present *)

val split_name : string
(* name of the "split_goal" transformation *)

val limit_line : Gnat_loc.loc option
(* set if option --limit-line was given; we only prove VCs from that line *)

val limit_subp : Ident.label option
(* set if option --limit-subp was given; we only prove VCs from that subprogram
   *)

val ide_progress_bar : bool
(* set if option --ide-progress-bar was given, to issue formatted output on
   current numbers of VCs proved *)

val parallel : int
(* number of parallel processes that can be run in parallel for proving VCs *)
