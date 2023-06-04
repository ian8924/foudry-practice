// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

//comptroller
import "../contracts/Unitroller.sol";
import "../contracts/Comptroller.sol";
// cToken
import "../contracts/CErc20Delegator.sol";
import "../contracts/CErc20Delegate.sol";
import "../contracts/CToken.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
//interestModel
import "../contracts/WhitePaperInterestRateModel.sol";
//priceOracle
import "../contracts/SimplePriceOracle.sol";

contract MyScript is Script {

    function run() external {
        uint256 privateKey = vm.envUint("key");
        vm.startBroadcast(privateKey);

        // set underlyingToken
        ERC20 underlyingToken = new ERC20("Test Token", "TT");
        
        // set oracle
        SimplePriceOracle priceOracle = new SimplePriceOracle(); // deploy oracle contract

        // unitroller & comptroller
        Comptroller comptroller = new Comptroller();
        Unitroller unitroller = new Unitroller();
        Comptroller unitrollerProxy = Comptroller(address(unitroller));
        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(priceOracle);

        // set Model
        WhitePaperInterestRateModel whitePaperInterestRateModel = new WhitePaperInterestRateModel(0, 0);

        CErc20Delegate delegate = new CErc20Delegate(); 
        bytes memory data = new bytes(0x00);

        CErc20Delegator delegator = new CErc20Delegator(
            address(underlyingToken),
            ComptrollerInterface(address(unitroller)),
            InterestRateModel(address(whitePaperInterestRateModel)),
            1e18,
            "Compound Test Token",
            "CTT",
            18,
            payable(msg.sender),
            address(delegate),
            data
        ); 

        vm.stopBroadcast();
    }
}