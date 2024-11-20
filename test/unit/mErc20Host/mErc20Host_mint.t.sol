// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

// contracts
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";

// tests
import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mErc20Host_mint is mToken_Unit_Shared {
    function test_RevertGiven_MarketIsPausedForMinting(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint)
        inRange(amount, SMALL, LARGE)
    {
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWethHost.mint(amount);
    }

    function test_RevertGiven_MarketIsNotListed(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint)
        inRange(amount, SMALL, LARGE)
    {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWethHost.mint(amount);
    }

    function test_RevertGiven_WhenSupplyCapIsReached(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenSupplyCapReached(address(mWethHost), amount)
        whenMarketIsListed(address(mWethHost))
    {
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethHost), amount);

        vm.expectRevert(OperatorStorage.Operator_MarketSupplyReached.selector);
        mWethHost.mint(amount);
        // it should revert with Operator_MarketSupplyReached
    }

    function test_WhenSupplyCapIsGreater(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWethHost))
    {
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethHost), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        mWethHost.mint(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore);

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore);

        // it should transfer underlying from user
        assertGt(balanceWethBefore, balanceWethAfter);

        assertEq(totalSupplyAfter - amount, totalSupplyBefore);
    }

    function test_GivenAmountIs0() external whenMarketIsListed(address(mWethHost)) {
        uint256 amount = 0;
        vm.expectRevert(); //arithmetic underflow or overflow
        mWethHost.mint(amount);
    }

    modifier whenMintExternalIsCalled() {
        // @dev does nothing; for readability only
        _;
    }

    modifier givenDecodedAmountIsValid() {
        // @dev does nothing; for readability only
        _;
    }

    function test_RevertGiven_JournalIsEmpty(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenMintExternalIsCalled
    {
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);
        mWethHost.mintExternal("", "0x123");
    }

    function test_RevertGiven_JournalIsNonEmptyButLengthIsNotValid(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenMintExternalIsCalled
    {
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);
        mWethHost.mintExternal("", "0x123");
    }

    function test_GivenDecodedAmountIs0() external whenMintExternalIsCalled whenImageIdExists {
        uint256 amount = 0;
        bytes memory journalData = _createJournal(
            amount,
            address(this),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Mint)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);
        mWethHost.mintExternal(journalData, "0x123");
    }

    function test_RevertWhen_SealVerificationFails(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenMintExternalIsCalled
        whenImageIdExists
        givenDecodedAmountIsValid
    {
        bytes memory journalData = _createJournal(
            amount,
            address(this),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Mint)
        );

        verifierMock.setStatus(true); // set for failure

        vm.expectRevert();
        mWethHost.mintExternal(journalData, "0x123");
    }

    function test_WhenSealVerificationWasOk(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenMintExternalIsCalled
        whenImageIdExists
        givenDecodedAmountIsValid
        whenMarketIsListed(address(mWethHost))
    {
        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        bytes memory journalData = _createJournal(
            amount,
            address(this),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Mint)
        );
        mWethHost.mintExternal(journalData, "0x123");

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore);

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore);

        // it should transfer underlying from user
        assertEq(balanceWethBefore, balanceWethAfter);

        assertEq(totalSupplyAfter - amount, totalSupplyBefore);
    }
}
