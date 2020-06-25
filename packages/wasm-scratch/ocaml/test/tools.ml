open Ergo_lib

module Ejson = struct
  open Core

  let null = Ejnull
  let false_ = Ejbool false
  let true_ = Ejbool true
  let number x = Ejnumber x
  let string x = Ejstring (Ergo_lib.Util.char_list_of_string x)
end

module Imp = struct
  open Core

  let const x = ImpExprConst x

  let op x args = ImpExprOp (x, args)
  let not a = op EJsonOpNot a
  let and_ a = op EJsonOpAnd a
  let or_ a = op EJsonOpOr a
  let lt a = op EJsonOpLt a
  let gt a = op EJsonOpGt a
  let le a = op EJsonOpLe a
  let ge a = op EJsonOpGe a

  open Ejson
  let c_null = const null
  let c_false = const false_
  let c_true = const true_
  let c_number x = const (number x)
  let c_string x = const (string x)
end

let ejson_to_string x =
  Core.ejsonToString x |> Util.string_of_char_list
