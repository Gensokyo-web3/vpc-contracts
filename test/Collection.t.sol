// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/Collection.sol";

contract CollectionTest is Test {
    Collection public collection;

    string public collectionName = "name";
    string public collectionSymbol = "symbol";

    address public manager = address(0xaa);

    function setUp() public {
        collection = new Collection(collectionName, collectionSymbol, manager);
        vm.prank(manager);
        collection.setCollectionMetadata("ipfs://defaultCollectionMetadata");
    }

    function testOwnerPermissions() public {
        string memory newCollectionMetadata = "ipfs://newCollectionMetadata";
        vm.prank(manager);
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
        string memory correctMetadata = "ipfs://someCorrectTokenMetadata";
        if (_fakeManager == manager) return;
        vm.prank(_fakeManager);
        vm.expectRevert("Ownable: caller is not the owner");
        collection.mint(correctMetadata);
    }

    function testMintToken() public {
        string memory correctMetadata = "ipfs://someCorrectTokenMetadata";
        // STEP 1
        // set collection metadata as NULL (not correct) & Mint by manager.
        vm.prank(manager);
        collection.setCollectionMetadata("");
        assertEq(bytes(""), bytes(collection.metadata()));

        vm.prank(manager);
        vm.expectRevert("Collection: Please check the collection's metadata.");
        collection.mint(correctMetadata);

        // STEP 2
        // set collection metadata correct & Mint a NULL token by manager.
        vm.prank(manager);
        collection.setCollectionMetadata(correctMetadata);

        vm.prank(manager);
        vm.expectRevert("Collection: Invalid Metadata.");
        collection.mint("");

        // STEP 3
        // set collection metadata correct & Mint a new token by manager.
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
}
