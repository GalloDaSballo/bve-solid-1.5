import brownie
from brownie import *
from helpers.constants import MaxUint256
from helpers.SnapshotManager import SnapshotManager
from helpers.time import days

"""
  TODO: Put your tests here to prove the strat is good!
  See test_harvest_flow, for the basic tests
  See test_strategy_permissions, for tests at the permissions level
"""


def test_my_custom_test(setup_strat):
  initial_pool_balance = setup_strat.balanceOfPool()
  
  assert initial_pool_balance > 0 ##  Setup deposited so we have non zero

  ## Claim Distribution
  setup_strat.claimDistribution()

  ## Harvest means we increased balance
  assert setup_strat.balanceOfPool() > initial_pool_balance


  ## Check balanceOfRewards is non zero

  ## Claim rewards

  ## Vote

  ## Wait another week

  ## Check rewards can be claimed in gauge as well
  assert False