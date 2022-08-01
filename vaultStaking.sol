// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "./Ownable.sol";
import "./TransferHelper.sol";
import "./IERC20.sol";
import "hardhat/console.sol";

contract VaultStaking is Ownable {
    address USDTtokenaddress;
    address CHBtokenaddress;

    uint256 numberOfVault;

    mapping(address => bool) vaultUserMapping;

    struct VaultStruct {
        uint256 VaultBalance;
        address vaultOwner;
        uint256 MaturityTimePeriod;
        uint256 penaltyPercentage;
        uint256 APYpercentage;
        uint256 MinUSDTrequired;
        uint256 MaxUSDTstakedInVault;
    }

    struct UserDetails {
        uint256 stakeAmount;
        uint256 stakeTimeStamp;
        bool isStaked;
    }

    mapping(address => mapping(uint256 => UserDetails)) public userMapping;
    mapping(uint256 => VaultStruct) public vaultID;

    constructor(address _USDTtokenaddress, address _CHBtokenaddress) {
        USDTtokenaddress = _USDTtokenaddress;
        CHBtokenaddress = _CHBtokenaddress;
    }

    function createVault(
        uint256 _MaturityTimePeriod,
        uint256 _penaltyPercentage,
        uint256 _APYPercentage,
        uint256 _MinUSDTrequired,
        uint256 _MaxUSDTstakedInVault
    ) public returns (bool success) {
        require(!vaultUserMapping[msg.sender], "User can create vault once");
        VaultStruct storage vaults = vaultID[++numberOfVault];

        vaults.vaultOwner = msg.sender;
        vaults.MaturityTimePeriod = _MaturityTimePeriod;
        vaults.penaltyPercentage = _penaltyPercentage;
        vaults.APYpercentage = _APYPercentage;
        vaults.MinUSDTrequired = _MinUSDTrequired;
        vaults.MaxUSDTstakedInVault = _MaxUSDTstakedInVault;

        vaultUserMapping[msg.sender] = true;

        return true;
    }

    function stakeUSDT(uint256 _stakeAmount, uint256 _vaultId)
        public
        returns (bool success)
    {
        require(_stakeAmount > 0, "Stake amount should be greater than 0");
        require(Token(USDTtokenaddress).balanceOf(msg.sender) >= _stakeAmount);
        require(
            Token(USDTtokenaddress).allowance(msg.sender, address(this)) >=
                _stakeAmount
        );
        require(
            _stakeAmount <= vaultID[_vaultId].MaxUSDTstakedInVault,
            "Max. staked amount in vault exceeded"
        );

        require(
            vaultID[_vaultId].MinUSDTrequired < _stakeAmount,
            "Stake Amount is less"
        );

        UserDetails storage udetails = userMapping[msg.sender][_vaultId];

        udetails.stakeAmount = _stakeAmount;
        TransferHelper.safeTransferFrom(
            USDTtokenaddress,
            msg.sender,
            address(this),
            _stakeAmount
        );

        vaultID[_vaultId].VaultBalance += _stakeAmount;
        udetails.isStaked = true;

        udetails.stakeTimeStamp = block.timestamp;

        return true;
    }

    function unstakeUSDT(uint256 _vaultId) public returns (bool success) {
        UserDetails storage udetailsnew = userMapping[msg.sender][_vaultId];

        require(udetailsnew.isStaked, "User has not staked yet");

        if (
            block.timestamp >=
            udetailsnew.stakeTimeStamp + vaultID[_vaultId].MaturityTimePeriod
        ) {
            uint userRewards = ((99 * 100 * calculateRewardTokens(_vaultId)) / 10000);
            uint ownerRewards = (calculateRewardTokens(_vaultId) * 1 * 100) / 10000;
            
            TransferHelper.safeTransfer(
                USDTtokenaddress,
                msg.sender,
                udetailsnew.stakeAmount
            );
            console.log(udetailsnew.stakeAmount, "stake amount");
            console.log( userRewards, "reward tokens");

            TransferHelper.safeTransfer(
                CHBtokenaddress,
                msg.sender,
                userRewards
            );
            console.log( userRewards, "reward tokens");
            

            console.log(ownerRewards, "Reward tokens for owner");

            TransferHelper.safeTransfer(
                CHBtokenaddress,
                vaultID[_vaultId].vaultOwner,
                ownerRewards
            );
        } else {
            uint256 penalty = (vaultID[_vaultId].penaltyPercentage *
                udetailsnew.stakeAmount * 100) / 10000;
            TransferHelper.safeTransfer(USDTtokenaddress, owner, penalty);
            TransferHelper.safeTransfer(
                USDTtokenaddress,
                msg.sender,
                (udetailsnew.stakeAmount - penalty)
            );
        }
        vaultID[_vaultId].VaultBalance -= udetailsnew.stakeAmount;

        udetailsnew.isStaked = false;
        return true;
    }

    function calculateRewardTokens(uint256 _vaultId)
        internal
        view
        returns (uint256)
    {
        UserDetails memory udetailsnew3 = userMapping[msg.sender][_vaultId];
        uint256 rewards = (vaultID[_vaultId].APYpercentage *
            udetailsnew3.stakeAmount *
            vaultID[_vaultId].MaturityTimePeriod * 100) / 10000 * 60;

        if (
            block.timestamp - udetailsnew3.stakeTimeStamp <
            vaultID[_vaultId].MaturityTimePeriod
        ) {
            rewards = 0;
        }

        return rewards;
    }
}
