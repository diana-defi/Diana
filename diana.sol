/************
*
 * 
  * 
   *
    *                                                                                                  
           ,,    ,,                                
         `7MM    db                                
           MM                                      
      ,M""bMM  `7MM   ,6"Yb.  `7MMpMMMb.   ,6"Yb.  
    ,AP    MM    MM  8)   MM    MM    MM  8)   MM  
    8MI    MM    MM   ,pm9MM    MM    MM   ,pm9MM  
    `Mb    MM    MM  8M   MM    MM    MM  8M   MM  
     `Wbmd"MML..JMML.`Moo9^Yo..JMML  JMML.`Moo9^Yo.
 
    *
   * 
  * 
 * 
* 
************/


pragma solidity 0.5.11;

contract Diana {
    
    struct User {
        uint id;
        address referrer;
        uint partnersCount;
        mapping(uint8 => bool) activeX3Levels;
        mapping(uint8 => X3) x3Matrix;
    }
    
    struct X3 {
        address currentReferrer;
        address[] referrals;
        bool blocked;
        uint reinvestCount;
        uint repeat;
    }

    uint8 public constant LAST_LEVEL = 8;
    
    mapping(address => User) public users;
    mapping(uint => address) public idToAddress;
    mapping(uint => address) public userIds;
    mapping(address => uint) public balances; 

    uint public lastUserId = 2;
    address public owner;
    address public bonus;
    address public power;

    
    mapping(uint8 => uint) public levelPrice;
    
    event Registration(address indexed user, address indexed referrer, uint indexed userId, uint referrerId);
    event Reinvest(address indexed user, address indexed currentReferrer, address indexed caller, uint8 level);
    event Upgrade(address indexed user, address indexed referrer, uint8 level);
    event NewUserPlace(address indexed user, address indexed referrer, uint8 level, uint8 place);
    event MissedReceive(address indexed receiver, address indexed from, uint8 indexed level);
    event SentDividends(address indexed from, address indexed receiver, uint8 indexed level,bool isExtra);
    
    
    constructor(address ownerAddress,address bonusAddress,address powerAddress) public {
        levelPrice[1] = 100 ether;
        for (uint8 i = 2; i <= LAST_LEVEL; i++) {
            levelPrice[i] = levelPrice[i-1] * 2;
        }
        
        owner = ownerAddress;
        bonus = bonusAddress;
        power = powerAddress;
        
        User memory user = User({
            id: 1,
            referrer: address(0),
            partnersCount: uint(0)
        });
        
        users[ownerAddress] = user;
        idToAddress[1] = ownerAddress;
        
        for (uint8 i = 1; i <= LAST_LEVEL; i++) {
            users[ownerAddress].activeX3Levels[i] = true;
        }
        
        userIds[1] = ownerAddress;
    }
    

    function registrationExt(address referrerAddress) external payable returns(bool){
        registration(msg.sender, referrerAddress);
        return true;
    }
    
    function buyNewLevel(uint8 level) external payable returns(bool){
        require(isUserExists(msg.sender), "user is not exists. Register first.");
        require(msg.value == levelPrice[level], "invalid price");
        require(level > 1 && level <= LAST_LEVEL, "invalid level");

        require(!users[msg.sender].activeX3Levels[level], "level already activated");
        require(users[msg.sender].activeX3Levels[level - 1], "last level did not activated");

        if (users[msg.sender].x3Matrix[level-1].blocked) {
            users[msg.sender].x3Matrix[level-1].blocked = false;
        }     
    
        address freeX3Referrer = findFreeX3Referrer(msg.sender, level);
        users[msg.sender].x3Matrix[level].currentReferrer = freeX3Referrer;
        users[msg.sender].activeX3Levels[level] = true;
        updateX3Referrer(msg.sender, freeX3Referrer, level);
            
        emit Upgrade(msg.sender, freeX3Referrer, level);
        return true;
    }    
    
    function registration(address userAddress, address referrerAddress) private {
        require(msg.value == 100 ether, "registration cost 100");
        require(!isUserExists(userAddress), "user exists");
        require(isUserExists(referrerAddress), "referrer not exists");
        
        uint32 size;
        assembly {
            size := extcodesize(userAddress)
        }
        require(size == 0, "cannot be a contract");
        
        User memory user = User({
            id: lastUserId,
            referrer: referrerAddress,
            partnersCount: 0
        });
        
        users[userAddress] = user;
        idToAddress[lastUserId] = userAddress;
        
        users[userAddress].referrer = referrerAddress;
        
        users[userAddress].activeX3Levels[1] = true; 
        
        userIds[lastUserId] = userAddress;
        lastUserId++;
        
        users[referrerAddress].partnersCount++;

        address freeX3Referrer = findFreeX3Referrer(userAddress, 1);
        users[userAddress].x3Matrix[1].currentReferrer = freeX3Referrer;
        updateX3Referrer(userAddress, freeX3Referrer, 1);
        
        emit Registration(userAddress, referrerAddress, users[userAddress].id, users[referrerAddress].id);
    }
    
    
    function updateX3Referrer(address userAddress, address referrerAddress, uint8 level) private {
        users[referrerAddress].x3Matrix[level].referrals.push(userAddress);

        
        if (users[referrerAddress].x3Matrix[level].referrals.length < 3) {
            emit NewUserPlace(userAddress, referrerAddress, level, uint8(users[referrerAddress].x3Matrix[level].referrals.length));
            return sendDividends(referrerAddress, userAddress, level);
        }
        
        emit NewUserPlace(userAddress, referrerAddress, level, 3);
        //close matrix
        users[referrerAddress].x3Matrix[level].repeat++;
        users[referrerAddress].x3Matrix[level].referrals = new address[](0);
        if (users[referrerAddress].x3Matrix[level].repeat == 2 && !users[referrerAddress].activeX3Levels[level+1] && level != LAST_LEVEL) {
            users[referrerAddress].x3Matrix[level].blocked = true;
        }

        //create new one by recursion
        if (referrerAddress != owner) {
            //check referrer active level
            address freeReferrerAddress = findFreeX3Referrer(referrerAddress, level);
            if (users[referrerAddress].x3Matrix[level].currentReferrer != freeReferrerAddress) {
                users[referrerAddress].x3Matrix[level].currentReferrer = freeReferrerAddress;
            }
            
            users[referrerAddress].x3Matrix[level].reinvestCount++;
            emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, level);
            updateX3Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
             // destory
            uint256 amount = levelPrice[level] / 100;
            
            address(uint160(bonus)).transfer(amount * 30);
            address(uint160(power)).transfer(amount * 10);
            address(0).transfer(amount * 60);
            
            emit SentDividends(msg.sender, address(0), level,true);
        }
    }

    
    function findFreeX3Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (users[users[userAddress].referrer].activeX3Levels[level]) {
                return users[userAddress].referrer;
            }
            
            userAddress = users[userAddress].referrer;
        }
    }
    
    
        
    function usersActiveX3Levels(address userAddress, uint8 level) public view returns(bool) {
        return users[userAddress].activeX3Levels[level];
    }

    function usersX3Matrix(address userAddress, uint8 level) public view returns(address, address[] memory, bool,uint) {
        return (users[userAddress].x3Matrix[level].currentReferrer,
                users[userAddress].x3Matrix[level].referrals,
                users[userAddress].x3Matrix[level].blocked,
                users[userAddress].x3Matrix[level].repeat);
    }
    
    function isUserExists(address user) public view returns (bool) {
        return (users[user].id != 0);
    }

    function findReceiver(address userAddress, address _from, uint8 level) private returns(address, bool) {
        address receiver = userAddress;
        bool isExtraDividends;
        
        while (true) {
            if (users[receiver].x3Matrix[level].blocked) {
                emit MissedReceive(receiver, _from, level);
                isExtraDividends = true;
                receiver = users[receiver].x3Matrix[level].currentReferrer;
            } else {
                return (receiver, isExtraDividends);
            }
        }
    }

    function sendDividends(address userAddress, address _from, uint8 level) private {
        
        (address receiver, bool isExtraDividends) = findReceiver(userAddress, _from, level);
        
        uint256 amount = levelPrice[level] / 100;
        address(uint160(receiver)).transfer(amount * 50);
        address(uint160(bonus)).transfer(amount * 30);
        address(uint160(power)).transfer(amount * 10);
        address(0).transfer(amount * 10);
        
        emit SentDividends(msg.sender, receiver, level,isExtraDividends);
    }
}