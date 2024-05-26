// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.6;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {IERC1155ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC1155ReceiverUpgradeable.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC165Upgradeable.sol";

// Import interfaces from the project
import {IAccessRestriction} from "./../../access/IAccessRestriction.sol";
import {ILRT} from "./../../tokens/erc20/ILRT.sol";
import {ILandRocker} from "./../../landrocker/ILandRocker.sol";
import {ILRTVesting} from "./../../vesting/ILRTVesting.sol";
import {ILandRockerERC1155} from "../../tokens/erc1155/ILandRockerERC1155.sol";
import {ILootBoxUpgraded} from "./ILootBoxUpgraded.sol";

import "hardhat/console.sol";

/**
 * @title LootBox
 * @dev A contract for managing non-minted ERC1155 asset sell orders.
 * This contract inherits from Marketplace and implements the ILootBox interface.
 */
contract LootBoxUpgraded is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC165Upgradeable,
    IERC1155ReceiverUpgradeable,
    ILootBoxUpgraded
{
    // Use counters library for incrementing sell Ids
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant CATEGORY = keccak256("LOOTBOX");

    // Access control reference
    IAccessRestriction internal _accessRestriction;
    // LRT reference
    ILRT internal _lrt;
    // LandRocker reference
    ILandRocker internal _landrocker;
    // LRTVesting reference
    ILRTVesting internal _lrtVesting;

    // Stores the capacity of the loot box
    uint256 public lootBoxCapacity;

    // Stores total created loot box
    uint256 public totalCreatedLootBox;

    // Mapping to store sell for each lootBox sell
    mapping(uint256 => LootBoxSell) public override lootBoxSells;

    // Maps user addresses to their respective sold lootBoxes.
    mapping(address => mapping(uint256 => uint16))
        public
        override userLootBoxes;

    // Counter for sell Ids
    CountersUpgradeable.Counter private _sellIdCounter;

    string public override greeting;

    /**
     * @dev Reverts if the caller is not the owner.
     */
    modifier onlyOwner() {
        _accessRestriction.ifOwner(msg.sender);
        _;
    }

    /**
     * @dev Reverts if the caller is not an admin.
     */
    modifier onlyAdmin() {
        _accessRestriction.ifAdmin(msg.sender);
        _;
    }

    /**
     * @dev Modifier: Only accessible by authorized scripts
     */
    modifier onlyScript() {
        _accessRestriction.ifScript(msg.sender);
        _;
    }

    // Modifier to validate addresses
    modifier validAddress(address _address) {
        require(_address != address(0), "LootBox::Not valid address");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the LootBox contract.
     * @param _accessRestrictionAddress The address of the access restriction contract.
     * @param _lrtAddress The address of the LRT contract.
     * @param _landrockerAddress The address of the LandRocker contract.
     * @param _lrtVestingAddress Address of the LRTVesting contract.
     * @param _greeting The greeting message to be displayed on the marketplace.
     */
    function initializeLootBox(
        address _accessRestrictionAddress,
        address _lrtAddress,
        address _landrockerAddress,
        address _lrtVestingAddress,
        string memory _greeting
    ) external override reinitializer(2) {
        _accessRestriction = IAccessRestriction(_accessRestrictionAddress);
        _lrt = ILRT(_lrtAddress);
        _landrocker = ILandRocker(_landrockerAddress);
        _lrtVesting = ILRTVesting(_lrtVestingAddress);

        greeting = _greeting;
    }

    /**
     * @dev Sets the maximum lootBox capacity allowed by the contract.
     * @param _lootBoxCapacity The maximum lootBox capacity.
     */
    function setLootBoxCapacity(
        uint256 _lootBoxCapacity
    ) external override onlyAdmin {
        require(
            _lootBoxCapacity > 0 && _lootBoxCapacity > totalCreatedLootBox,
            "LootBox::LootBox capacity not set"
        );
        lootBoxCapacity = _lootBoxCapacity;
        emit UpdatedLootBoxCapacity(_lootBoxCapacity);
    }

    /**
     * @dev Creates a new sell order for a lootBox asset.
     * @param _price The price of the asset in LRT tokens.
     * @param _sellUnit The unit of the asset being sold in each transaction.
     * @param _listedAmount The total amount of the asset to be listed for sale.
     * Only administrators can create sell orders.
     */
    function createSell(
        uint256 _price,
        uint256 _sellUnit,
        uint256 _listedAmount
    ) external override onlyAdmin {
        _validateSell(_listedAmount, _sellUnit);

        //Ensure that the price should be more than zero.
        require(_price > 0, "LootBox::LootBox price is invalid");

        LootBoxSell storage lootBoxSell = lootBoxSells[
            _sellIdCounter.current()
        ];

        //Set the listing to started
        lootBoxSell.status = 0;
        lootBoxSell.price = _price;
        lootBoxSell.sellUnit = _sellUnit;
        lootBoxSell.listedAmount = _listedAmount;
        lootBoxSell.soldAmount = 0;

        //Increment the _createdLootBoxCount by the given _listedAmount
        totalCreatedLootBox += _listedAmount;

        emit SellCreated(
            _sellIdCounter.current(),
            _price,
            _sellUnit,
            _listedAmount
        );

        _sellIdCounter.increment();
    }

    /**
     * @dev Edits an existing sell order for a lootBox asset.
     * @param _sellId The unique identifier of the sell order to be edited.
     * @param _price The updated price of the asset in LRT tokens.
     * @param _sellUnit The updated unit of the asset being sold in each transaction.
     * @param _listedAmount The updated total amount of the asset to be listed for sale.
     * Only administrators can edit sell orders.
     */
    function editSell(
        uint256 _sellId,
        uint256 _price,
        uint256 _sellUnit,
        uint256 _listedAmount
    ) external override onlyAdmin {
        LootBoxSell storage lootBoxSell = lootBoxSells[_sellId];

        //Ensure that the sell is there
        require(
            lootBoxSell.listedAmount > 0,
            "LootBox::The sell does not exist"
        );

        _validateSell(_listedAmount, _sellUnit);

        //Ensure that the listing is not sold
        require(
            lootBoxSell.status != 1,
            "LootBox::Sold listing lootBox cannot be edit"
        );

        require(
            _listedAmount >= lootBoxSell.soldAmount + _sellUnit,
            "LootBox::There are not any item to sell"
        );

        //Increment the totalCreatedLootBox by the given new _listedAmount
        totalCreatedLootBox -= lootBoxSell.listedAmount;
        totalCreatedLootBox += _listedAmount;

        // Update the sell order information
        lootBoxSell.status = 0;
        lootBoxSell.price = _price;
        lootBoxSell.sellUnit = _sellUnit;
        lootBoxSell.listedAmount = _listedAmount;

        // Emit an event to indicate the sell order has been updated
        emit SellUpdated(_sellId, _price, _sellUnit, _listedAmount);
    }

    /**
     * @dev Cancels a sell order.
     * @param _sellId The unique identifier of the sell order to be canceled.
     * Only administrators can cancel sell orders.
     */
    function cancelSell(uint256 _sellId) external override onlyAdmin {
        LootBoxSell storage lootBoxSell = lootBoxSells[_sellId];

        //Ensure that the listing is started
        require(lootBoxSell.status == 0, "LootBox::Cannot cancel active offer");
        //Set the listing to canceled
        lootBoxSell.status = 2;

        emit SellCanceled(_sellId);
    }

    /**
     * @dev Allows a user to purchase a lootBox asset from the marketplace.
     * @param _sellId The unique identifier of the sell order to be purchased.
     * Only administrators can edit sell orders.
     */
    function buyItem(uint256 _sellId) external override nonReentrant {
        LootBoxSell storage lootBoxSell = lootBoxSells[_sellId];

        //Ensure that the sell is there
        require(
            lootBoxSell.listedAmount > 0,
            "LootBox::The sell does not exist"
        );

        // Ensure that the total sold units do not exceed the listed amount
        require(
            lootBoxSell.sellUnit + lootBoxSell.soldAmount <=
                lootBoxSell.listedAmount,
            "LootBox::Exceed sell limit"
        );

        //Ensure that the listing is started
        require(
            lootBoxSell.status == 0,
            "LootBox::Listed lootBox has not valid status"
        );

        uint256 price = lootBoxSell.price;

        bool hasSufficientBalance = _lrt.balanceOf(msg.sender) >= price;

        // Transfer the LRT tokens from the buyer to the marketplace
        if (hasSufficientBalance) {
            _processLootBokxPurchase(_sellId, msg.sender, lootBoxSell);
        } else {
            _processVestingPurchase(_sellId, msg.sender, lootBoxSell);
        }

        // Update the sold amount and check if the listing is now sold out
        lootBoxSell.soldAmount += lootBoxSell.sellUnit;

        if (lootBoxSell.soldAmount == lootBoxSell.listedAmount) {
            //Set the listing to sold
            lootBoxSell.status = 1;
        }

        userLootBoxes[msg.sender][_sellId] += 1;
    }

    /**
     * @dev Reveals a loot box for a given buyer.
     * @param _sellId The ID of the loot box sale.
     * @param _collection The address of the collection contract.
     * @param _tokenId The ID of the token to mint.
     * @param _buyer The address of the buyer receiving the item.
     */
    function revealItem(
        uint256 _sellId,
        address _collection,
        uint256 _tokenId,
        address _buyer
    ) external override onlyScript nonReentrant {
        LootBoxSell storage lootBoxSell = lootBoxSells[_sellId];

        //Ensure that the sell is there
        require(
            lootBoxSell.listedAmount > 0,
            "LootBox::The sell does not exist"
        );

        //Ensure that the sellId with just one NFT exists
        require(lootBoxSell.sellUnit == 1, "LootBox::The sell does not exist");

        //Ensure that the buyer has sufficient lootBox form corresponding sellId
        require(
            userLootBoxes[_buyer][_sellId] > 0,
            "LootBox::Insufficient lootBox balance"
        );

        require(
            _landrocker.landrocker1155Collections(_collection),
            "LootBox::Collection is not active"
        );

        userLootBoxes[_buyer][_sellId] -= 1;

        // Emit an event indicating a successful lootBox reveal
        emit LootBoxRevealed(_sellId, _collection, _tokenId, _buyer);

        // Transfer the purchased tokens to the buyer
        ILandRockerERC1155(_collection).mint(_buyer, _tokenId, 1, CATEGORY);
    }

    /**
     * @dev Reveals a batch of loot box for a given buyer.
     * @param _sellId The ID of the loot box sale.
     * @param _collections An array of the address of collections.
     * @param _tokenIds An array of the tokenIds to mint.
     * @param _buyer The address of the buyer receiving the item.
     */
    function revealBatchItem(
        uint256 _sellId,
        address[] calldata _collections,
        uint256[] calldata _tokenIds,
        address _buyer
    ) external override onlyScript nonReentrant {
        LootBoxSell storage lootBoxSell = lootBoxSells[_sellId];

        //Ensure that the buyer has sufficient lootBox form corresponding sellId
        require(
            lootBoxSell.sellUnit == _collections.length &&
                _collections.length == _tokenIds.length,
            "LootBox::Invalid input parameters"
        );

        //Ensure that the sellId with more than one NFTs exists
        require(lootBoxSell.sellUnit > 1, "LootBox::The sell does not exist");

        //Ensure that the buyer has sufficient lootBox form corresponding sellId
        require(
            userLootBoxes[_buyer][_sellId] > 0,
            "LootBox::Insufficient lootBox balance"
        );

        // Iterate over the lootBoxes to reveal each one to the buyer
        for (uint256 i = 0; i < _collections.length; i++) {
            require(
                _landrocker.landrocker1155Collections(_collections[i]),
                "LootBox::Collection is not active"
            );

            // Emit an event indicating a successful lootBox reveal
            emit LootBoxBatchRevealed(
                _sellId,
                _collections[i],
                _tokenIds[i],
                _buyer
            );

            // Transfer the purchased tokens to the buyer
            ILandRockerERC1155(_collections[i]).mint(
                _buyer,
                _tokenIds[i],
                1,
                CATEGORY
            );
        }

        userLootBoxes[_buyer][_sellId] -= 1;
    }

    /**
     * @dev Handles the receipt of ERC1155 tokens when they are transferred to this contract.
     * @param operator The address which called `safeTransferFrom` function (i.e., the sender).
     * @param from The address which previously owned the token.
     * @param id The Id of the ERC1155 token being transferred.
     * @param value The amount of tokens being transferred.
     * @param data Additional data with no specified format.
     * @return A bytes4 magic value, indicating ERC1155Receiver compatibility.
     *  See {IERC1155-onERC1155Received}.
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev Handles the receipt of a batch of ERC1155 tokens when they are transferred to this contract.
     * @param operator The address which called `safeBatchTransferFrom` function (i.e., the sender).
     * @param from The address which previously owned the tokens.
     * @param ids An array of Ids for the ERC1155 tokens being transferred.
     * @param values An array of amounts corresponding to the tokens being transferred.
     * @param data Additional data with no specified format.
     * @return A bytes4 magic value, indicating ERC1155Receiver compatibility (0xbc197c81).
     *  See {IERC1155-onERC1155BatchReceived}.
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev See {IERC165Upgradeable-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId ||
            interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev Withdraws a specified amount of LRT tokens to the treasury.
     * @param _amount The amount of LRT tokens to withdraw.
     */
    function withdraw(uint256 _amount) external override onlyAdmin {
        // Ensure that the withdrawal amount is greater than zero.
        require(_amount > 0, "LootBox::Insufficient amount, equal to zero");

        // Check if the contract holds enough LRT tokens to perform the withdrawal.
        require(
            _lrt.balanceOf(address(this)) >= _amount,
            "LootBox::No balance to withdraw"
        );

        // Get the address of the treasury where the withdrawn LRT tokens will be sent.
        address treasury = _landrocker.treasury();

        // Attempt to transfer the specified amount of LRT tokens to the treasury.
        // Ensure that the transfer was successful; otherwise, revert the transaction.
        require(
            _lrt.transfer(treasury, _amount),
            "LootBox::Unsuccessful transfer"
        );
        emit Withdrawn(_amount, treasury);
    }

    /**
     * @dev Handles the purchase of a lootBox asset using LRT balance.
     * @param _sellId ID of the sell order.
     * @param _buyer Address of the buyer.
     * @param _sellOrder Details of the sell order for a lootBox asset.
     */
    function _processLootBokxPurchase(
        uint256 _sellId,
        address _buyer,
        LootBoxSell memory _sellOrder
    ) private {
        // Check if the buyer has approved an allowance of LRT tokens for this contract
        require(
            _lrt.allowance(_buyer, address(this)) >= _sellOrder.price,
            "LootBox::Allowance error"
        );

        // Transfer LRT tokens from the buyer to the marketplace
        require(
            _lrt.transferFrom(_buyer, address(this), _sellOrder.price),
            "LootBox::Unsuccessful transfer"
        );

        // Emit an event indicating a successful lootBox purchase
        emit LootBoxBoughtWithBalance(
            _sellId,
            msg.sender,
            _sellOrder.sellUnit,
            _sellOrder.price
        );
    }

    /**
     * @dev Handles the purchase of a lootBox asset using vested LRT balance.
     * @param _sellId ID of the sell order.
     * @param _buyer Address of the buyer.
     * @param _sellOrder Details of the sell order for a lootBox asset.
     */
    function _processVestingPurchase(
        uint256 _sellId,
        address _buyer,
        LootBoxSell memory _sellOrder
    ) private {
        console.log("_processVestingPurchase");
        // Get the vested and claimed amounts from the vesting contract
        (, uint256 vestedAmount, uint256 claimedAmount) = _lrtVesting
            .holdersStat(_buyer);

        // Ensure that the buyer has enough vested balance
        require(
            claimedAmount + _sellOrder.price <= vestedAmount,
            "LootBox::Insufficient vested balance"
        );

        // Emit an event indicating a successful lootBox purchase
        emit LootBoxBoughtWithVesting(
            _sellId,
            _buyer,
            _sellOrder.sellUnit,
            _sellOrder.price
        );

        _lrtVesting.setDebt(_buyer, _sellOrder.price);
    }

    /**
     * @dev Validates the parameters for creating or editing a lootBox asset sell order.
     * @param _listedAmount The total amount of the asset listed for sale.
     * @param _sellUnit The unit of the asset being sold in each transaction.
     */
    function _validateSell(
        uint256 _listedAmount,
        uint256 _sellUnit
    ) private view {
        // Ensure that lootBox does not exceed the capacity
        require(
            totalCreatedLootBox + _listedAmount <= lootBoxCapacity,
            "LootBox::LootBox exceed capacity"
        );

        // Ensure that there are items to sell (listed amount is greater than zero)
        require(_listedAmount > 0, "LootBox::There are not any item to sell");
        // Ensure that at least one item is being sold (sell unit is greater than zero)
        require(_sellUnit > 0, "LootBox::At least one item to sell");
        // Ensure that the listed amount is greater than or equal to the sell unit
        require(
            _listedAmount >= _sellUnit,
            "LootBox::Sell unit is larger than listed amount"
        );
        // Ensure that the listed amount is a multiple of the sell unit (divisible without remainder)
        require(
            _listedAmount % _sellUnit == 0,
            "LootBox::Listed amount is not a coefficient of sell unit"
        );
    }

    /**
     * @dev Authorizes a contract upgrade.
     * @param newImplementation The address of the new contract implementation.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
