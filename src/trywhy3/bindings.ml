open Js_of_ocaml
open Js

let log s = ignore (Firebug.console ## log (string s))

let log_time s =
  let date = new%js date_now in
  let date_str = string_of_float (date ## getTime /. 1000.) in
  log (date_str ^ " : " ^ s)

let check_def s o =
  Js.Optdef.get o (fun () ->
      log ("Object " ^ s ^ " is undefined or null");
      assert false)

let get_global ident =
  let res : 'a Js.optdef = Js.Unsafe.(get global) (Js.string ident) in
  check_def ident res

module Ace () = struct

  type marker

  class type annotation =
    object
      method row : int readonly_prop
      method column : int readonly_prop
      method text : js_string t readonly_prop
      method _type : js_string t readonly_prop
    end

  class type range =
    object
    end

  class type selection =
    object
      method setSelectionRange : range t -> bool t -> unit meth
    end

  class type editSession =
    object
      method addMarker : range t -> js_string t -> js_string t -> bool t -> marker meth
      method clearAnnotations : unit meth
      method getLength : int meth
      method removeMarker : marker -> unit meth
      method setAnnotations : annotation t js_array t -> unit meth
      method setMode : js_string t -> unit meth
    end

  class type editor =
    object
      method focus : unit meth
      method getSelection : selection t meth
      method getSession : editSession t meth
      method getValue : js_string t meth
      method gotoLine : int -> int -> bool t -> unit meth
      method redo : unit meth
      method setReadOnly : bool t -> unit meth
      method setTheme : js_string t -> unit meth
      method setValue : js_string t -> int -> unit meth
      method undo : unit meth
    end

  class type ace =
    object
      method edit : js_string t -> editor t optdef meth
      method require : js_string t -> Unsafe.any meth
    end

  let ace : ace Js.t = get_global "ace"
  let edit s = ace ## edit s

  let range : (int -> int -> int -> int -> range Js.t) Js.constr =
    let r =
      Unsafe.get (ace ## require (Js.string "ace/range")) (Js.string "Range")
    in
    check_def "Range" r

  let annotation row col text kind : annotation t =
    object%js
      val row = row
      val column = col
      val text = text
      val _type = kind
    end

end
