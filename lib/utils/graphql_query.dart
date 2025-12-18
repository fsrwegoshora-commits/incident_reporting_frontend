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
          officerUid
          shiftDate
          startTime
          endTime
          shiftTime
          shiftDutyType
          dutyDescription
          isExcused
          excuseReason
          isPunishmentMode
          isReassigned
          checkpointUid
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
      department{
        uid
        name
        type
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
      department{
        uid
        name
        type
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
        department{
        uid
        name
        type
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
      department{
        uid
        name
        type
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
        shiftTime
        shiftDutyType
        startTime
        endTime
        dutyDescription
        isPunishmentMode
        isExcused
        isReassigned
        officer {
          uid
          badgeNumber
          userAccount {
            name
          }
        }
        checkpoint {
          uid
          name
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
        shiftTime
        shiftDutyType
        startTime
        endTime
        dutyDescription
        isPunishmentMode
        isExcused
        isReassigned
        officer {
          uid
          badgeNumber
          userAccount {
            name
          }
        }
        checkpoint {
          uid
          name
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
query GetShiftsByStation(\$policeStationUid: String!, \$pageableParam: PageableParamInput!) {
  getShiftsByStation(policeStationUid: \$policeStationUid, pageableParam: \$pageableParam) {
    data {
      uid
      shiftDate
      shiftTime
      shiftDutyType
      startTime
      endTime
      dutyDescription
      isPunishmentMode
      isExcused
      excuseReason
      isReassigned
      officer {
        uid
        badgeNumber
        userAccount {
          uid
          name
          phoneNumber
        }
      }
      checkpoint {
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


const String getShiftsByOfficerQuery = """
query GetShiftsByPoliceOfficer(\$policeOfficerUid: String!, \$pageableParam: PageableParamInput!) {
  getShiftsByPoliceOfficer(policeOfficerUid: \$policeOfficerUid, pageableParam: \$pageableParam) {
    data {
      uid
      shiftDate
      shiftTime
      shiftDutyType
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
        }
      }
      checkpoint {
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
        shiftTime
        shiftDutyType
        startTime
        endTime
        dutyDescription
        isPunishmentMode
        isExcused
        isReassigned
        officer {
          uid
          badgeNumber
          userAccount {
            name
          }
        }
        checkpoint {
          uid
          name
        }
      }
  }
}
""";

// GraphQL Query - Get Police Officer Shifts by Checkpoint

const String getPoliceOfficerShiftsByCheckpointQuery = """
query GetPoliceOfficerShiftsByCheckpoint(\$pageableParam: PageableParamInput, \$checkpointUid: String!) {
  getPoliceOfficerShiftsByCheckpoint(pageableParam: \$pageableParam, checkpointUid: \$checkpointUid) {
    data {
      uid
      shiftDate
      shiftTime
      shiftDutyType
      startTime
      endTime
      dutyDescription
      isPunishmentMode
      isExcused
      isReassigned
      officer {
        uid
        badgeNumber
        userAccount {
          uid
          name
          phoneNumber
        }
      }
      checkpoint {
        uid
        name
        contactPhone
      }
    }
    elements
    pages
    size
    page
  }
}
""";

// Alternative version with full details
const String getPoliceOfficerShiftsByCheckpointDetailedQuery = """
query GetPoliceOfficerShiftsByCheckpoint(\$pageableParam: PageableParamInput, \$checkpointUid: String!) {
  getPoliceOfficerShiftsByCheckpoint(pageableParam: \$pageableParam, checkpointUid: \$checkpointUid) {
    data {
      uid
      shiftDate
      shiftTime
      shiftDutyType
      startTime
      endTime
      dutyDescription
      isPunishmentMode
      isExcused
      isReassigned
      officer {
        uid
        badgeNumber
        code
        userAccount {
          uid
          name
          phoneNumber
          email
        }
        station {
          uid
          name
        }
        department {
          uid
          name
        }
      }
      checkpoint {
        uid
        name
        contactPhone
        location {
          latitude
          longitude
          address
        }
      }
    }
    elements
    pages
    size
    page
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
          shiftTime
          shiftDutyType
          startTime
          endTime
          dutyDescription
          isPunishmentMode
          isExcused
          isReassigned
          officer {
            uid
            badgeNumber
            userAccount {
              name
            }
          }
          checkpoint {
            uid
            name
          }
   }
  }
}
""";

const String assignCheckpointShiftBulkMutation = """
mutation AssignCheckpointShiftBulk(\$bulkCheckpointShiftDto: BulkCheckpointShiftDtoInput!) {
  assignCheckpointShiftBulk(bulkCheckpointShiftDto: \$bulkCheckpointShiftDto) {
    status
    message
    data {
      uid
      officerUid
      shiftDate
      shiftTime
      shiftDutyType
      startTime
      endTime
      dutyDescription
      isPunishmentMode
      isExcused
      excuseReason
      isReassigned
      checkpointUid
      officer {
        uid
        badgeNumber
        userAccount {
          uid
          name
          phoneNumber
        }
      }
      checkpoint {
        uid
        name
      }
    }
  }
}
""";

const String getCheckpointShiftsByDateRangeQuery = """
query GetCheckpointShiftsByDateRange(
  \$checkpointUid: String!, 
  \$startDate: LocalDate!, 
  \$endDate: LocalDate!, 
  \$pageableParam: PageableParamInput
) {
  getCheckpointShiftsByDateRange(
    checkpointUid: \$checkpointUid, 
    startDate: \$startDate, 
    endDate: \$endDate, 
    pageableParam: \$pageableParam
  ) {
    data {
      uid
      officerUid
      shiftDate
      shiftTime
      shiftDutyType
      startTime
      endTime
      dutyDescription
      isPunishmentMode
      isExcused
      excuseReason
      isReassigned
      checkpointUid
      officer {
        uid
        badgeNumber
        userAccount {
          uid
          name
          phoneNumber
        }
      }
      checkpoint {
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

// ============================================================================
// INCIDENT MUTATIONS
// ============================================================================

const String createIncidentMutation = '''
  mutation CreateIncident(\$incidentDto: IncidentReportDtoInput!) {
    createIncident(incidentDto: \$incidentDto) {
      status
      message
      data {
        uid
        title
        description
        type
        location
        latitude
        longitude
        status
        reportedAt
        isLiveCallRequested
         assignedOfficer {
          uid
          badgeNumber
          code
          userAccount {
            name
            phoneNumber
          }
        }
        assignedStation {
          uid
          name
        }
      }
    }
  }
''';

const String updateIncidentMutation = '''
  mutation UpdateIncident(\$incidentDto: IncidentReportDtoInput!) {
    updateIncident(incidentDto: \$incidentDto) {
      status
      message
      data {
        uid
        title
        status
        resolvedAt
        assignedOfficer {
          uid
          userAccount {
            name
            phoneNumber
          }
        }
      }
    }
  }
''';

const String assignOfficerToIncidentMutation = '''
  mutation AssignOfficer(\$incidentUid: String!, \$officerUid: String!) {
    assignOfficerToIncident(incidentUid: \$incidentUid, officerUid: \$officerUid) {
      status
      message
      data {
        uid
        assignedOfficer {
          uid
          userAccount {
            name
          }
        }
      }
    }
  }
''';

const String deleteIncidentMutation = '''
  mutation DeleteIncident(\$uid: String!) {
    deleteIncident(uid: \$uid) {
      status
      message
    }
  }
''';

// ============================================================================
// INCIDENT QUERIES
// ============================================================================

const String getIncidentQuery = '''
  query GetIncident(\$uid: String!) {
    getIncident(uid: \$uid) {
      status
      message
      data {
        uid
        title
        description
        type
        location
        latitude
        longitude
        imageUrl
        audioUrl
        videoUrl
        status
        isLiveCallRequested
        reportedAt
        resolvedAt
        reportedBy {
          uid
          name
          phoneNumber
        }
        assignedStation {
          uid
          name
          contactInfo
        }
        assignedOfficer {
          uid
          userAccount {
            name
            phoneNumber
          }
          code
          badgeNumber
        }
      }
    }
  }
''';

const String getMyIncidentsQuery = '''
  query GetMyIncidents(\$pageableParam: PageableParamInput!) {
    getMyIncidents(pageableParam: \$pageableParam) {
      status
      message
      data {
          uid
          title
          type
          location
          status
          reportedAt
          assignedStation {
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

const String getStationIncidentsQuery = '''
  query GetStationIncidents(\$pageableParam: PageableParamInput!, \$status: IncidentStatus) {
    getStationIncidents(pageableParam: \$pageableParam, status: \$status) {
      status
      message
      data {     
          uid
          title
          type
          location
          status
          reportedAt
          reportedBy {
            name
            phoneNumber
          }
          assignedOfficer {
            userAccount {
              name
            }
          }
      }
        page
        size
        pages
        elements
      
    }
  }
''';

const String getOfficerIncidentsQuery = '''
  query GetOfficerIncidents(\$pageableParam: PageableParamInput!, \$status: IncidentStatus) {
    getOfficerIncidents(pageableParam: \$pageableParam, status: \$status) {
      status
      message
      data {
          uid
          title
          type
          location
          status
          reportedAt
          reportedBy {
            name
            phoneNumber
          }
          assignedOfficer {
            userAccount {
              name
            }
          }
        }
        page
        size
        pages
        elements
    }
  }
''';

const String getNearbyIncidentsQuery = '''
  query GetNearbyIncidents(\$latitude: Float!, \$longitude: Float!, \$radiusKm: Float, \$status: IncidentStatus) {
    getNearbyIncidents(latitude: \$latitude, longitude: \$longitude, radiusKm: \$radiusKm, status: \$status) {
      status
      message
      data {
        uid
        title
        type
        location
        latitude
        longitude
        status
        reportedAt
      }
    }
  }
''';

const String getIncidentStatsQuery = '''
  query GetIncidentStats(\$stationUid: String) {
    getIncidentStats(stationUid: \$stationUid) {
      status
      message
      data {
        pending
        inProgress
        resolved
        recentCount
      }
    }
  }
''';

/// ============================================================================
// CHAT MESSAGE MUTATIONS
// ============================================================================

const String sendChatMessageMutation = '''
  mutation SendChatMessage(\$chatMessageDto: ChatMessageDtoInput!) {
    sendChatMessage(chatMessageDto: \$chatMessageDto) {
      status
      message
      data {
        uid
        message
        messageType
        sentAt
        mediaUrl
        mediaFileName
        mediaFileSize
        mediaDuration
        mediaThumbnailUrl
        sender {
          uid
          name
          phoneNumber
        }
      }
    }
  }
''';

const String deleteChatMessageMutation = '''
  mutation DeleteChatMessage(\$uid: String!) {
    deleteChatMessage(uid: \$uid) {
      status
      message
    }
  }
''';

const String sendSystemMessageMutation = '''
  mutation SendSystemMessage(\$incidentUid: String!, \$message: String!) {
    sendSystemMessage(incidentUid: \$incidentUid, message: \$message) {
      status
      message
      data {
        uid
        message
        messageType
        sentAt
        mediaUrl
        mediaFileName
        mediaFileSize
        mediaDuration
        mediaThumbnailUrl
        sender {
          uid
          name
          phoneNumber
        }
      }
    }
  }
''';

const String markMessagesAsReadMutation = '''
  mutation MarkMessagesAsRead(\$incidentUid: String!) {
    markMessagesAsRead(incidentUid: \$incidentUid) {
      status
      message
      data
    }
  }
''';

// ============================================================================
// MEDIA UPLOAD MUTATION
// ============================================================================

const String uploadMediaMutation = '''
  mutation UploadMedia(\$base64File: String!, \$fileName: String!, \$mediaType: String!) {
    uploadMedia(base64File: \$base64File, fileName: \$fileName, mediaType: \$mediaType) {
      status
      message
      data {
        fileUrl
        fileName
        originalFileName
        fileSize
        mediaType
      }
    }
  }
''';


// ============================================================================
// CHAT MESSAGE QUERIES
// ============================================================================

const String getChatMessageQuery = '''
  query GetChatMessage(\$uid: String!) {
    getChatMessage(uid: \$uid) {
      status
      message
      data {
        uid
        message
        messageType
        sentAt
        mediaUrl
        mediaFileName
        mediaFileSize
        mediaDuration
        mediaThumbnailUrl
        sender {
          uid
          name
          phoneNumber
        }
      }
    }
  }
''';

const String getIncidentMessagesQuery = '''
  query GetIncidentMessages(\$incidentUid: String!, \$pageableParam: PageableParamInput!) {
    getIncidentMessages(incidentUid: \$incidentUid, pageableParam: \$pageableParam) {
      status
      message
      data {
        content {
          uid
          message
          messageType
          sentAt
          mediaUrl
          mediaFileName
          mediaFileSize
          mediaDuration
          mediaThumbnailUrl
          sender {
            uid
            name
            phoneNumber
          }
        }
        totalElements
        totalPages
        number
      }
    }
  }
''';

const String getAllIncidentMessagesQuery = '''
  query GetAllIncidentMessages(\$incidentUid: String!) {
    getAllIncidentMessages(incidentUid: \$incidentUid) {
      status
      message
      data {
        uid
        message
        messageType
        sentAt
        mediaUrl
        mediaFileName
        mediaFileSize
        mediaDuration
        mediaThumbnailUrl
        sender {
          uid
          name
          phoneNumber
        }
      }
    }
  }
''';

const String getUnreadMessageCountQuery = '''
  query GetUnreadMessageCount(\$incidentUid: String!) {
    getUnreadMessageCount(incidentUid: \$incidentUid) {
      status
      message
      data
    }
  }
''';
// ============================================================================
// OFFICER SHIFT QUERIES
// ============================================================================

const String getCurrentOfficerOnDutyQuery = '''
  query GetCurrentOfficerOnDuty(\$stationUid: String!) {
    getCurrentOfficerOnDuty(stationUid: \$stationUid) {
      status
      message
      data {
        uid
        shiftType
        shiftDate
        startTime
        endTime
        officer {
          uid
          badgeNumber
          code
          userAccount {
            uid
            name
            phoneNumber
          }
          station {
          name
          contactInfo
         }
        }
      }
    }
  }
''';

const String getAllOfficersOnDutyNowQuery = '''
  query GetAllOfficersOnDutyNow(\$stationUid: String) {
    getAllOfficersOnDutyNow(stationUid: \$stationUid) {
      status
      message
      data {
        uid
        shiftType
        shiftDate
        startTime
        endTime
        officer {
          uid
          badgeNumber
          code
          userAccount {
            name
            phoneNumber
          }
          station {
          name
         }
        } 
      }
    }
  }
''';

// ============================================================================
// AGENCY QUERIES
// ============================================================================

const String saveAgencyMutation = """
mutation SaveAgency(\$agencyDto: AgencyDtoInput!) {
  saveAgency(agencyDto: \$agencyDto) {
    status
    message
    data {
      uid
      name
      code
      description
    }
  }
}
""";

const String getAgencyQuery = """
query GetAgency(\$uid: String!) {
  getAgency(uid: \$uid) {
    status
    message
    data {
      uid
      name
      code
      description
    }
  }
}
""";

const String deleteAgencyMutation = """
mutation DeleteAgency(\$uid: String!) {
  deleteAgency(uid: \$uid) {
    status
    message
  }
}
""";

const String getAgenciesQuery = """
  query GetAgencies(\$pageableParam: PageableParamInput) {
    getAgencies(pageableParam: \$pageableParam) {
      data {
        uid
        name
        code
        description
      }
      elements
      pages
      size
      page
    }
  }
""";

// ============================================================================
// AGENCY QUERIES
// ============================================================================
const String saveDepartmentMutation = """
mutation SaveDepartment(\$departmentDto: DepartmentDtoInput!) {
  saveDepartment(departmentDto: \$departmentDto) {
    status
    message
    data {
      uid
      name
      type
      agency {
        uid
        name
        code
        description
      }
    }
  }
}
""";

const String getDepartmentQuery = """
query GetDepartment(\$uid: String!) {
  getDepartment(uid: \$uid) {
    status
    message
    data {
      uid
      name
      type
      agency {
        uid
        name
        code
        description
      }
    }
  }
}
""";

const String deleteDepartmentMutation = """
mutation DeleteDepartment(\$uid: String!) {
  deleteDepartment(uid: \$uid) {
    status
    message
  }
}
""";

const String getDepartmentsQuery = """
  query GetDepartments(\$pageableParam: PageableParamInput) {
    getDepartments(pageableParam: \$pageableParam) {
      data {
        uid
        name
        type
        agency {
          uid
          name
          code
          description
        }
      }
      elements
      pages
      size
      page
    }
  }
""";
// ============================================================================
// CHECK POINT QUERIES
// ============================================================================

const String saveTrafficCheckpointMutation = """
mutation SaveTrafficCheckpoint(\$trafficCheckPointDto: TrafficCheckPointDtoInput!) {
  saveTrafficCheckpoint(trafficCheckPointDto: \$trafficCheckPointDto) {
    status
    message
    data {
      uid
      name
      contactPhone
      coverageRadiusKm
      active
      location {
        latitude
        longitude
        address
      }
      parentStation {
        uid
        name
      }
      department {
        uid
        name
      }
      supervisingOfficer {
        uid
        badgeNumber
        code
        userAccount{
          phoneNumber
          name
        }
      }
    }
  }
}
""";

const String getTrafficCheckpointQuery = """
query GetTrafficCheckpoint(\$uid: String!) {
  getTrafficCheckpoint(uid: \$uid) {
    status
    message
    data {
      uid
      name
      contactPhone
      coverageRadiusKm
      active
      location {
        latitude
        longitude
        address
      }
      parentStation {
        uid
        name
      }
      department {
        uid
        name
      }
      supervisingOfficer {
        uid
        badgeNumber
        code
        userAccount{
          phoneNumber
          name
        }
      }
    }
  }
}
""";

const String deleteTrafficCheckpointMutation = """
mutation DeleteTrafficCheckpoint(\$uid: String!) {
  deleteTrafficCheckpoint(uid: \$uid) {
    status
    message
  }
}
""";

const String getTrafficCheckpointsQuery = """
query GetTrafficCheckpoints(\$pageableParam: PageableParamInput) {
  getTrafficCheckpoints(pageableParam: \$pageableParam) {
    data {
      uid
      name
      contactPhone
      coverageRadiusKm
      active
      location {
        latitude
        longitude
        address
      }
      parentStation {
        uid
        name
      }
      department {
        uid
        name
      }
      supervisingOfficer {
        uid
        badgeNumber
        code
        userAccount{
          phoneNumber
          name
        }
      }
    }
    elements
    pages
    size
    page
  }
}
""";

const String assignSupervisorMutation = """
mutation AssignSupervisor(\$checkpointUid: String!, \$officerUid: String!) {
  assignSupervisor(checkpointUid: \$checkpointUid, officerUid: \$officerUid) {
    status
    message
    data {
      uid
      name
      supervisingOfficer {
        uid
        badgeNumber
        code
        userAccount{
          phoneNumber
          name
        }
      }
    }
  }
}
""";

const String changeSupervisorMutation = """
mutation ChangeSupervisor(\$checkpointUid: String!, \$newOfficerUid: String!) {
  changeSupervisor(checkpointUid: \$checkpointUid, officerUid: \$newOfficerUid) {
    status
    message
    data {
      uid
      name
      supervisingOfficer {
        uid
        badgeNumber
        code
        userAccount{
          phoneNumber
          name
        }
      }
    }
  }
}
""";

// GraphQL Query - Get Traffic Checkpoints by Police Station

const String getTrafficCheckpointsByPoliceStationQuery = """
query GetTrafficCheckpointsByPoliceStation(\$pageableParam: PageableParamInput, \$stationUid: String!) {
  getTrafficCheckpointsByPoliceStation(pageableParam: \$pageableParam, stationUid: \$stationUid) {
    data {
      uid
      name
      contactPhone
      coverageRadiusKm
      active
      location {
        latitude
        longitude
        address
      }
      parentStation {
        uid
        name
      }
      department {
        uid
        name
      }
      supervisingOfficer {
        uid
        userAccount {
          name
          phoneNumber
        }
        badgeNumber
      }
    }
    elements
    pages
    size
    page
  }
}
""";