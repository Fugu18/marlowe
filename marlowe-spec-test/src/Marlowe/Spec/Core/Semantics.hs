{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BlockArguments #-}

module Marlowe.Spec.Core.Semantics
  ( tests
  )
  where

import qualified Arith as Arith
import Control.Monad.IO.Class (MonadIO(..))
import Data.Aeson (ToJSON(..))
import qualified Data.Aeson as JSON
import Marlowe.Spec.Core.Arbitrary (genValue, genState, genEnvironment, genContract, genTransaction, arbitraryNonnegativeInteger, arbitraryValidInputs)
import Marlowe.Spec.Interpret (InterpretJsonRequest, Request (..), Response (..))
import Marlowe.Spec.Reproducible (reproducibleProperty, reproducibleProperty', generate, generateT, assertResponse)
import Test.Tasty (TestTree, testGroup)
import Test.QuickCheck (withMaxSuccess)
import Test.QuickCheck.Monadic (assert, run, monitor, pre)
import Semantics (evalValue, playTrace, computeTransaction, TransactionOutput (..), TransactionOutputRecord_ext (TransactionOutputRecord_ext), isQuiescent, TransactionWarning, txOutWarnings, reduceContractUntilQuiescent, ReduceResult (..), Transaction_ext (..))
import Timeout (isClosedAndEmpty)
import SemanticsTypes (Value(..), State_ext (..), Contract(..), minTime)
import SingleInputTransactions (traceListToSingleInput)
import QuickCheck.GenT (suchThat)
import QuickCheck.GenT (listOf)
import Test.QuickCheck.Property (counterexample)
import Marlowe.Utils (showAsJson)
import PositiveAccounts (validAndPositive_state)
import QuickCheck.GenT (listOf1)
import TransactionBound (maxTransactionsInitialState)
import Orderings (Ord(..))

tests :: InterpretJsonRequest -> TestTree
tests i = testGroup "Semantics"
    [ evalValueTest i
    , divisionRoundsTowardsZeroTest i
    -- TransactionBound.thy
    -- , playTrace_only_accepts_maxTransactionsInitialStateTest i -- FIXME: does not make sense
    -- SingleInputTransactions.thy
    , traceToSingleInputIsEquivalentTest i
    , reduceContractUntilQuiescentIdempotentTest i
    -- QuiescentResults.thy
    , computeTransactionIsQuiescentTest i
    , playTraceIsQuiescentTest i
    -- PositiveAccounts.thy
    -- playTraceAux_preserves_validAndPositive_state
    -- Timeout.thy
    , timedOutTransaction_closes_contractTest i
    -- timedOutTransaction_closes_contract2Test i
    -- timedOutTransaction_closes_contract3Test i
    -- CloseIsSafe.thy
    , closeIsSafeTest i
    ]

-- The default maxSuccess is 100 and this tests modifies that to 500 as it was empirically found that 10 out of 10 times
-- an existing bug in the purescript implementation regarding division rounding was found. With the default 100 only
-- 5 out of 10 executions of the test found the problem.
-- As with all testing, the fact that the implementation passes this property-based test doesn't guarantee that there
-- are no bugs, only that the selected arbitrary examples didn't find one.
evalValueTest :: InterpretJsonRequest -> TestTree
evalValueTest interpret = reproducibleProperty' "Eval Value" (withMaxSuccess 500) do
    env <- run $ generate $ genEnvironment
    state <- run $ generateT $ genState interpret
    value <- run $ generateT $ genValue interpret
    let
        req :: Request JSON.Value
        req = EvalValue env state value
        successResponse = RequestResponse $ toJSON $ evalValue env state value
    assertResponse interpret req successResponse

divisionRoundsTowardsZeroTest :: InterpretJsonRequest -> TestTree
divisionRoundsTowardsZeroTest interpret = reproducibleProperty "Division rounding"  do
    env <- run $ generate $ genEnvironment
    state <- run $ generateT $ genState interpret
    numerator <- run $ generateT $ genValue interpret
    denominator <- run $ generateT
        (genValue interpret
          `suchThat` (\d -> (Arith.abs_int $ evalValue env state numerator) `Arith.less_int` (Arith.abs_int $ evalValue env state d))
        )
    let
        req :: Request JSON.Value
        req = EvalValue env state (DivValue numerator denominator)
        successResponse = RequestResponse $ toJSON (0 :: Int)
    assertResponse interpret req successResponse

-- TransactionBound.thy
-- lemma playTrace_only_accepts_maxTransactionsInitialState :
--    "playTrace sl c l = TransactionOutput txOut ⟹
--      length l ≤ maxTransactionsInitialState c"
playTrace_only_accepts_maxTransactionsInitialStateTest :: InterpretJsonRequest -> TestTree
playTrace_only_accepts_maxTransactionsInitialStateTest interpret = reproducibleProperty "playTrace only accepts maxTransactionsInitialState"  do
    contract <- run $ generateT $ genContract interpret
    transactions <- run $ generateT $ listOf1 $ genTransaction interpret
    startTime <- run $ generate $ arbitraryNonnegativeInteger
    let
        req :: Request JSON.Value
        req = PlayTrace (integer_of_int startTime) contract transactions
    RequestResponse res <- run $ liftIO $ interpret req

    case JSON.fromJSON res of
      JSON.Success (TransactionOutput (TransactionOutputRecord_ext _ _ _ _ _)) -> do
        monitor
          ( counterexample $
              "Request: " ++ showAsJson req ++ "\n"
                ++ "Expected reponse to be quiescent" )
        assert $ toInteger (length transactions) <= Arith.integer_of_nat (maxTransactionsInitialState contract)
      JSON.Success _ -> pre False
      _ -> fail "JSON parsing failed!"

-- SingleInputTransactions.thy
-- theorem traceToSingleInputIsEquivalent:
--    "playTrace sn co tral = playTrace sn co (traceListToSingleInput tral)"
traceToSingleInputIsEquivalentTest :: InterpretJsonRequest -> TestTree
traceToSingleInputIsEquivalentTest interpret = reproducibleProperty "Single input transactions"  do
    contract <- run $ generateT $ genContract interpret
    transactions <- run $ generateT $ (listOf $ genTransaction interpret) `suchThat` \t -> t /= traceListToSingleInput t
    startTime <- run $ generate $ arbitraryNonnegativeInteger

    let
        multipleInputs = PlayTrace (integer_of_int startTime) contract transactions
        singletonInput = PlayTrace (integer_of_int startTime) contract (traceListToSingleInput transactions)

        multipleInputsResponse = RequestResponse $ toJSON $ playTrace startTime contract transactions
        singletonInputResponse = RequestResponse $ toJSON $ playTrace startTime contract (traceListToSingleInput transactions)

    assertResponse interpret multipleInputs multipleInputsResponse
    assertResponse interpret singletonInput singletonInputResponse

    assert $ multipleInputsResponse == singletonInputResponse

integer_of_int :: Arith.Int -> Integer
integer_of_int (Arith.Int_of_integer k) = k

-- SingleInputTransactions.thy
--
-- lemma reduceContractUntilQuiescentIdempotent :
--    "reduceContractUntilQuiescent env state contract = ContractQuiescent reducedAfter wa pa nsta ncont ⟹
--       reduceContractUntilQuiescent env nsta ncont = ContractQuiescent False [] [] nsta ncont"
reduceContractUntilQuiescentIdempotentTest :: InterpretJsonRequest -> TestTree
reduceContractUntilQuiescentIdempotentTest interpret = reproducibleProperty "reduceContractUntilQuiescent idempotent"  do
    env <- run $ generate $ genEnvironment
    state <- run $ generateT $ genState interpret
    contract <- run $ generateT $ genContract interpret

    let
        req :: Request JSON.Value
        req = ReduceContractUntilQuiescent env state contract
    RequestResponse res <- run $ liftIO $ interpret req

    case JSON.fromJSON res of
      JSON.Success (ContractQuiescent _ _ _ nsta ncont) -> do
        monitor
          ( counterexample $
              "Request: " ++ showAsJson req ++ "\n"
                ++ "Expected: ContractQuiescent" )
        assert $ case reduceContractUntilQuiescent env nsta ncont of
                   ContractQuiescent False [] [] nsta' ncont' -> nsta == nsta' && ncont == ncont'
                   _ -> False
      JSON.Success _ -> pre False
      _ -> fail "JSON parsing failed!"


-- QuiescentResults.thy
-- theorem computeTransactionIsQuiescent:
--    "validAndPositive_state sta ⟹
--      computeTransaction traIn sta cont = TransactionOutput traOut ⟹
--        isQuiescent (txOutContract traOut) (txOutState traOut)"
computeTransactionIsQuiescentTest :: InterpretJsonRequest -> TestTree
computeTransactionIsQuiescentTest interpret = reproducibleProperty "Compute transaction is quiescent" do
    contract <- run $ generateT $ genContract interpret
    state <- run $ generateT $ genState interpret `suchThat` validAndPositive_state
    transactions <- run $ generateT $ genTransaction interpret
    let
        req :: Request JSON.Value
        req = ComputeTransaction transactions state contract
    RequestResponse res <- run $ liftIO $ interpret req

    case JSON.fromJSON res of
      JSON.Success transactionOutput  -> do
        let expected = computeTransaction transactions state contract
        monitor
          ( counterexample $
              "Request: " ++ showAsJson req ++ "\n"
                ++ "Expected: " ++ show expected ++ "\n"
                ++ "Actual: " ++ show transactionOutput)
        assert $ equals transactionOutput expected
      _ -> fail "JSON parsing failed!"

  where
    equals :: TransactionOutput -> TransactionOutput -> Bool
    equals
      (TransactionOutput (TransactionOutputRecord_ext warnings1 payments1 (State_ext accounts1 choices1 boundValues1 minTime1 b1) contract1 a1))
      (TransactionOutput (TransactionOutputRecord_ext warnings2 payments2 (State_ext accounts2 choices2 boundValues2 minTime2 b2) contract2 a2)) =
        warnings1 == warnings2
        && payments1 == payments2
        && accounts1 == accounts2
        && setEquals choices1 choices2
        && setEquals boundValues1 boundValues2
        && minTime1 == minTime2
        && contract1 == contract2
        && a1 == a2
        && b1 == b2
    equals a b = a == b

    setEquals :: Eq a => [a] -> [a] -> Bool
    setEquals l1 l2 =
        all (flip elem l2) l1
        && all (flip elem l1) l2

-- QuiescentResults.thy
-- theorem playTraceIsQuiescent:
--    "playTrace sl cont (Cons h t) = TransactionOutput traOut ⟹
--      isQuiescent (txOutContract traOut) (txOutState traOut)"
playTraceIsQuiescentTest :: InterpretJsonRequest -> TestTree
playTraceIsQuiescentTest interpret = reproducibleProperty "playTrace is quiescent" do
    contract <- run $ generateT $ genContract interpret `suchThat` (/=Close)
    startTime <- run $ generate $ arbitraryNonnegativeInteger
    transactions <- run $ generate $ arbitraryValidInputs (State_ext [] [] [] startTime ()) contract `suchThat` ((>0) . length)
    let
        req :: Request JSON.Value
        req = PlayTrace (integer_of_int startTime) contract transactions
    RequestResponse res <- run $ liftIO $ interpret req

    case JSON.fromJSON res of
      JSON.Success (TransactionOutput (TransactionOutputRecord_ext _ _ txOutState txOutContract _)) -> do
        monitor
          ( counterexample $
              "Request: " ++ showAsJson req ++ "\n"
                ++ "Expected reponse to be quiescent" )
        assert $ isQuiescent txOutContract txOutState
      JSON.Success _ -> pre False
      _ -> fail "JSON parsing failed!"

-- Timeout.thy
-- theorem timedOutTransaction_closes_contract:
--    "validAndPositive_state sta
--       ⟹  iniTime ≥ minTime sta
--       ⟹  iniTime ≥ maxTimeContract cont
--       ⟹  endTime ≥ iniTime
--       ⟹  accounts sta ≠ [] ∨ cont ≠ Close
--       ⟹  isClosedAndEmpty (computeTransaction ⦇ interval = (iniTime, endTime)
--                                               , inputs = [] ⦈ sta cont)"
timedOutTransaction_closes_contractTest :: InterpretJsonRequest -> TestTree
timedOutTransaction_closes_contractTest interpret = reproducibleProperty "Timed-out transaction closes contract"  do
  state <- run $ generateT $ genState interpret `suchThat` validAndPositive_state
  txIn <- run $ generateT $ genTransaction interpret `suchThat` \(Transaction_ext (_,upper) _ _) -> less_eq (minTime state) upper
  let req :: Request JSON.Value
      req = ComputeTransaction txIn state Close

  RequestResponse res <- run $ liftIO $ interpret req

  case JSON.fromJSON res of
    JSON.Success txOut@(TransactionOutput trec) -> do
      let expected :: [TransactionWarning]
          expected = mempty
      monitor
        ( counterexample $
            "Request: " ++ showAsJson req ++ "\n"
              ++ "Expected: " ++ show expected ++ "\n"
              ++ "Actual: " ++ show (txOutWarnings trec))
      assert $ isClosedAndEmpty txOut
    JSON.Success _ -> pre False
    _ -> fail "JSON parsing failed!"

-- CloseIsSafe.thy
-- theorem closeIsSafe :
--    "computeTransaction tra sta Close = TransactionOutput trec ⟹  txOutWarnings trec = []"
closeIsSafeTest :: InterpretJsonRequest -> TestTree
closeIsSafeTest interpret = reproducibleProperty "Close is safe" do
  state <- run $ generateT $ genState interpret
  txIn <- run $ generateT $ genTransaction interpret `suchThat` \(Transaction_ext (_,upper) _ _) -> less_eq (minTime state) upper
  let req :: Request JSON.Value
      req = ComputeTransaction txIn state Close

  RequestResponse res <- run $ liftIO $ interpret req

  case JSON.fromJSON res of
    JSON.Success (TransactionOutput trec) -> do
      let expected :: [TransactionWarning]
          expected = mempty
      monitor
        ( counterexample $
            "Request: " ++ showAsJson req ++ "\n"
              ++ "Expected: " ++ show expected ++ "\n"
              ++ "Actual: " ++ show (txOutWarnings trec))
      assert (txOutWarnings trec == expected)
    JSON.Success _ -> pre False
    _ -> fail "JSON parsing failed!"
