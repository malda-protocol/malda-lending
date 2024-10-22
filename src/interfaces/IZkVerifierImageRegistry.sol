// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IZkVerifierImageRegistry {
    /**
     * @notice Returns bytes32 image by index
     * @param _index the array index
     */
    function getImageForIndex(uint256 _index) external view returns (bytes32);
    /**
     * @notice Returns whitelist state for an image id
     * @param _imageId the bytes32 image id
     */
    function isActive(bytes32 _imageId) external view returns (bool);

    /**
     * @notice Returns index array for image id
     * @param _imageId the bytes32 image id
     */
    function imageIndex(bytes32 _imageId) external view returns (uint256);
}
