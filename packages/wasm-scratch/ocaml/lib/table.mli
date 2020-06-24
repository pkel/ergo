type 'a t (** A table with elements of type ['a]. *)

val create : element_size:('a -> int) -> 'a t
(** Create an empty table for elements of type ['a].
 *  The [element_size] function defines the size of a single element.
 *)

val offset : 'a t -> 'a -> int
(** Return the offset of a table element within the table. If the element is
 *  not in the table, it will be appended.
 *)

val elements : 'a t -> (int * 'a) list
(** Return all elements of the table together with their offset.
 *  The returned list is ordered by increasing offset. *)

val size : 'a t -> int
(** Return the size of the table. This is also the offset of the next element
 *  that is appended to the table. *)
