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




val schedule_proof_attempt : 
  debug:bool -> timelimit:int -> memlimit:int -> prover:prover -> 
  command:string -> driver:Why.Driver.driver -> 
  callback:(unit -> unit) -> goal -> unit
  (** schedules an attempt to prove goal with the given prover.  This
      function just prepares the goal for the proof attempt, and put
      it in the queue of waiting proofs attempts, associated with its
      callback.
      
      @param timelimit CPU time limit given for that attempt, in
      seconds, must be positive. (unlimited attempts are not allowed
      with this function)

      @param memlimit memory limit given for that attempt, must be
      positive. If not given, does not limit memory consumption

      @raise AlreadyAttempted if there already exists a non-obsolete
      external proof attempt with the same prover and time limit, or
      with a lower or equal time limit and a result different from Timeout


  *)

val start_queue_thread : int -> unit
(** starts another thread in charge of launching proof attempts
    the parameter is the maximal number of proof attempts to run in parallel.

    Whenever an external proof attempt terminates, the associated callback
    is called.

*)



(*
Local Variables: 
compile-command: "make -C ../.. bin/manager.byte"
End: 
*)




