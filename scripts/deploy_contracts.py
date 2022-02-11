from operator import ne
from brownie import (
    accounts,
    SuperDeposit,
    DepositKeeper,
    network,
    config,
    convert,
    interface,
    DataGiver,
    TestKeeper
)
from brownie.network.gas.strategies import GasNowStrategy
from brownie.network import web3

network.max_fee("10 gwei")
network.priority_fee("2 gwei")

#acc = accounts.load("0")

host = convert.to_address("0x22ff293e14F1EC3A09B137e9e06084AFd63adDF9")
cfa = convert.to_address("0xEd6BcbF6907D4feEEe8a8875543249bEa9D308E8")

host_mumbai = convert.to_address("0xEB796bdb90fFA0f28255275e16936D25d3418603")
cfa_mumbai = convert.to_address("0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873")

host_kovan = convert.to_address("0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3")
cfa_kovan = convert.to_address("0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F")

Dai_mumbai = convert.to_address("0x001b3b4d0f3714ca98ba10f6042daebf0b1b7b6f")
DaiX_mumbai = convert.to_address("0x06577b0B09e69148A45b866a0dE6643b6caC40Af")

daikovan = convert.to_address("0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD")
daixkovan = convert.to_address("0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09")

acount = accounts.add(config["wallets"]["from_dep"])

def deployment_path():
    print("deploying contracts contract...")
    deposit_contract = (
        SuperDeposit.deploy(
            cfa_kovan,
            daixkovan,
            daikovan,
            {"from": acount}
            #publish_source=True
        )
        if len(SuperDeposit) <= 0
        else SuperDeposit[-1]
    )
    print("super contract deployed at: ")
    deposit_address = deposit_contract.address
    print(deposit_address)
    print("deploying contract 2...")
    keeper_contract = (
        TestKeeper.deploy(
            deposit_address,
            {"from": acount},
            #publish_source=True
        )
        if len(TestKeeper) <= 0
        else TestKeeper[-1]
    )
    keeper_address = keeper_contract.address
    print(keeper_address)

    print("deploying contract 2...")
    data_contract = (
        DataGiver.deploy(
            host_kovan,
            cfa_kovan,
            {"from": acount}
        )
        if len(DataGiver) <= 0
        else DataGiver[-1]
    )

    #deposit_contract.addAcceptedToken(
    #    daixkovan,
    #    "DAI",
    #    daikovan,
    #    {"from": acount}
    #)
    
    assert(deposit_contract.keeperContract() == keeper_address)

    daix = interface.ISuperToken(daixkovan)
    dai = interface.IERC20(daikovan)

    #print("approving dai upgrade")
    #dai.approve(
    #    daikovan,
    #    2000000000000000000000,
    #    {"from": acount}
    #)
    print("upgrading...")
    amount = dai.allowance(acount, daikovan)
    print(amount)
    #daix.upgrade(amount, {"from": acount})

    CFA = interface.IConstantFlowAgreementV1(cfa_kovan)
    #nft_contract = interface.ITreeBudgetNFT("")
    _host = interface.ISuperfluid(host_kovan)

    print("creating flow...")
    def create_flow():
        cfaContext = data_contract.getEncoding(
            convert.to_int("0.25 ether"),
            daixkovan,
            deposit_address
        )
        return _host.callAgreement(
            cfa_kovan,#cfa addressl
            cfaContext,
            "",#user data
            {"from": acount}
        )
    create_flow()

    print("getting cfa to contract from account..")
    print(
        CFA.getFlow(
            daixkovan,
            acount,
            deposit_address
        )
    )
    print("adding user frequency for flow...")
    deposit_contract.addFreequency(3590, {"from": acount})

def main():
    deployment_path()

if __name__ == "__main__()":
    main()
