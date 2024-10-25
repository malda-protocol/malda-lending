// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IZkVerifierImageRegistry} from "../interfaces/IZkVerifierImageRegistry.sol";

// contracts
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ZkVerifierImageRegistry is Ownable, IZkVerifierImageRegistry {
    // ----------- STORAGE ------------
    /**
     * @notice Returns whitelist state for an image id
     */
    mapping(bytes32 => bool) public override isActive;
    /**
     * @notice Returns index array for image id
     */
    mapping(bytes32 => uint256) public override imageIndex;
    /**
     * @notice Array for registered image ids
     */
    bytes32[] public imageIds;

    // ----------- EVENTS ------------
    event ImageAdded(bytes32 imageId, uint256 index);

    // ----------- ERRORS ------------
    error ZkVerifierImagesRegistry_AlredyRegistered();

    constructor(address _owner) Ownable(_owner) {}

    // ----------- VIEW ------------
    /**
     * @inheritdoc IZkVerifierImageRegistry
     */
    function getImageForIndex(uint256 _index) external view override returns (bytes32) {
        return imageIds[_index];
    }

    // ----------- OWNER ------------
    /**
     * @notice Registers a new image id
     * @param _newImageId the new bytes32 verification image id
     */
    function addImageId(bytes32 _newImageId) external onlyOwner {
        require(!isActive[_newImageId] && imageIndex[_newImageId] == 0, ZkVerifierImagesRegistry_AlredyRegistered());
        isActive[_newImageId] = true;
        imageIds.push(_newImageId);
        imageIndex[_newImageId] = imageIds.length - 1;
        emit ImageAdded(_newImageId, imageIds.length - 1);
    }

    /**
     * @notice Disables existing image id
     * @param _imageId the existing bytes32 verification image id
     */
    function disableImageId(bytes32 _imageId) external onlyOwner {
        isActive[_imageId] = false;
        imageIndex[_imageId] = 0;
    }
}
