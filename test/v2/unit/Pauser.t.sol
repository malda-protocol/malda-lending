// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Pauser_constructor as LegacyPauserConstructor} from "test/unit/Pauser/Pauser_constructor.t.sol";
import {Pauser_pause as LegacyPauserPause} from "test/unit/Pauser/Pauser_pause.t.sol";
import {
    Pauser_addPausableMarket as LegacyPauserAddPausableMarket
} from "test/unit/Pauser/Pauser_addPausableMarket.t.sol";
import {
    Pauser_removePausableMarket as LegacyPauserRemovePausableMarket
} from "test/unit/Pauser/Pauser_removePausableMarket.t.sol";

contract PauserConstructorV2 is LegacyPauserConstructor {}

contract PauserPauseV2 is LegacyPauserPause {}

contract PauserAddPausableMarketV2 is LegacyPauserAddPausableMarket {}

contract PauserRemovePausableMarketV2 is LegacyPauserRemovePausableMarket {}
