// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TheAccount} from "src/TheAccount.sol";
import {Deploy} from "script/Deploy.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract AccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    TheAccount myAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    address randomuser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    function setUp() public  {
        Deploy deploy = new Deploy();
        (helperConfig, myAccount) = deploy.deployAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // USDC Mint
    // msg.sender -> MyAccount
    // approve some amount
    // USDC contract
    // come from the entrypoint
    function testOwnerCanExecuteCommands() public  {
        // Arrange
        assertEq(usdc.balanceOf(address(myAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myAccount), AMOUNT);
        // Act
        vm.prank(myAccount.owner());
        myAccount.execute(dest, value, functionData);

        // Assert
        assertEq(usdc.balanceOf(address(myAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public  {
        // Arrange
        assertEq(usdc.balanceOf(address(myAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myAccount), AMOUNT);
        // Act
        vm.prank(randomuser);
        vm.expectRevert(TheAccount.TheAccount__NotFromEntryPointOrOwner.selector);
        myAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public  {
        // Arrange
        assertEq(usdc.balanceOf(address(myAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(TheAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(myAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // Act
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(actualSigner, myAccount.owner());
    }

    // 1. Sign user ops
    // 2. Call validate userops
    // 3. Assert the return is correct
    function testValidationOfUserOps() public  {
        // Arrange
        assertEq(usdc.balanceOf(address(myAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(TheAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(myAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = myAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public  {
        // Arrange
        assertEq(usdc.balanceOf(address(myAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(TheAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(myAccount)
        );
        // bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        vm.deal(address(myAccount), 1e18);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act
        vm.prank(randomuser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomuser));

        // Assert
        assertEq(usdc.balanceOf(address(myAccount)), AMOUNT);
    }
}