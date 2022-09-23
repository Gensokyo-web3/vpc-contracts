// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./SBT.sol";

contract Collection is ERC721URIStorage, Ownable, SBT {
    using Counters for Counters.Counter;
    Counters.Counter public counters;

    // isSBT will make the entire NFT in the collection non-transferable.
    // to control the independent tokenId, please use the function "setTokenIsSBT".
    bool public isSBT = false;
    bool public isAllowUserBurnToken = false;

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

    function mint(string memory _tokenMetadata)
        public
        onlyOwner
        returns (uint256)
    {
        require(
            bytes(metadata).length > 0,
            "Collection: Please check the collection's metadata."
        );

        require(
            bytes(_tokenMetadata).length > 0,
            "Collection: Invalid Metadata."
        );

        uint256 newTokenId = counters.current();
        _mint(address(this), newTokenId);
        _setTokenURI(newTokenId, _tokenMetadata);
        counters.increment();
        emit Minted(newTokenId, _tokenMetadata);
        return newTokenId;
    }

    function burn(uint256 _tokenId) public {
        // NOT ONLYOWNER !
        require(locked(_tokenId) == false, "Collection: SBT cannot be burned.");

        if (owner() == msg.sender) {
            // is Collection owner
            _burn(_tokenId);
            emit Burned(_tokenId);
            return;
        } else {
            // is not Collection owner
            // allow user burn
            require(
                isAllowUserBurnToken,
                "Collection: token is not allowed to burned."
            );

            require(
                ownerOf(_tokenId) == _msgSender(),
                "Collection: The caller is not the owner of the Token."
            );

            _burn(_tokenId);
            emit Burned(_tokenId);
            return;
        }
    }

    // SET the status of allowing users to burn his own token.
    function setCollectionIsAllowUserToBurnHisOwnToken(bool _allowBurnStatus)
        public
        onlyOwner
    {
        isAllowUserBurnToken = _allowBurnStatus;
    }

    // Transfer from COLLECTION to user.
    function transferTokenFromCollectionToUserAddress(
        uint256 _tokenId,
        address _user
    ) public onlyOwner {
        require(
            _user != address(0) && _user != address(this),
            "Collection: Please make sure the user address is correct."
        );
        _transfer(address(this), _user, _tokenId);
        emit TransferToUserFromCollection(_tokenId, _user);
    }

    // SET Token's metadata (by Token ID)
    function setTokenMetadata(uint256 _tokenId, string memory _tokenMetadata)
        public
        onlyOwner
    {
        _setTokenURI(_tokenId, _tokenMetadata);
        emit TokenMeatadataUpdated(_tokenId, _tokenMetadata);
    }

    // SET Collection's metadata
    function setCollectionMetadata(string memory _collectionMetadata)
        public
        onlyOwner
    {
        metadata = _collectionMetadata;
        // emit CollectionMetadataUpdated(_collectionMetadata);
    }

    // SET Base URI for token  metadata: for the full metadata URL
    function setCollectionBaseURI(string memory _baseURIForMetadata)
        public
        onlyOwner
    {
        baseURIForMetadata = _baseURIForMetadata;
    }

    // SET SBT status for COLLECTION
    function setCollectionIsSBT(bool _SBTStatus) public onlyOwner {
        isSBT = _SBTStatus;
        // emit CollectionIsSBTStatusUpdated(isSBT);
    }

    // SET SBT status for Token ()
    function setTokenIsSBT(bool _tokenIdIsSBT, uint256 _tokenId)
        public
        onlyOwner
    {
        if (_tokenIdIsSBT) {
            _lockToken(_tokenId);
        } else {
            _unlockToken(_tokenId);
        }
    }

    // PUBLIC QUERY FEATURES
    function totalSupply() public view returns (uint256) {
        return counters.current();
    }

    // FOR SBT IERC5192.locked function returns.
    // GET tokenId -> token's lock status.
    // "isSBT" hiegh level.
    // "tokenId => lockStatus" is low level.
    function _locked(uint256 tokenId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        if (isSBT) {
            return isSBT;
        } else {
            return _tokenIsBound[tokenId];
        }
    }

    // For ERC721URIStorage get full metadata URI
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURIForMetadata;
    }

    /**
     * Override function
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (isSBT) {
            require(
                from == address(0) || from == address(this),
                "SBTCollection: only allow first mint."
            );
        } else {
            require(
                _tokenIsBound[tokenId] == false,
                "SBTCollection: SBT cannot transfer."
            );
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
