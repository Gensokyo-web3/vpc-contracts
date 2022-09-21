// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// import "./interfaces/IERC5192.sol"; // TODO: Add SBT SUPPORT 09-21-2022

contract Collection is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public counters;

    bool public isSBT = false;

    string public metadata;
    string public baseURIForMetadata;

    // event CollectionMetadataUpdated(string _metadata);
    event TokenMeatadataUpdated(uint256 indexed _tokenId, string _metadata);
    event TransferToUserFromCollection(uint256 indexed _tokenId, address _user);
    // event CollectionIsSBTStatusUpdated(bool _isSBT);

    event Minted(uint256 indexed _tokenId, string _metadata);
    event Burned(uint256 indexed _tokenId);

    constructor(
        string memory _name,
        string memory _symbol,
        // string memory _metadata,
        address _manager
    ) ERC721(_name, _symbol) {
        // metadata = _metadata;
        transferOwnership(_manager);
    }

    function mint(string memory _tokenMetadata) public onlyOwner returns (uint256) {
        uint256 newTokenId = counters.current();
        _mint(address(this), newTokenId);
        _setTokenURI(newTokenId, _tokenMetadata);
        counters.increment();
        emit Minted(newTokenId, _tokenMetadata);
        return newTokenId;
    }

    function burn(uint256 _tokenId) public onlyOwner {
        _burn(_tokenId);
        emit Burned(_tokenId);
    }

    function transferTokenFromCollectionToUserAddress(uint256 _tokenId, address _user) public onlyOwner {
        require(
            _user != address(0) && _user != address(this),
            "Collection: Please make sure the user address is correct."
        );
        _transfer(address(this), _user, _tokenId);
        emit TransferToUserFromCollection(_tokenId,_user);
    }

    // SET Token's metadata (by Token ID)
    function setTokenMetadata(uint256 _tokenId, string memory _tokenMetadata) public onlyOwner {
        _setTokenURI(_tokenId, _tokenMetadata);
        emit TokenMeatadataUpdated(_tokenId, _tokenMetadata);
    }

    // SET Collection's metadata
    function setCollectionMetadata(string memory _collectionMetadata) public onlyOwner {
        metadata = _collectionMetadata;
        // emit CollectionMetadataUpdated(_collectionMetadata);
    }

    // SET Base URI for token  metadata: for the full metadata URL
    function setCollectionBaseURI(string memory _baseURIForMetadata) public onlyOwner {
        baseURIForMetadata = _baseURIForMetadata;
    }

    // SET SBT status
    function setCollectionIsSBT(bool _SBTStatus) public onlyOwner {
        isSBT = _SBTStatus;
        // emit CollectionIsSBTStatusUpdated(isSBT);
    }

    /**
     * PUBLIC QUERY FEATURES
     */
    function totalSupply() public view returns (uint256) {
        return counters.current();
    }

    // For ERC721URIStorage get full metadata URI
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURIForMetadata;
    }

    /**
     * Override function
     */
    function _beforeTokenTransfer( address from, address to, uint256 tokenId ) internal virtual override {
        require(
            isSBT == true && // FOR SBT
            (from == address(0) || from == address(this)),
            "SBTCollection: only allow first mint" 
        );
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
