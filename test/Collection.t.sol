// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/Collection.sol";

contract CollectionTest is Test {
    Collection public collection;

    string public collectionName = "name";
    string public collectionSymbol = "symbol";

    string public correctMetadata = "ipfs://someCorrectTokenMetadata";

    address public manager = address(0xaa);

    event CollectionMetadataUpdated(string _metadata);
    event TokenMeatadataUpdated(uint256 indexed _tokenId, string _metadata);
    event TransferToUserFromCollection(uint256 indexed _tokenId, address _user);
    event CollectionIsSBTStatusUpdated(bool _isSBT);

    event Minted(uint256 indexed _tokenId, string _metadata);
    event Burned(uint256 indexed _tokenId);

    // ERC721 Events
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function setUp() public {
        collection = new Collection(collectionName, collectionSymbol, manager);
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit CollectionMetadataUpdated("ipfs://defaultCollectionMetadata");
        collection.setCollectionMetadata("ipfs://defaultCollectionMetadata");
    }

    function testOwnerPermissions(
        address _userA,
        address _userB,
        string memory _metadataA,
        string memory _metadataB
    ) public {
        vm.assume(_userA != _userB);
        vm.assume(_userA != address(0));
        vm.assume(_userB != address(0));

        Collection collectionA = new Collection(
            collectionName,
            collectionSymbol,
            _userA
        );

        Collection collectionB = new Collection(
            collectionName,
            collectionSymbol,
            _userB
        );

        vm.prank(_userA);
        vm.expectRevert("Ownable: caller is not the owner");
        collectionB.setCollectionMetadata(_metadataB);

        vm.prank(_userA);
        vm.expectEmit(true, true, true, true);
        emit CollectionMetadataUpdated(_metadataA);
        collectionA.setCollectionMetadata(_metadataA);

        vm.prank(_userB);
        vm.expectRevert("Ownable: caller is not the owner");
        collectionA.setCollectionMetadata(_metadataA);

        vm.prank(_userB);
        vm.expectEmit(true, true, true, true);
        emit CollectionMetadataUpdated(_metadataB);
        collectionB.setCollectionMetadata(_metadataB);
    }

    function testOwnerPermissions() public {
        string memory newCollectionMetadata = "ipfs://newCollectionMetadata";
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit CollectionMetadataUpdated(newCollectionMetadata);
        collection.setCollectionMetadata(newCollectionMetadata);
        assertEq(bytes(newCollectionMetadata), bytes(collection.metadata()));
    }

    function testPermissionsByIllegalOwner(address _fakeManager) public {
        if (_fakeManager == manager) return;
        vm.prank(_fakeManager);
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setCollectionMetadata("IllegalSettings");
    }

    function testMintTokenByIllegaUser(address _fakeManager) public {
        if (_fakeManager == manager) return;
        vm.prank(_fakeManager);
        vm.expectRevert("Ownable: caller is not the owner");
        collection.mint(correctMetadata);
    }

    function testMintTokenByManagerNullMeta() public {
        // set collection metadata as NULL (not correct) & Mint by manager.
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit CollectionMetadataUpdated("");
        collection.setCollectionMetadata("");
        assertEq(bytes(""), bytes(collection.metadata()));

        vm.prank(manager);
        vm.expectRevert("Collection: Please check the collection's metadata.");
        collection.mint(correctMetadata);
    }

    function testMintNullTokenByManager() public {
        // set collection metadata correct & Mint a NULL token by manager.
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit CollectionMetadataUpdated(correctMetadata);
        collection.setCollectionMetadata(correctMetadata);

        vm.prank(manager);
        vm.expectRevert("Collection: Invalid Metadata.");
        collection.mint("");
    }

    function testMintNewToken() public {
        // set collection metadata correct & Mint a new token by manager.
        vm.expectEmit(true, true, true, true);
        emit Minted(0, correctMetadata);
        vm.prank(manager);
        uint256 mintedTokenId = collection.mint(correctMetadata);
        assertEq(mintedTokenId, 0);
        // check metadata (token URI) of token.
        string memory tokenURIofMintedToken = collection.tokenURI(
            mintedTokenId
        );
        assertEq(bytes(tokenURIofMintedToken), bytes(correctMetadata));
    }

    function _mintATokenByManager() internal returns (uint256) {
        vm.prank(manager);

        uint256 mintedTokenId = collection.mint("hello");
        uint256 currentTokenId = collection.totalSupply();
        assertEq(mintedTokenId, currentTokenId - 1);
        return mintedTokenId;
    }

    function testBurnToken(address _illegaUser, address _normalUser) public {
        if (
            _illegaUser == address(collection) ||
            _illegaUser == manager ||
            _illegaUser == _normalUser ||
            _normalUser == address(collection) ||
            _normalUser == address(0x0)
        ) return;

        // isAllowUserBurnToken = false
        // Try to burn token by Manager
        uint256 mintedTokenId = _mintATokenByManager();
        assertEq(mintedTokenId, 0);

        vm.expectEmit(true, true, true, true);
        emit Burned(mintedTokenId);

        vm.prank(manager);

        collection.burn(mintedTokenId);
        // Try to get burned Token.
        vm.expectRevert("ERC721: invalid token ID");
        collection.ownerOf(mintedTokenId);

        // isAllowUserBurnToken = false
        // Try to burn token by ILLEGA user.
        mintedTokenId = _mintATokenByManager();
        assertEq(mintedTokenId, 1);
        vm.prank(_illegaUser);
        vm.expectRevert("Collection: token is not allowed to burned.");
        collection.burn(mintedTokenId);

        // isAllowUserBurnToken = true
        // Burn token by ILLEGA user.
        mintedTokenId = _mintATokenByManager();
        assertEq(mintedTokenId, 2);

        vm.prank(manager);
        collection.setCollectionIsAllowUserToBurnHisOwnToken(true);
        assertEq(collection.isAllowUserBurnToken(), true);

        vm.prank(_illegaUser);
        vm.expectRevert(
            "Collection: The caller is not the owner of the Token."
        );
        collection.burn(mintedTokenId);
        address mintedTokenOwner = collection.ownerOf(mintedTokenId);
        assertEq(address(collection), mintedTokenOwner);

        // isAllowUserBurnToken = true
        // Burn token by normal user.
        // transfer Token from collection to users.
        mintedTokenId = _mintATokenByManager();
        vm.prank(manager);
        collection.transferTokenFromCollectionToUserAddress(
            mintedTokenId,
            _normalUser
        );
        // burn token by user.
        vm.prank(_normalUser);
        collection.burn(mintedTokenId);
    }

    function testAllowUserBurnHisOwnToken(bool _allowBurnStatus) public {
        // by illegal user.
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setCollectionIsAllowUserToBurnHisOwnToken(_allowBurnStatus);

        // by manager.
        vm.prank(manager);
        collection.setCollectionIsAllowUserToBurnHisOwnToken(_allowBurnStatus);
        assertEq(collection.isAllowUserBurnToken(), _allowBurnStatus);
    }

    function testTransferTokenFromCollectionToUserAddress(address _targetUser)
        public
    {
        // if (_targetUser == address(0) || _targetUser == address(collection)) {
        //     return;
        // }

        vm.assume(_targetUser != address(0));
        vm.assume(_targetUser != address(collection));

        uint256 mintedTokenId = _mintATokenByManager();
        uint256 nonExistentTokenId = 20000;

        // not exist token Id
        vm.prank(manager);
        vm.expectRevert("ERC721: invalid token ID");
        collection.transferTokenFromCollectionToUserAddress(
            nonExistentTokenId,
            _targetUser
        );

        // by illegal user
        vm.expectRevert("Ownable: caller is not the owner");
        collection.transferTokenFromCollectionToUserAddress(
            mintedTokenId,
            _targetUser
        );

        // by manager.
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit TransferToUserFromCollection(mintedTokenId, _targetUser);
        collection.transferTokenFromCollectionToUserAddress(
            mintedTokenId,
            _targetUser
        );
        address mintedTokenOwner = collection.ownerOf(mintedTokenId);
        assertEq(mintedTokenOwner, _targetUser);

        // Test the transferred token Id
        vm.prank(manager);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        collection.transferTokenFromCollectionToUserAddress(
            mintedTokenId,
            _targetUser
        );
    }

    function testEnableCollectionSBTState(bool _SBTState) public {
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit CollectionIsSBTStatusUpdated(_SBTState);
        collection.setCollectionIsSBT(_SBTState);

        // set SBT state by illegal user.
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setCollectionIsSBT(!_SBTState);
    }

    function testMintAndTransferOutFromCollectionWhenGlobalSBTStateIsEnabled(
        address _targetUser
    ) public {
        // mint & transfer (from Collection) to User when Global SBT is true.
        vm.assume(_targetUser != address(0));
        vm.assume(_targetUser != address(collection));

        vm.prank(manager);
        collection.setCollectionIsSBT(true);

        uint256 mintedTokenId = _mintATokenByManager();

        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(collection), _targetUser, mintedTokenId);
        collection.transferTokenFromCollectionToUserAddress(
            mintedTokenId,
            _targetUser
        );
    }

    function _mintAndTransferOurFromCollectionToken(address _targetUser)
        internal
        returns (uint256)
    {
        uint256 mintedTokenId = _mintATokenByManager();
        vm.prank(manager);
        collection.transferTokenFromCollectionToUserAddress(
            mintedTokenId,
            _targetUser
        );
        return mintedTokenId;
    }

    function testAfterFransferOurFromCollectionTryToTransferByUserWhenSBTIsEnabled(
        address _targetUser
    ) public {
        if (_targetUser == address(0) || _targetUser == address(collection))
            return;

        vm.prank(manager);
        collection.setCollectionIsSBT(true);

        address aNewTarget = address(0xbb);
        uint256 mintedTokenId = _mintAndTransferOurFromCollectionToken(
            _targetUser
        );

        vm.prank(_targetUser);
        vm.expectRevert("SBTCollection: only allow first mint.");
        collection.transferFrom(_targetUser, aNewTarget, mintedTokenId);
    }

    function testMintAndTransferOutFromCollectionWhenSingelTokenIsSBT(
        address _targetUser
    ) public {
        if (_targetUser == address(0) || _targetUser == address(collection))
            return;

        uint256 mintedTokenIdA = _mintAndTransferOurFromCollectionToken(
            _targetUser
        );

        uint256 mintedTokenIdB = _mintAndTransferOurFromCollectionToken(
            _targetUser
        );

        vm.prank(manager);
        collection.setTokenIsSBT(true, mintedTokenIdA); // A is SBT, owner is _targetUser
        assertTrue(collection.locked(mintedTokenIdA));

        vm.prank(manager);
        collection.setTokenIsSBT(false, mintedTokenIdB); // B not SBT, owner is _targetUser
        assertFalse(collection.locked(mintedTokenIdB));

        address newTokenOwner = address(0xbb);
        vm.prank(_targetUser);
        vm.expectRevert("SBTCollection: SBT cannot transfer.");
        collection.transferFrom(_targetUser, newTokenOwner, mintedTokenIdA);
        assertEq(collection.ownerOf(mintedTokenIdA), _targetUser);

        vm.prank(_targetUser);
        collection.transferFrom(_targetUser, newTokenOwner, mintedTokenIdB);
        assertEq(collection.ownerOf(mintedTokenIdB), newTokenOwner);

        // set collection's isSBT = true (, and transfer B token.)
        vm.prank(manager);
        collection.setCollectionIsSBT(true);
        assertEq(collection.isSBT(), true);

        // When isSBT is true, all token "locked" status will be true.
        assertEq(collection.locked(mintedTokenIdA), true);
        assertEq(collection.locked(mintedTokenIdB), true);

        // as the newTokenOwner try to transfer token B backto _targetUser.(in isSBT = true mode)
        vm.prank(newTokenOwner);
        vm.expectRevert("SBTCollection: only allow first mint.");
        collection.transferFrom(newTokenOwner, _targetUser, mintedTokenIdB);

        // as _targetUser try to transfer token A to newTokenOwner (in isSBT = true mode)
        vm.prank(_targetUser);
        vm.expectRevert("SBTCollection: only allow first mint.");
        collection.transferFrom(_targetUser, newTokenOwner, mintedTokenIdA);

        // set collection's isSBT = false (, and transfer token.)
        vm.prank(manager);
        collection.setCollectionIsSBT(false);
        assertEq(collection.isSBT(), false);

        // When isSBT is true, just locked (by handle) token will be true, in (not locked) default is false.
        assertEq(collection.locked(mintedTokenIdA), true);
        assertEq(collection.locked(mintedTokenIdB), false);
        assertEq(collection.ownerOf(mintedTokenIdA), _targetUser);
        assertEq(collection.ownerOf(mintedTokenIdB), newTokenOwner);

        // try to transfer (by user) after isSBT false->true->false;
        vm.prank(newTokenOwner);
        collection.transferFrom(newTokenOwner, _targetUser, mintedTokenIdB);
        assertEq(collection.ownerOf(mintedTokenIdB), _targetUser);

        // token B locked() == true, so token B unable transfer
        vm.prank(_targetUser);
        vm.expectRevert("SBTCollection: SBT cannot transfer.");
        collection.transferFrom(_targetUser, newTokenOwner, mintedTokenIdA);
    }

    function testSetMetadataForCollection(
        string memory _metadata,
        address _illegalUser
    ) public {
        // already tested in testOwnerPermissions();
        vm.assume(_illegalUser != address(manager));
        // set metadata by illegalUser
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setCollectionMetadata(_metadata);
        // set metadata by manager
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit CollectionMetadataUpdated(_metadata);
        collection.setCollectionMetadata(_metadata);
        assertEq(collection.metadata(), _metadata);
    }

    function testSetMetadataForToken(
        string memory _metadataA,
        string memory _metadataB,
        address _illegalUser
    ) public {
        vm.assume(_illegalUser != address(manager));

        uint256 mintedTokenIdA = _mintATokenByManager();
        uint256 mintedTokenIdB = _mintATokenByManager();
        assertEq(collection.tokenURI(mintedTokenIdA), "hello");
        assertEq(collection.tokenURI(mintedTokenIdB), "hello");

        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit TokenMeatadataUpdated(mintedTokenIdA, _metadataA);
        collection.setTokenMetadata(mintedTokenIdA, _metadataA);
        assertEq(collection.tokenURI(mintedTokenIdA), _metadataA);

        vm.prank(_illegalUser);
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setTokenMetadata(mintedTokenIdB, _metadataB);
        assertEq(collection.tokenURI(mintedTokenIdB), "hello");
    }

    function testSetCollectionBaseURI(
        string memory _baseURI,
        address _illegalUser
    ) public {
        vm.assume(_illegalUser != address(manager));

        vm.prank(_illegalUser);
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setCollectionBaseURI(_baseURI);

        vm.prank(manager);
        collection.setCollectionBaseURI(_baseURI);

        uint256 mintedTokenId = _mintATokenByManager();
        assertEq(
            collection.tokenURI(mintedTokenId),
            string(abi.encodePacked(_baseURI, "hello"))
        );
    }
}
