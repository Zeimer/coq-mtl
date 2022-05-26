Require Import Control.All.
Require Import Control.Monad.Trans.
Require Import Control.Monad.Class.All.
Require Import Control.Monad.Identity.

Require Import Misc.Monoid.

(** A transformer which adds the ability to perform logging to the base
    monad [M]. *)
Definition WriterT (W : Monoid) (M : Type -> Type) (A : Type)
  : Type := M (A * W)%type.

(** Definitions of [fmap], [pure], [ap], [bind], [aempty], [aplus] are
    similar to these for [Writer], but we have to insert [M]'s [bind]s
    and [pure]s in the right places. *)

Definition fmap_WriterT
  {W : Monoid} {M : Type -> Type} {inst : Monad M} {A B : Type} (f : A -> B)
  (x : WriterT W M A) : WriterT W M B :=
    fmap (fun '(a, w) => (f a, w)) x.

#[global] Hint Unfold WriterT fmap_WriterT : CoqMTL.

#[refine]
#[export]
Instance Functor_WriterT
  (W : Monoid) {M : Type -> Type} {inst : Monad M} : Functor (WriterT W M) :=
{
    fmap := @fmap_WriterT W M inst
}.
Proof. all: unfold compose; monad. Defined.

Definition pure_WriterT
  {W : Monoid} {M : Type -> Type} {inst : Monad M} {A : Type} (x : A)
    : WriterT W M A := pure (x, neutr).

Definition ap_WriterT
  (W : Monoid) (M : Type -> Type) (inst : Monad M) (A B : Type)
  (mf : WriterT W M (A -> B)) (mx : WriterT W M A) : WriterT W M B :=
    @bind M inst _ _ mf (fun '(f, w) =>
    @bind M inst _ _ mx (fun '(x, w') =>
      pure (f x, op w w'))).

#[global] Hint Unfold pure_WriterT ap_WriterT : CoqMTL.

#[refine]
#[export]
Instance Applicative_WriterT
  (W : Monoid) (M : Type -> Type) (inst : Monad M)
  : Applicative (WriterT W M) :=
{
    is_functor := @Functor_WriterT W M inst;
    pure := @pure_WriterT W M inst;
    ap := @ap_WriterT W M inst;
}.
Proof. all: monad. Defined.

(** [WriterT M] is [Alternative] only when [M] is. *)

Lemma WriterT_not_Alternative :
  (forall (W : Monoid) (M : Type -> Type) (inst : Monad M),
    Alternative (WriterT W M)) -> False.
Proof.
  intros. assert (W : Monoid).
    refine {| carr := unit; neutr := tt; op := fun _ _ => tt |}.
      1-3: try destruct x; reflexivity.
    destruct (X W Identity Monad_Identity).
    clear -aempty. specialize (aempty False).
    compute in aempty. destruct aempty. assumption.
Qed.

#[refine]
#[export]
Instance Alternative_WriterT
  (W : Monoid) (M : Type -> Type) (inst : Monad M) (inst' : Alternative M)
  : Alternative (WriterT W M) :=
{
    is_applicative := Applicative_WriterT W M inst;
    aempty A := fmap (fun a => (a, neutr)) aempty;
    aplus A x y := @aplus M inst' _ x y;
}.
Proof. all: monad. Abort.

Definition bind_WriterT
  {W : Monoid} {M : Type -> Type} {inst : Monad M} {A B : Type}
  (x : WriterT W M A) (f : A -> WriterT W M B) : WriterT W M B :=
    @bind M inst _ _ x (fun '(a, w) =>
    @bind M inst _ _ (f a) (fun '(b, w') =>
      pure (b, op w w'))).

#[global] Hint Unfold bind_WriterT : CoqMTL.

#[refine]
#[export]
Instance Monad_WriterT
  (W : Monoid) (M : Type -> Type) (inst : Monad M) : Monad (WriterT W M) :=
{
    is_applicative := @Applicative_WriterT W M inst;
    bind := @bind_WriterT W M inst;
}.
Proof. all: monad. Defined.

(** We can lift a computation into the monad just by not doing any logging
    at all. *)
Definition lift_WriterT
  (W : Monoid) {M : Type -> Type} {inst : Monad M} {A : Type} (ma : M A)
    : WriterT W M A := fmap (fun x : A => (x, neutr)) ma.

#[global] Hint Unfold lift_WriterT : CoqMTL.

#[refine]
#[export]
Instance MonadTrans_WriterT (W : Monoid) : MonadTrans (WriterT W) :=
{
    is_monad := @Monad_WriterT W;
    lift := @lift_WriterT W;
}.
Proof. all: unfold compose; monad. Defined.

(** [WriterT] adds a layer of [MonadWriter] on top of the base monad [M]. *)
#[refine]
#[export]
Instance MonadWriter_WriterT
  (W : Monoid) (M : Type -> Type) (inst : Monad M)
  : MonadWriter W (WriterT W M) (Monad_WriterT W M inst) :=
{
    tell := fun w => pure (tt, w);
    listen :=
      fun A (ma : M (A * W)%type) =>
        ma >>= fun '(a, w) => pure ((a, w), neutr);
}.
Proof. all: monad. Defined.

(** [WriterT] preserves all other kinds of monads. *)

#[refine]
#[export]
Instance MonadAlt_WriterT
  (W : Monoid) (M : Type -> Type) (inst : Monad M) (inst' : MonadAlt M inst)
  : MonadAlt (WriterT W M) (Monad_WriterT W M inst) :=
{
    choose := fun A x y => @choose M inst inst' (A * W) x y
}.
Proof. all: monad. Defined.

#[refine]
#[export]
Instance MonadFail_WriterT
  (W : Monoid) (M : Type -> Type) (inst : Monad M) (inst' : MonadFail M inst)
  : MonadFail (WriterT W M) (Monad_WriterT W M inst) :=
{
    fail := fun A => @fail M inst inst' (A * W)
}.
Proof. monad. Defined.

#[refine]
#[export]
Instance MonadNondet_WriterT
  (W : Monoid) (M : Type -> Type)
  (inst : Monad M) (inst' : MonadNondet M inst)
  : MonadNondet (WriterT W M) (Monad_WriterT W M inst) :=
{
    instF := @MonadFail_WriterT W M inst (@instF _ _ inst');
    instA := @MonadAlt_WriterT W M inst (@instA _ _ inst');
}.
Proof. all: monad. Defined.

#[refine]
#[export]
Instance MonadExcept_WriterT
  (W : Monoid) (M : Type -> Type)
  (inst : Monad M) (inst' : MonadExcept M inst)
  : MonadExcept (WriterT W M) (Monad_WriterT W M inst) :=
{
    instF := @MonadFail_WriterT W M inst inst';
    catch := fun A x y => @catch M inst _ _ x y;
}.
Proof. all: monad. Defined.

#[refine]
#[export]
Instance MonadReader_WriterT
  (W : Monoid) (E : Type) (M : Type -> Type)
  (inst : Monad M) (inst' : MonadReader E M inst)
  : MonadReader E (WriterT W M) (Monad_WriterT W M inst) :=
{
    ask := ask >>= fun e => pure (e, neutr)
}.
Proof.
  rewrite <- ask_ask at 3.
  rewrite !constrA_spec.
  monad.
Defined.

#[refine]
#[export]
Instance MonadState_WriterT
  (W : Monoid) (S : Type) (M : Type -> Type)
  (inst : Monad M) (inst' : MonadState S M inst)
  : MonadState S (WriterT W M) (Monad_WriterT W M inst) :=
{
    get := get >>= fun s => pure (s, neutr);
    put := fun s => put s >> pure (tt, neutr);
}.
Proof.
  intros. cbn. unfold ap_WriterT, fmap_WriterT. monad.
  intro. cbn. unfold ap_WriterT, fmap_WriterT, pure_WriterT, const, id.
    rewrite !bind_fmap. unfold compose.
    rewrite <- !constrA_bind_assoc, !bind_pure_l.
    rewrite 2!constrA_bind_assoc. rewrite put_get.
    rewrite <- 2!constrA_bind_assoc. rewrite !bind_pure_l.
    reflexivity.
  cbn. unfold bind_WriterT, pure_WriterT.
    rewrite bind_assoc.
    replace (pure (tt, @neutr W))
       with (fmap (fun u => (u, @neutr W)) (@pure M inst _ tt))
    by hs.
    rewrite <- get_put at 1. rewrite fmap_bind. f_equal. monad.
  intros. cbn. unfold bind_WriterT. rewrite !bind_assoc.
    do 2 match goal with
        | |- context [fun s : S => pure (s, ?x) >>= ?f] =>
            replace (fun s : S => pure (s, x) >>= f)
               with (fun s : S => f (s, x)) by monad
    end.
    rewrite <- !bind_assoc, <- get_get, !bind_assoc.
    f_equal. ext s. monad.
Defined.

#[refine]
#[export]
Instance MonadStateNondet_WriterT
  (W : Monoid) (S : Type) (M : Type -> Type)
  (inst : Monad M) (inst' : MonadStateNondet S M inst)
  : MonadStateNondet S (WriterT W M) (Monad_WriterT W M inst) :=
{
    instS := MonadState_WriterT W S M inst inst';
    instN := MonadNondet_WriterT W M inst inst';
}.
Proof.
  intros. rewrite constrA_spec. cbn.
    unfold bind_WriterT.
    rewrite <- (@seq_fail_r S M inst inst' _ _ x) at 1.
    rewrite constrA_spec. f_equal. monad.
  intros. cbn. unfold bind_WriterT.
    rewrite <- bind_choose_r. f_equal.
    ext aw. destruct aw as [a w]. apply bind_choose_l.
Defined.

(** If [M] is the free monad of [F], so is [WriterT W M]. *)
#[refine]
#[export]
Instance MonadFree_WriterT
  (F : Type -> Type) (instF : Functor F)
  (W : Monoid) (M : Type -> Type)
  (instM : Monad M) (instMF : MonadFree F M instF instM)
  : MonadFree F (WriterT W M) instF (Monad_WriterT W M instM) :=
{
    wrap := fun A m => @wrap F M instF instM instMF _ m
}.
Proof.
  intros. cbn. unfold bind_WriterT, pure_WriterT, WriterT in *.
  rewrite wrap_law.
  rewrite (wrap_law _ _ (fun a : A => pure (a, neutr)) x).
  monad.
Defined.