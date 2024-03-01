pragma solidity 0.8.19;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";

abstract contract GovernableRelayer {
    IWormholeRelayer public immutable wormholeRelayer;
    address immutable vault;
    uint16 immutable targetChain;

    uint256 constant GAS_LIMIT = 1_000_000;

    constructor(address _wormholeRelayer, address _removeVault, uint16 _targetChain, address _vault) {
        // TODO: checks
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        vault = _vault;
        targetChain = _targetChain;
    }


    function getQuote() public view returns (uint256 cost) {
        // Cost of requesting a message to be sent to
        // chain 'targetChain' with a gasLimit of 'GAS_LIMIT'
        (cost,) = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
    }


    /// @dev inherited by L2 Govenor
    function _executeCrosschainProposal(uint256 proposalId, address[] calldata targets, uint256[] calldata values, bytes[] calldata targetCallDatas) internal {

        uint256 cost = getQuote();
        require(msg.value == cost, "Incorrect payment");

        bytes memory payload = abi.encode(proposalId, targets, values, targetCallDatas);

        // propsalId + calldata
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            vault,
            payload,
            0, // no receiver value needed
            GAS_LIMIT
        );
    }
}
