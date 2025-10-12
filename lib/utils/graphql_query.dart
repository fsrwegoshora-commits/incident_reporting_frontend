const String registerMutation = """
mutation RegisterUser(\$phone: String!, \$name: String!) {
  userRegistration(userDto: {
    phoneNumber: \$phone,
    name: \$name
  }) {
    status
    message
    data {
      uid
      name
      phoneNumber
      role
    }
  }
}
""";

// Request OTP
const String requestOtpMutation = """
mutation RequestOtp(\$phone: String!) {
  requestOtp(phoneNumber: \$phone) {
    status
    message
    data
  }
}
""";

const String validateTokenQuery = r'''
query ValidateToken($token: String!) {
  validateToken(token: $token) {
    status
    message
    data
  }
}
''';

// Verify OTP (Updated)
const String verifyOtpMutation = """
mutation VerifyOtp(\$phone: String!, \$code: String!) {
  verifyOtp(phoneNumber: \$phone, code: \$code) {
    message
    data
  }
}
""";

const String meQuery = """
query {
  me {
    message
    data {
      uid
      name
      phoneNumber
      role
      stationUid
      stationName
      badgeNumber
      rank
      isOnDuty
      officerUid  
      currentShift {
        uid
        shiftDate
        startTime
        endTime
        shiftType
        dutyDescription
        isExcused
        excuseReason
        isPunishmentMode
        isReassigned
        reassignedFromUid
      }
    }
  }
}
""";

const String registerSpecialUserMutation = """
mutation RegisterSpecialUser(\$userDto: UserDtoInput!) {
  registerSpecialUser(userDto: \$userDto) {
    status
    message
    data {
      uid
      phoneNumber
      role
    }
  }
}
""";
const String getUsersQuery = '''
  query GetUsers(\$pageableParam: PageableParamInput) {
    getUsers(pageableParam: \$pageableParam) {
      data {
        uid
        name
        phoneNumber
        role
        station {
          name
        }
      }
      elements
      pages
      size
      page
    }
  }
''';

// Add this schema definition
const String pageableParamInput = '''
  input PageableParamInput {
    sortBy: String
    sortDirection: String  # Changed from enum to String to match Java
    size: Int
    page: Int
    searchParam: String
    isActive: Boolean
  }
''';

const String deleteUserMutation = """
mutation DeleteUser(\$uid: String!) {
  deleteUser(uid: \$uid) {
    status
    message
  }
}
""";

// In graphql_query.dart

const String deleteMyAccountMutation = """
  mutation DeleteMyAccount {
    deleteMyAccount {
      status
      message
      data {
        uid
        phoneNumber
        name
      }
    }
  }
""";

const String getUserMutation = """
query getUser(\$uid: String!) {
  getUser(uid: \$uid) {
    status
    message
    data {
      uid
      name
      phoneNumber
      role
      station {
        name
      }
    }
  }
}
""";

const String getSpecialUsersQuery = """
query GetSpecialUsers(\$role: Role) {
  getSpecialUsers(role: \$role) {
    status
    message
    data {
      uid
      name
      phoneNumber
      role
      station {
        uid
        name
      }
    }
  }
}
""";


//======================= POLICE STATION QUERY ====================

const String savePoliceStationMutation = """
mutation SavePoliceStation(\$policeStationDto: PoliceStationDtoInput!) {
  savePoliceStation(policeStationDto: \$policeStationDto) {
    status
    message
    data {
      uid
      name
      contactInfo
      policeStationLocation {
        id
        name
        label
      }
      location {
        latitude
        longitude
        address
      }
    }
  }
}
""";

const String getStationsByAdminQuery = r'''
  query GetStationsByAdmin {
    getStationsByAdmin {
      status
      message
      data {
        uid
        name
      }
    }
  }
''';
const String getPoliceStationsQueryMutation = """
query GetPoliceStations(\$pageableParam: PageableParamInput) {
  getPoliceStations(pageableParam: \$pageableParam) {
    data {
      uid
      name
      contactInfo
      policeStationLocation {
        id
        name
        label
      }
      location { 
        latitude
        longitude
        address
      }
    }
    elements
    pages
    size
    page
  }
}
""";
const String deletePoliceStationMutation = """
mutation DeletePoliceStation(\$uid: String!) {
  deletePoliceStation(uid: \$uid) {
    status
    message
  }
}
""";

