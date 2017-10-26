pragma solidity ^0.4.4;

import "./SortLib.sol";

contract SingleHouse {
  
  // one contract is associated to one particular House in the network.

  address Admin;                    // shall be defined at the creation of contract or to be defined manually
  address public Address;
  bytes32 public name;              // name of the device (Serie No.)
  uint    consumption;              // Production of electricity (consumption: positive)
  uint    consumStatusAt;           // timestamp of the update (consumption)
  uint    consumTimeOut = 5 minutes;
  address[] connectedPV;            // List of PV connected
  address[] connectedBattery;       // List of batteries connected

  // ==== may be splited into another contract

  using SortLib for SortLib.PriceTF[];

  SortLib.PriceTF[] prepPriceQueryInfo;
  //SortLib.PriceTF[] sortedPriceQueryInfo;

  uint    lastPriceQueryAt;

  /*struct PriceTF {
    uint  prs;
    bool  updated;
  }*/

  mapping(address=>SortLib.PriceTF) priceQueryInfo;
  mapping(uint=>address) sortedPriceQueryInfo;
  
// ====
  
  modifier ownerOnly {
    if (msg.sender == Address) {
      _;
    } else {
      revert();
    }
  }

  modifier adminOnly {
    if (msg.sender == Admin) {
      _;
    } else {
      revert();
    }
  }

  modifier connectedPVOnly (address adrP) {
    var check = false;
    for (uint i = 0; i < connectedPV.length; i++) {
      if (msg.sender == connectedPV[i]) {
        check = true;
      }
    }
    if (check == true) {
      _;
    } else {
      revert();
    }
  }

  modifier connectedBatteryOnly (address adrB) {
    var check = false;
    for (uint i = 0; i < connectedBattery.length; i++) {
      if (msg.sender == connectedBattery[i]) {
        check = true;
      }
    }
    if (check == true) {
      _;
    } else {
      revert();
    }
  }

  modifier timed (uint initialTime, uint allowedTimeOut) {
    if(now < initialTime + allowedTimeOut) {
      _;
    } else {
      revert();
    }
  }

  event ConsumptionLog(address adr, uint consum, uint consumAt);
  event ConfigurationLog(string confMod, uint statusAt);

  function SingleHouse (address adr, address adm) {
    // constructor
    Address = adr;
    Admin = adm;
  }

  function setConsumption(uint consum) ownerOnly {
    consumption = consum;
    consumStatusAt = now;
    ConsumptionLog(Address, consumption, consumStatusAt);
  }

  function addConnectedPV(address adrP) adminOnly external {
    connectedPV.push(adrP);
    ConfigurationLog("PV Added",now);
  }

  function deleteConnectedPV(address adrP) adminOnly external returns (bool) {
    for (uint i = 0; i < connectedPV.length; i++) {
      if (adrP == connectedPV[i]) {
        delete connectedPV[i];
        if (i != connectedPV.length-1) {
          connectedPV[i] = connectedPV[connectedPV.length-1];
        }
        connectedPV.length--;
        ConfigurationLog("PV Deleted",now);
        return true;
      }
    }
    return false;
  }

  function addConnectedBattery(address adrB) adminOnly external {
    connectedBattery.push(adrB);
    ConfigurationLog("Battery Added",now);
  }

  function deleteConnectedBattery(address adrB) adminOnly external returns (bool) {
    for (uint i = 0; i < connectedBattery.length; i++) {
      if (adrB == connectedBattery[i]) {
        delete connectedBattery[i];
        if (i != connectedBattery.length-1) {
          connectedBattery[i] = connectedBattery[connectedBattery.length-1];
        }
        connectedBattery.length--;
        ConfigurationLog("Battery Deleted",now);
        return true;
      }
    }
    return false;
  }

  function getConsumption(uint initTime) timed(initTime,consumTimeOut) external returns (uint consum, uint consumAt) {
    consum = consumption;
    consumAt = consumStatusAt;
  }

  /*function getPVPrice(address deviceAdr) returns (uint, bool, address) {
      return deviceAdr.call(bytes4(sha3("getPrice(uint)")),lastPriceQueryAt);
  }*/

  function getConnectedPVCount() returns (uint){
    return connectedPV.length;
  }

  function getconnectedBatteryCount() returns (uint){
    return connectedBattery.length;
  }

  function getConnectPVAddress(uint a) returns (address) {
    if (a<connectedPV.length) {
      return connectedPV[a];
    } else {
      return 0x0;
    }
  }

  function getconnectedBatteryAddress(uint a) returns (address) {
    if (a<connectedBattery.length) {
      return connectedBattery[a];
    } else {
      return 0x0;
    }
  }

  function setPriceQueryInfo(address adr, uint prs, bool tf) {
    require(assertInConnectedPV(adr) || assertInConnectedBattery(adr));
    SortLib.PriceTF memory tempPriceTF;
    tempPriceTF.prs = prs;
    tempPriceTF.updated = tf;
    priceQueryInfo[adr] = tempPriceTF;
  }

  function assertInConnectedPV(address adr) returns (bool) {
    for (uint i = 0; i < connectedPV.length; i++) {
      if (adr == connectedPV[i]) {
        return true;
      }
    }
    return false;
  }
  
  function assertInConnectedBattery(address adr) returns (bool) {
    for (uint i = 0; i < connectedBattery.length; i++) {
      if (adr == connectedBattery[i]) {
        return true;
      }
    }
    return false;
  }

  //------------------------------
  // to Sort the received list of Price (from PV and Battery)
  //------------------------------

  function sortPriceList() {
    createPriceList();
    uint maxTemp;
    uint totalLength = connectedPV.length + connectedBattery.length;
    for (uint i=0; i<totalLength; i++) {
      maxTemp = prepPriceQueryInfo.maxStruct();
      swap(totalLength-1-i,i);
      del(maxTemp);
    }
  }

  function createPriceList() private {
    prepPriceQueryInfo.length = connectedPV.length + connectedBattery.length;
    //sortedPriceQueryInfo.length = prepPriceQueryInfo.length; => sortedPQI is using mapping now
    for (uint i = 0; i < connectedPV.length; i++) {
      prepPriceQueryInfo[i] = priceQueryInfo[connectedPV[i]];
      sortedPriceQueryInfo[i] = connectedPV[i];
    }
    for (i = connectedPV.length; i < prepPriceQueryInfo.length; i++) {
      prepPriceQueryInfo[i] = priceQueryInfo[connectedBattery[i-connectedPV.length]];
      sortedPriceQueryInfo[i] = connectedBattery[i-connectedPV.length];
    }
  }

  function del (uint _id) private {
    if (_id != prepPriceQueryInfo.length) {
      delete prepPriceQueryInfo[_id];
      prepPriceQueryInfo[_id] = prepPriceQueryInfo[prepPriceQueryInfo.length-1];
      prepPriceQueryInfo.length--;
    } else {
      delete prepPriceQueryInfo[_id];
      prepPriceQueryInfo.length--;
    }
  }

  function swap (uint _id1, uint _id2) private {
    if (_id1 != _id2) {
      address temp;
      temp = sortedPriceQueryInfo[_id1];
      sortedPriceQueryInfo[_id1] = sortedPriceQueryInfo[_id2];
      sortedPriceQueryInfo[_id2] = temp;   
    }
  }

  // ------------------------------

  
  

}
