(*<*)
theory Specification
  imports 
      Main  
      "HOL-Library.LaTeXsugar" 
      Core.SemanticsTypes 
      Core.MoneyPreservation 
      Core.QuiescentResult
      Core.SingleInputTransactions
      Core.Timeout
      Core.TransactionBound

begin                                                     
(*>*)

chapter \<open>Marlowe\<close>

section \<open>Introduction\<close>

text \<open>TODO: small introduction on Marlowe\<close>
text \<open>TODO: description of each chapter\<close>

section \<open>The Marlowe Model\<close>
text \<open>TODO: Add parts of the section "The Marlowe Model" from the
2019 paper that helps introduce Marlowe. 
The paper starts describing some of the data types, in here I would 
point to the Marlowe Core Data Types instead with more in depth description

I would also add a Note of internal accounts here.

\<close>

chapter \<open>Marlowe Core\<close>

section \<open>Types\<close>

text \<open>Contract type\<close>
text \<open>@{datatype [display,names_short, margin=40]Contract}\<close>

text \<open>Value\<close>
text \<open>@{datatype [display,names_short, margin=40]Value}\<close>

text \<open>Input\<close>
text \<open>@{datatype [display,names_short, margin=40]Input}\<close>

text \<open>State\<close>
(* Sadly there is no antiquote to print a record, and I wasn't able to 
make the snipet import work (described in chapter 7 of the Sugar Latex PDF).
So to show records we need to duplicate the definition
 *)
record State = accounts :: Accounts
               choices :: "(ChoiceId \<times> ChosenNum) list"
               boundValues :: "(ValueId \<times> int) list"
               minSlot :: Slot



section \<open>Semantics\<close>

text \<open>TODO: Add the different functions and explanation \<close>


subsection \<open>Eval value\<close>
text \<open>TODO: explain\<close>
text \<open>TODO: Special note on semantics of division\<close>

text \<open>@{code_stmts evalValue constant: evalValue (Haskell)}\<close>

text \<open>Instead of haskell code we might want to add the general type and
then subsubsection for each case\<close>

text \<open>\<^emph>\<open>evalValue\<close> :: @{typeof evalValue}\<close>

subsubsection \<open>Addition\<close>

text \<open>@{thm evalValue.simps(4)}\<close>
text \<open>TODO: add name to the case so we don't rely on the number evalValue\_Add or similar\<close>
text \<open>TODO: Lemmas about adition. Distributive, commutative, a - a = 0\<close>
text \<open>@{thm evalNegValue}\<close>

subsection \<open>Eval observation\<close>
text \<open>TODO: explain\<close>
text \<open>@{code_stmts evalObservation constant: evalObservation (Haskell)}\<close>

subsection \<open>Reduction loop\label{sec:reductionloop}\<close>

text \<open>TODO: explain\<close>
text \<open>@{code_stmts reductionLoop constant: reductionLoop (Haskell)}\<close>

subsection \<open>reduceContractUntilQuiescent\label{sec:reduceContractUntilQuiescent}\<close>

text \<open>TODO: explain\<close>
text \<open>@{code_stmts reduceContractUntilQuiescent constant: reduceContractUntilQuiescent (Haskell)}\<close>

subsection \<open>Apply all inputs\label{sec:applyAllInputs}\<close>
text \<open>TODO: explain\<close>
text \<open>@{code_stmts applyAllInputs constant: applyAllInputs (Haskell)}\<close>

subsection \<open>Compute Transaction\label{sec:computeTransaction}\<close>
text \<open>TODO: explain\<close>
text \<open>@{code_stmts computeTransaction constant: computeTransaction (Haskell)}\<close>

subsection \<open>Play Trace\label{sec:playTrace}\<close>
text \<open>TODO: explain\<close>
text \<open>@{code_stmts playTrace constant: playTrace (Haskell)}\<close>

subsection \<open>Max time\<close>
text \<open>TODO: explain\<close>
text \<open>@{code_stmts maxTimeContract constant: maxTimeContract (Haskell)}\<close>

subsection \<open>Fix interval\<close>
text \<open>TODO: explain\<close>
text \<open>@{code_stmts fixInterval constant: fixInterval (Haskell)}\<close>



chapter \<open>Marlowe Extended\<close>
text \<open>TODO: what is extended and why it exists\<close> 



section \<open>Types\<close>
text \<open>TODO: Mostly the difference with Core\<close>

section \<open>Conversion to Core\<close>
text \<open>TODO: conversion to core\<close> 


chapter \<open>Serialization\<close>
text \<open>TODO: Json and CBOR serialization of both Core and Extended in one chapter with the differences?
or one Serialization section per each chapter?\<close>


chapter \<open>Textual representation\<close>
text \<open>TODO: Rail diagram of the Marlowe Grammar\<close>

chapter \<open>Static Analysis\<close>
text \<open>TODO: Static analysis in the specification or as something external?\<close>



chapter \<open>Marlowe guarantees\<close>
text \<open>TODO: add human readable version of the important theorems and lemmas\<close>

section \<open>Money Preservation\<close>
text \<open>TODO: Money preservation\<close>
text \<open>@{thm playTrace_preserves_money}\<close>

section \<open>Positive accounts\<close>
text \<open>TODO: Positive accounts\<close>
text \<open>@{thm playTraceAux_preserves_validAndPositive_state}\<close>

section \<open>Quiescent result\<close>
text \<open>TODO: definition of Quiescent\<close>
text
\<open>
The following always produce quiescent contracts:
\<^item> reductionLoop \secref{sec:reductionloop}
\<^item> reduceContractUntilQuiescent \secref{sec:reduceContractUntilQuiescent}
\<^item> applyAllInputs  \secref{sec:applyAllInputs}
\<^item> computeTransaction  \secref{sec:computeTransaction}
\<^item> playTrace  \secref{sec:playTrace} 
\<close>

text \<open>@{thm playTraceIsQuiescent}\<close>
text \<open>TODO: explanation of theorem\<close>

section \<open>reduceContractUntilQuiescent is idempotent\<close>
text \<open>TODO: explain\<close>
text \<open>@{thm reduceContractUntilQuiescentIdempotent }\<close>

section \<open>Split transactions into single input does not affect the result\<close>
text \<open>TODO: explain\<close>
text \<open>@{thm playTraceAuxToSingleInputIsEquivalent }\<close>


section \<open>Contracts always close\<close>

text \<open>TODO: proofs around contracts always close and Funds are not held after it close\<close>
(* Do we have or need a lemma that accounts are empty after close? *)

subsection \<open>Termination Proof\<close>
text \<open>TODO: adapt text from section 5.1 "Termination proof" from the 
2019 paper.\<close>

subsection \<open>All contracts have a maximum time\<close>
text \<open>If we send an empty transaction with time equal to maxTimeContract, the contract will close\<close>
text \<open>TODO: explain\<close>
text \<open>@{thm [mode=Rule,names_short] timedOutTransaction_closes_contract}\<close>

subsection \<open>Contract does not hold funds after it closes\<close>
text \<open>TODO: Funds are not held after it close\<close>

subsection \<open>Transaction bound\<close>
text \<open>There is a maximum number of transaction that can be accepted by a contract\<close>

(* should we have a maxTransactions :: Contract \<Rightarrow> Int in the semantics? *)
text \<open>@{thm playTrace_only_accepts_maxTransactionsInitialState}\<close>


(*<*)
end
(*>*)