const String getPoliceStationMutation = """
query GetPoliceStation(\$uid: String!) {
  getPoliceStation(uid: \$uid) {
    status
    message
    data {
      uid
      name
      contactInfo
      policeStationLocation {
        id
        name
        label
      }
      location { 
        latitude
        longitude
        address
      }
    }
  }
}
""";


const String getNearbyPoliceStationsQuery = '''
  query GetNearbyPoliceStations(\$latitude: Float!, \$longitude: Float!, \$maxDistance: Float!) {
    getNearbyPoliceStations(
      latitude: \$latitude
      longitude: \$longitude
      maxDistance: \$maxDistance
    ) {
      data {
        uid
        name
        contactInfo
        temporaryDistance
        location {
          latitude
          longitude
        }
      }
    }
  }
''';



//=========== POLICE OFFICE QUERY============

const String savePoliceOfficerMutation = """
mutation SavePoliceOfficer(\$policeOfficerDto: PoliceOfficerDtoInput!) {
  savePoliceOfficer(policeOfficerDto: \$policeOfficerDto) {
    status
    message
    data {
      uid
      badgeNumber
      code
      station {
        uid
        name
      }
      userAccount {
        uid
        name
        phoneNumber
      }
    }
  }
}
""";
const String getPoliceOfficerQuery = """
query GetPoliceOfficer(\$uid: String!) {
  getPoliceOfficer(uid: \$uid) {
    status
    message
    data {
      uid
      badgeNumber
      code
      station {
        uid
        name
      }
      userAccount {
        uid
        name
        phoneNumber
      }
    }
  }
}
""";

const String deletePoliceOfficerMutation = """
mutation DeletePoliceOfficer(\$uid: String!) {
  deletePoliceOfficer(uid: \$uid) {
    status
    message
  }
}
""";

String getPoliceOfficersQuery = """
  query GetPoliceOfficers(\$pageableParam: PageableParamInput) {
    getPoliceOfficers(pageableParam: \$pageableParam) {
      data {
        uid
        badgeNumber
        code
        userAccount {
          uid
          name
          phoneNumber
        }
        station {
          uid
          name
        }
      }
      elements
      pages
      size
      page
    }
  }
""";

const String getPoliceOfficersByStationQuery = r'''
query GetPoliceOfficersByStation($pageableParam: PageableParamInput, $policeStationUid: String!) {
  getPoliceOfficersByStation(pageableParam: $pageableParam, policeStationUid: $policeStationUid) {
    data {
      uid
      badgeNumber
      code
      userAccount {
        uid
        name
        phoneNumber
      }
      station {
        uid
        name
      }
    }
    page
    size
    pages
    elements
  }
}
''';

//======================= officer shift QUERY ====================

const String saveShiftMutation = """
mutation SaveShift(\$dto: OfficerShiftDtoInput!) {
  saveShift(policeOfficerDto: \$dto) {
    status
    message
    data {
      uid
      shiftDate
      shiftType
      startTime
      endTime
      dutyDescription
      isPunishmentMode
      officer {
        uid
        badgeNumber
        userAccount {
          name
        } 
      }
    }
  }
}
""";

const String excuseShiftMutation = """
mutation ExcuseShift(\$uid: String!, \$reason: String!) {
  excuseShift(policeOfficerDto: \$uid, reason: \$reason) {
    status
    message
    data {
      uid
      isExcused
      excuseReason
    }
  }
}
""";

const String reassignShiftMutation = """
mutation ReassignShift(\$uid: String!, \$newOfficerUid: String!) {
  reassignShift(policeOfficerDto: \$uid, newOfficerUid: \$newOfficerUid) {
    status
    message
    data {
      uid
      shiftDate
      shiftType
      startTime
      endTime
      dutyDescription
      isPunishmentMode
      officer {
        uid
        badgeNumber
        userAccount {
          name
          phoneNumber
        }
      }
    }
  }
}
""";

