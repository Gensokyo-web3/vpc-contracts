// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC5192.sol";

contract SBT is IERC5192  {
  mapping(uint256 => bool) internal _tokenIsBound;

  function _lockToken(uint256 tokenId) internal {
    _tokenIsBound[tokenId] = true;
    emit Locked(tokenId);
  } 

  function _unlockToken(uint256 tokenId) internal {
    _tokenIsBound[tokenId] = false;
    emit Unlocked(tokenId);
  }

  function _locked(uint256 tokenId) internal view virtual returns (bool) {
    return _tokenIsBound[tokenId];
  }

  function locked(uint256 tokenId) public override view returns (bool) {
    return _locked(tokenId);
  }
}