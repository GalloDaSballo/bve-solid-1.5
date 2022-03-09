// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {BaseStrategy} from "@badger-finance/BaseStrategy.sol";

import "../interfaces/solidly/IBaseV1Gauge.sol";
import "../interfaces/solidly/IBaseV1Voter.sol";
import "../interfaces/solidly/IVe.sol";
import "../interfaces/solidly/IveDist.sol";

contract MyStrategy is BaseStrategy, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow

    address public constant BADGER_TREE =
        0x89122c767A5F543e663DB536b603123225bc3823;

    
    IVe public constant VE = IVe(0xcBd8fEa77c2452255f59743f55A3Ea9d83b3c72b);

    IBaseV1Voter public constant VOTER = IBaseV1Voter(0xdC819F5d05a6859D2faCbB4A44E5aB105762dbaE);
    
    IveDist public constant VE_DIST = IveDist(0xA5CEfAC8966452a78d6692837b2ba83d19b57d07);

    uint256 public lockId; // Will be set on first lock and always used

    bool public relockOnEarn; // Should we relock?
    bool public relockOnTend;

    uint public constant MAXTIME = 4 * 365 * 86400;

    event SetRelockOnEarn(bool value);
    event SetRelockOnTend(bool value);

    /// @dev Initialize the Strategy with security settings as well as tokens
    /// @notice Proxies will set any non constant variable you declare as default value
    /// @dev add any extra changeable variable at end of initializer as shown
    function initialize(address _vault, address[1] memory _wantConfig) public initializer {
        __BaseStrategy_init(_vault);

        address _want = _wantConfig[0];
        want = _want;
        
        // If you need to set new values that are not constants, set them like so
        // stakingContract = 0x79ba8b76F61Db3e7D994f7E384ba8f7870A043b7;

        // If you need to do one-off approvals do them here like so
        IERC20Upgradeable(_want).safeApprove(
            address(VE),
            type(uint256).max
        );
    }
    
    /// @dev Return the name of the strategy
    function getName() external pure override returns (string memory) {
        return "Strategy Vested Escrow Solid";
    }

    /// @dev Return a list of protected tokens
    /// @notice It's very important all tokens that are meant to be in the strategy to be marked as protected
    /// @notice this provides security guarantees to the depositors they can't be sweeped away
    function getProtectedTokens() public view virtual override returns (address[] memory) {
        address[] memory protectedTokens = new address[](2);
        protectedTokens[0] = want;
        protectedTokens[1] = address(VE);
        // Other tokens can be claimed, but claiming instantly emits them, 
        // so no tokens are expected to be in the strategy at any time
        return protectedTokens;
    }

    /// @dev Deposit `_amount` of want, investing it to earn yield
    function _deposit(uint256 _amount) internal override {
        if(lockId != 0) {
            // Lock More
            VE.increase_amount(lockId, _amount);
        } else {
            // Create lock, for maximum time
            lockId = VE.create_lock(_amount, MAXTIME);
        }
    }

    /// @dev Withdraw all funds, this is used for migrations, most of the time for emergency reasons
    function _withdrawAll() internal override {
        VE.withdraw(lockId); // Revert if lock not expired
    }

    /// @dev Withdraw `_amount` of want, so that it can be sent to the vault / depositor
    /// @notice just unlock the funds and return the amount you could unlock
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        if(balanceOfWant() >= _amount) {
            return _amount; // We have liquid assets, just send those
        }

        VE.withdraw(lockId); // Will revert is lock is not expired

        return balanceOfWant(); // Max 
    }

    //// === VE CUSTOM == //

    function _onlyTrusted() internal view {
        require(
            msg.sender == keeper() || msg.sender == governance() || msg.sender == strategist(),
            "_onlyTrusted"
        );
    }

    /// @notice Because locks last 4 years, we let strategist change the setting, impact is minimal
    function setRelockOnEarn(bool _relock) external {
        _onlyTrusted();
        relockOnEarn = _relock;
        emit SetRelockOnEarn(_relock);
    }

    function setRelockOnTend(bool _relock) external {
        _onlyTrusted();
        relockOnTend = _relock;
        emit SetRelockOnTend(_relock);
    }

    function claimDistribution() external returns (uint) {
        require(lockId != 0);

        uint256 harvested = VE_DIST.claim(lockId);
        _reportToVault(harvested); // Report profit for amount locked, takes fees, issues perf fees
    }


    /// Claim Tokens
    function claimRewards(address _gauge, address[] memory _tokens) external nonReentrant {
        _onlyTrusted();

        uint256 length = _tokens.length;

        // Get initial Amounts
        uint256[] memory amounts = new uint256[](length);

        for(uint i; i < length; ++i) {
            amounts[i] = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
        }

        // Claim
        address[] memory gauges = new address[](1);
        gauges[0] = _gauge;

        address[][] memory tokens = new address[][](1);
        tokens[0] = _tokens;

        VOTER.claimRewards(gauges, tokens);


        // Get Amounts balAfter & Handle the diff
        for(uint i; i < length; ++i) {
            uint256 balAfter = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
            uint256 toSend = balAfter.sub(amounts[i]);

            // Send it here else a duplicate will break the math
            // Safe because we send all the tokens, hence a duplicate will have difference = 0 and will stop
            _handleToken(_tokens[i], toSend);
        }
    }

    function claimBribes(address _bribe, address[] memory _tokens, uint _tokenId) external nonReentrant {
        _onlyTrusted();

        uint256 length = _tokens.length;

        // Get initial Amounts
        uint256[] memory amounts = new uint256[](length);

        for(uint i; i < length; ++i) {
            amounts[i] = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
        }

        // Claim
        address[] memory bribes = new address[](1);
        bribes[0] = _bribe;

        address[][] memory tokens = new address[][](1);
        tokens[0] = _tokens;

        VOTER.claimBribes(bribes, tokens, _tokenId);

        // Get Amounts balAfter & Handle the diff
        for(uint i; i < length; ++i) {
            uint256 balAfter = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
            uint256 toSend = balAfter.sub(amounts[i]);

            // Send it here else a duplicate will break the math
            // Safe because we send all the tokens, hence a duplicate will have difference = 0 and will stop
            _handleToken(_tokens[i], toSend);
        }
    }

    function claimFees(address _fee, address[] memory _tokens, uint _tokenId) external nonReentrant {
        _onlyTrusted();

        uint256 length = _tokens.length;

        // Get initial Amounts
        uint256[] memory amounts = new uint256[](length);

        for(uint i; i < length; ++i) {
            amounts[i] = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
        }

        // Claim
        address[] memory fees = new address[](1);
        fees[0] = _fee;

        address[][] memory tokens = new address[][](1);
        tokens[0] = _tokens;

        VOTER.claimFees(fees, tokens, _tokenId);

        // Get Amounts balAfter & Handle the diff
        for(uint i; i < length; ++i) {
            uint256 balAfter = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
            uint256 toSend = balAfter.sub(amounts[i]);

            // Send it here else a duplicate will break the math
            // Safe because we send all the tokens, hence a duplicate will have difference = 0 and will stop
            _handleToken(_tokens[i], toSend);
        }
    }

    
    /// VOTE
    function vote(address[] memory _poolVote, int256[] memory _weights) external nonReentrant {
        _onlyGovernance();
        VOTER.vote(lockId, _poolVote, _weights);
    }

    function _handleToken(address token, uint256 amount) internal {
        if(amount == 0) { return; } // If we get duplicate token, before - balAfter is going to be 0

        if(token == want) {
            // It's SOLID, lock more, emit harvest event
            VE.increase_amount(lockId, amount);

            _reportToVault(amount); // Report profit for amount locked, takes fees, issues perf fees
        } else {
            _processExtraToken(token, amount);
        }
    }

    /// @dev Does this function require `tend` to be called?
    function _isTendable() internal override pure returns (bool) {
        return false; // Change to true if the strategy should be tended
    }

    function _harvest() internal override returns (TokenAmount[] memory harvested) {
        // No-op as we don't do anything with funds
        // use autoCompoundRatio here to convert rewards to want ...

        // Nothing harvested, we have 2 tokens, return both 0s
        harvested = new TokenAmount[](1);
        harvested[0] = TokenAmount(want, 0);

        // keep this to get paid!
        _reportToVault(0);

        // To emit
        //     function _processExtraToken(address _token, uint256 _amount) internal {

        return harvested;
    }


    // Example tend is a no-op which returns the values, could also just revert
    function _tend() internal override returns (TokenAmount[] memory tended){
        // Nothing tended
        tended = new TokenAmount[](1);
        tended[0] = TokenAmount(want, 0); 
        return tended;
    }

    /// @dev Return the balance (in want) that the strategy has invested somewhere
    function balanceOfPool() public view override returns (uint256) {
        // No lock = no funds
        // Lock is the funds
        if(lockId == 0) {
            return 0;
        }

        return VE.balanceOfNFT(lockId);
    }

    /// @dev Return the balance of rewards that the strategy has accrued
    /// @notice Used for offChain APY and Harvest Health monitoring
    function balanceOfRewards() external view override returns (TokenAmount[] memory rewards) {
        // Rewards are 0
        rewards = new TokenAmount[](1);
        rewards[0] = TokenAmount(want, 0);

        if(lockId != 0) {
            rewards[0] = TokenAmount(want, VE_DIST.claimable(lockId));
        }
        return rewards;
    }
}