const String getAvailableOfficersQuery = """
query GetAvailableOfficers(\$date: LocalDate!) {
  getAvailableOfficersForDate(date: \$date) {
    status
    message
    data {
      uid
      badgeNumber
      userAccount {
        name
        phoneNumber
      }
    }
  }
}
""";

const String getAvailableOfficersForSlotQuery = """
query GetAvailableOfficersForSlot(\$date: String!, \$startTime: String!, \$endTime: String!) {
  getAvailableOfficersForSlot(date: \$date, startTime: \$startTime, endTime: \$endTime) {
    status
    message
    data {
      uid
      badgeNumber
      userAccount {
        name
        phoneNumber
      }
    }
  }
}

""";


const String getShiftsByStationQuery = """
query GetShiftsByStation(\$stationUid: String!, \$page: Int!, \$size: Int!) {
  getShiftsByStation(policeStationUid: \$stationUid, pageableParam: {page: \$page, size: \$size}) {
    status
    message
    data {
      uid
      shiftDate
      shiftType
      startTime
      endTime
      dutyDescription
      isExcused
      excuseReason
      isPunishmentMode
      officer {
        uid
        badgeNumber
        userAccount {
          name
          phoneNumber
        }
      }
    }
  }
}
""";


const String getShiftsByOfficerQuery = """
query GetShiftsByPoliceOfficer(\$officerUid: String!, \$page: Int!, \$size: Int!) {
  getShiftsByPoliceOfficer(policeOfficerUid: \$officerUid, pageableParam: {page: \$page, size: \$size}) {
    status
    message
    data {
      uid
      shiftDate
      shiftType
      dutyDescription
      isExcused
      excuseReason
      isPunishmentMode
    }
  }
}
""";

const String deleteOfficerShiftMutation = """
mutation DeleteOfficerShift(\$uid: String!) {
  deleteOfficerShift(uid: \$uid) {
    status
    message
    data {
      uid
    }
  }
}
""";

const String getPoliceOfficerShiftsQuery = """
query GetPoliceOfficerShifts(\$page: Int!, \$size: Int!) {
  getPoliceOfficerShifts(pageableParam: {page: \$page, size: \$size}) {
    status
    message
    data {
      uid
      shiftDate
      shiftType
      isExcused
      dutyDescription
      excuseReason
      isPunishmentMode
      officer {
        uid
        badgeNumber
         userAccount {
          name
          phoneNumber
        }
      }
    }
  }
}
""";

const String getPoliceOfficerShiftQuery = """
query GetPoliceOfficerShift(\$uid: String!) {
  getPoliceOfficerShift(uid: \$uid) {
    status
    message
    data {
      uid
      shiftDate
      shiftType
      dutyDescription
      isExcused
      excuseReason
      isPunishmentMode
      officer {
        uid
        badgeNumber
        userAccount {
          name
          phoneNumber
        }
      }
    }
  }
}
""";

//============================Admin query==============================

const String getAdministrativeAreasQuery = """
query GetAdministrativeAreas(\$pageableParam: PageableParamInput!, \$areaLevels: [AdministrativeAreaLevel!]) {
  getAdministrativeAreas(pageableParam: \$pageableParam, areaLevels: \$areaLevels) {
    data {
      uid
      name
      label
      areaType {
        uid
        name
        areaLevel {
          level
          name
        }
      }
      parentAreaId
    }
    page
    size
    pages
    elements
  }
}
""";

// const String pageableParamInput = """
// input PageableParamInput {
//   page: Int!
//   size: Int!
//   key: String
// }
// """;

const String getAreaTypesQuery = """
query GetAreaTypes(\$page: Int!, \$size: Int!, \$areaLevels: [AdministrativeAreaLevel!]) {
  getAreaTypes(pageableParam: {page: \$page, size: \$size}, areaLevels: \$areaLevels) {
    data {
      uid
      name
      level
    }
    page
    size
    pages
    elements
  }
}
""";


