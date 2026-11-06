// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, stdError} from "forge-std/Test.sol";
import {ZombieFactory} from "../src/ZombieFactory.sol";

contract ZombieFactoryTest is Test {
    ZombieFactory factory;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    event ZombieCreated(uint256 indexed id, address indexed owner, string name, uint256 dna);

    function setUp() public {
        factory = new ZombieFactory();
    }

    function testAliceCreatesZombie() public {
        vm.prank(alice);
        uint256 id = factory.createZombie("Alice");
        assertEq(id, 0);
        assertEq(factory.zombieToOwner(id), alice);
    }

    function testCreateZombieStoresData() public {
        vm.warp(1_700_000_000);

        vm.prank(alice);
        uint256 id = factory.createZombie("Alice");

        (string memory name, uint256 dna, uint256 createdAt) = factory.getZombie(id);
        assertEq(id, 0);
        assertEq(name, "Alice");
        assertEq(dna, uint256(keccak256(abi.encodePacked(alice, "Alice"))) % factory.DNA_MODULUS());
        assertEq(createdAt, 1_700_000_000);
        assertEq(factory.zombieToOwner(id), alice);
        assertEq(factory.ownerZombieCount(alice), 1);
        assertEq(factory.totalZombies(), 1);
    }

    function testTwoOwnersCreateDifferentZombies() public {
        vm.prank(alice);
        uint256 aliceId = factory.createZombie("Zed");
        vm.prank(bob);
        uint256 bobId = factory.createZombie("Zed");

        assertEq(aliceId, 0);
        assertEq(bobId, 1);
        assertEq(factory.zombieToOwner(aliceId), alice);
        assertEq(factory.zombieToOwner(bobId), bob);
        assertEq(factory.ownerZombieCount(alice), 1);
        assertEq(factory.ownerZombieCount(bob), 1);
        assertEq(factory.totalZombies(), 2);

        (, uint256 aliceDna,) = factory.getZombie(aliceId);
        (, uint256 bobDna,) = factory.getZombie(bobId);
        assertTrue(aliceDna != bobDna);
    }

    function testRevertsOnEmptyName() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Empty name"));
        factory.createZombie("");

        assertEq(factory.totalZombies(), 0);
    }

    function testRevertsOnSecondZombie() public {
        vm.startPrank(alice);
        factory.createZombie("First");
        vm.expectRevert(bytes("Already has zombie"));
        factory.createZombie("Second");
        vm.stopPrank();

        assertEq(factory.totalZombies(), 1);
        assertEq(factory.ownerZombieCount(alice), 1);
    }

    function testDnaIsBelowModulus() public {
        vm.prank(alice);
        uint256 id = factory.createZombie("Alice");

        (, uint256 dna,) = factory.getZombie(id);
        assertLt(dna, factory.DNA_MODULUS());
    }

    function testEmitsZombieCreated() public {
        uint256 dna = uint256(keccak256(abi.encodePacked(alice, "Alice"))) % factory.DNA_MODULUS();

        vm.expectEmit(true, true, false, true, address(factory));
        emit ZombieCreated(0, alice, "Alice", dna);

        vm.prank(alice);
        factory.createZombie("Alice");
    }

    function testGetZombieRevertsForUnknownId() public {
        vm.expectRevert(stdError.indexOOBError);
        factory.getZombie(0);
    }

    function testFuzzDnaIsBelowModulus(address owner, string calldata name) public {
        vm.assume(bytes(name).length > 0);

        vm.prank(owner);
        uint256 id = factory.createZombie(name);

        (, uint256 dna,) = factory.getZombie(id);
        assertLt(dna, factory.DNA_MODULUS());
        assertEq(factory.zombieToOwner(id), owner);
    }
}
