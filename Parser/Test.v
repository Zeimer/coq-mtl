Require Import Arith.

From CoqMTL Require Export Control.Monad.
From CoqMTL Require Export Control.Monad.All.

(** Helper functions which produce lists of natural numbers. *)

Fixpoint aux (n k : nat) : list nat :=
match n with
    | 0 => [k]
    | S n' => k :: aux n' (S k)
end.

Definition I (a b : nat) : list nat := aux (b - a) a.

(** Tests for [Applicative]. *)
From CoqMTL Require Export Control.Applicative.

(*
Compute zipWithA
  (fun _ _ => [true; false]) [1; 2; 3] [4; 5; 6; 7].
*)

(** Tests for [Alternative]: compute some Pythagorean triples. *)
From CoqMTL Require Export Control.Alternative.

(*
Compute do
  a <- I 1 25;
  b <- I 1 25;
  c <- I 1 25;
  guard (Nat.eqb (a * a + b * b) (c * c));;
  pure (a, b, c).
*)

(** Tests for [Foldable]. TODO: commented out. *)
From CoqMTL Require Import Control.Foldable.

(*
Compute isEmpty (None).
Compute size (Some 42).
Compute toListF (Some 5).
Compute elem Nat.eqb 2 (Some 2).
Compute maxF (Some 42).

Compute size (inr 5).
Compute maxF [1; 2; 3].
Compute findFirst (Nat.eqb 42) [1; 3; 5; 7; 11; 42].
Compute count (leb 10) [1; 3; 5; 7; 11; 42].
*)

(** Tests for parsers. Toggle between imports for Parser.Parser and
    Parser.Parser_ListT to test one of these. *)

From CoqMTL Require Import Parser.Parser.
(* From CoqMTL Require Import Parser.Parser_ListT. *)

(**
    expr    ::= expr addop factor | factor
    addop   ::= + | -
    factor  ::= nat | ( expr )
*)

Fixpoint exprn (n : nat) : Parser Z :=
match n with
    | 0 => aempty
    | S n' =>
        let
          addop := char "+" >> pure Z.add <|>
                   char "-" >> pure Z.sub
        in let
          factor := parseZ <|>
                    bracket (char "(") (exprn n') (char ")")
        in
          liftA3 (fun x op y => op x y) (exprn n') addop factor <|>
          factor
end.

Definition expr : Parser Z :=
  fun input : string => exprn (String.length input) input.

(*
Compute expr "2+2".
Compute expr "0-5)".
*)

(** The same grammar as above. *)
Fixpoint exprn2 (n : nat) : Parser Z :=
match n with
    | 0 => aempty
    | S n' =>
        let
          op := char "+" >> pure Z.add <|>
                char "-" >> pure Z.sub
        in let
          factor := parseZ <|> bracket (char "(") (exprn2 n') (char ")")
        in
          chainl1 factor op
end.

Definition expr2 : Parser Z :=
  fun input : string => exprn2 (String.length input) input.

(*
Compute expr2 "3-2"%string.
*)

(** Still the same grammar. *)
Fixpoint exprn3 (n : nat) : Parser Z :=
match n with
    | 0 => aempty
    | S n' =>
        let
          op := ops (char "+", Z.add) [(char "-", Z.sub)]
        in let
          factor := parseZ <|> bracket (char "(") (exprn3 n') (char ")")
        in
          chainl1 factor op
end.

Definition expr3 : Parser Z :=
  fun input : string => exprn3 (String.length input) input.

(*
Compute expr3 "1-(2-(3-4)-5)"%string.
*)

(** Nearly as before, but augmented with "^" for exponentiation. *)
Fixpoint exprn4 (n : nat) : Parser Z :=
match n with
    | 0 => aempty
    | S n' =>
        let
          addop := ops (char "+", Z.add) [(char "-", Z.sub)]
        in let
          expop := ops (char "^", Z.pow) []
        in let
          factor := parseZ <|> bracket (char "(") (exprn4 n') (char ")")
        in let
          term := chainr1 factor expop
        in
          chainl1 term addop
end.

Definition expr4 : Parser Z :=
  fun input : string => exprn4 (String.length input) input.

(*Compute expr4 "(1-2)^3".*)

Inductive Expr : Type :=
    | App : Expr -> Expr -> Expr
    | Lam : string -> Expr -> Expr
    | Let : string -> Expr -> Expr -> Expr
    | Var : string -> Expr.

(** Parser for lambda calculus with let using Coq-like syntax. *)
Fixpoint parseExprn (n : nat) : Parser Expr :=
match n with
    | 0 => aempty
    | S n' =>
        let
          id := identifier ["let"; "fun"; "in"]%string
        in let
          app := do
            token $ char "(";;
            e1 <- parseExprn n';
            e2 <- parseExprn n';
            token $ char ")";;
            pure $ App e1 e2
        in let
          lam := do
            token $ str "fun";;
            var <- id;
            token $ str "=>";;
            body <- parseExprn n';
            pure $ Lam var body
        in let
          parseLet := do
            token $ str "let";;
            var <- id;
            token $ str ":=";;
            body <- parseExprn n';
            token $ str "in";;
            let_body <- parseExprn n';
            pure $ Let var body let_body
        in let
          var := fmap Var id
        in
          app +++ lam +++ parseLet +++ var
end.

Definition parseExpr : Parser Expr :=
  fun input : string => parseExprn (String.length input) input.

(*
Time Compute parseExpr "(x x)".
Time Compute parseExpr "fun f => fun x => (f x)".
Time Compute parseExpr "let x := (x x) in x".
*)

(** Parser for lambda calculus with let using Haskell-like syntax. *)
Fixpoint parseExprn' (n : nat) : Parser Expr :=
match n with
    | 0 => aempty
    | S n' =>
        let
          variable := identifier ["let"; "in"]%string
        in let
          paren := bracket (char "(") (parseExprn' n') (char ")")
        in let
          var := fmap Var variable
        in let
          local := do
            symbol "let";;
            x <- variable;
            symbol "=";;
            e <- parseExprn' n';
            symbol "in";;
            e' <- parseExprn' n';
            pure $ Let x e e'
        in let
          lam := do
            symbol "\";;
            x <- variable;
            symbol "->";;
            e <- parseExprn' n';
            pure $ Lam x e
        in let
          atom := token (lam +++ local +++ var +++ paren)
        in
          chainl1 atom (pure App)
end.

Definition parseExpr' : Parser Expr :=
  fun input : string => parseExprn' (String.length input) input.

(*
Time Compute parseExpr' "(x x)".
Time Compute parseExpr' "\f -> \x -> (f x)".
Time Compute parseExpr' "let x = (x x) in x".
*)