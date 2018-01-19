Add Rec LoadPath "/home/zeimer/Code/Coq".

Require Import HSLib.Base.

Require Import HSLib.Applicative.Applicative.
Require Import HSLib.Alternative.Alternative.
Require Import HSLib.MonadBind.Monad.
Require Import HSLib.MonadPlus.MonadPlus.
Require Import HSLib.MonadTrans.MonadTrans.

(* TODO: find out wut's up with commutative monads and commutative
   applicatives *)

Definition ListT
  (M : Type -> Type) (A : Type) : Type :=
    forall X : Type, M X -> (A -> M X -> M X) -> M X.

(* Modified version of list notations from standard library. *)
Module ListT_Notations.

Notation "[[ ]]" :=
  (fun X nil _ => nil).
Notation "[[ x ]]" :=
  (fun X nil cons => cons x nil).
Notation "[[ x ; y ; .. ; z ]]" :=
  (fun X nil cons => cons x (cons y .. (cons z nil) ..)).
Notation "[[ x ; .. ; y ]]" :=
  (fun X nil cons => cons x .. (cons y nil) ..) (compat "8.4").

End ListT_Notations.

Export ListT_Notations.

Definition fmap_ListT
  {M : Type -> Type} {inst : Functor M} {A B : Type}
  (f : A -> B) (l : ListT M A) : ListT M B :=
    fun (X : Type) (nil : M X) (cons : B -> M X -> M X) =>
      l X nil (fun h t => cons (f h) t).

(*Definition wut := M[[0; 1; 2]].*)
Definition wut
  {M : Type -> Type} {inst : Monad M} : ListT M nat := [[0; 1; 2]].

Eval lazy in wut.
Eval lazy in fmap_ListT (plus 2) wut.

Instance Functor_ListT
  (M : Type -> Type) (inst : Functor M) : Functor (ListT M) :=
{
    fmap := @fmap_ListT M inst
}.
Proof.
  all: intros; unfold fmap_ListT;
    exts; unfold id, compose; f_equal.
Defined.

Definition ret_ListT
  (M : Type -> Type) (inst : Monad M) (A : Type) (x : A) : ListT M A :=
    fun (X : Type) (nil : M X) (cons : A -> M X -> M X) => ret (cons x nil).

Definition length_ListT
  {M : Type -> Type} {inst : Monad M} {A : Type}
  (l : ListT M A) : M nat :=
    l nat (ret 0) (fun _ => fmap S).

Eval lazy in length_ListT wut.

Definition ap_ListT
  {M : Type -> Type} {inst : Monad M} {A B : Type}
  (mfs : ListT M (A -> B)) (mxs : ListT M A) : ListT M B :=
    fun X nil cons =>
      mfs X nil (fun f fs => fmap f mxs X fs cons).

Definition fs
  {M : Type -> Type} {inst : Monad M} : ListT M (nat -> nat) :=
    [[plus 2; mult 2]].

Eval lazy in ap_ListT fs wut.

Instance Applicative_ListT
  (M : Type -> Type) (inst : Monad M) : Applicative (ListT M) :=
{
    is_functor := Functor_ListT M inst;
    ret := @ret_ListT M inst;
    ap := @ap_ListT M inst;
}.
Proof.
  all: cbn; unfold ListT, fmap_ListT, ret_ListT, ap_ListT; intros;
    exts; cbn; unfold fmap_ListT; f_equal.
Defined.

Definition aempty_ListT
  (M : Type -> Type) (inst : Monad M) (A : Type) : ListT M A :=
    fun X nil cons => nil.

Definition aplus_ListT
  (M : Type -> Type) (inst : Monad M) (A : Type) (ml1 ml2 : ListT M A)
    : ListT M A := fun X nil cons => ml1 X (ml2 X nil cons) cons.

Instance Alternative_ListT
  (M : Type -> Type) (inst : Monad M) : Alternative (ListT M) :=
{
    is_applicative := Applicative_ListT M inst;
    aempty := aempty_ListT M inst;
    aplus := aplus_ListT M inst;
}.
Proof.
  all: cbn; unfold ListT, aempty_ListT, aplus_ListT; monad.
Defined.

Definition bind_ListT
  {M : Type -> Type} {inst : Monad M} {A B : Type}
  (mla : ListT M A) (f : A -> ListT M B) : ListT M B :=
    fun X nil cons => mla X nil (fun h t => f h X t cons).

Eval lazy in bind_ListT wut
  (fun n => fun X nil cons => cons (n + 1) (cons (n + 2) nil)).

Instance Monad_ListT
  (M : Type -> Type) (inst : Monad M) : Monad (ListT M) :=
{
    is_applicative := Applicative_ListT M inst;
    bind := @bind_ListT M inst
}.
Proof.
  all: cbn; unfold ListT, fmap_ListT, ret_ListT, ap_ListT, bind_ListT; monad.
  compute. all: f_equal.
Defined.

Definition lift_ListT
  {M : Type -> Type} {inst : Monad M} (A : Type) (ma : M A) : ListT M A :=
    fun X nil cons => ma >>= fun a : A => cons a nil.

Instance MonadTrans_ListT : MonadTrans ListT :=
{
    is_monad := @Monad_ListT;
    lift := @lift_ListT;
}.
Proof.
  all: cbn; intros; unfold lift_ListT, ret_ListT, bind_ListT; monad.
  cbn. unfold Identity.ret_Identity. reflexivity.
Defined.