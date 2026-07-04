(function initRouting(root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.ZoomHubRouting = factory();
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function routingFactory() {
  function normalizeRoomName(value) {
    return String(value || '').trim().replace(/\s+/g, ' ').toLowerCase();
  }

  function zoomUserId(user) {
    const raw = user && (
      user.userId ??
      user.userID ??
      user.user_id ??
      user.id ??
      user.participantId ??
      user.participantID ??
      user.participant_id
    );
    if (raw === null || raw === undefined || raw === '') return null;
    const number = Number(raw);
    return Number.isFinite(number) ? number : raw;
  }

  function zoomCustomerKey(user) {
    return String(
      (user && (
        user.customerKey ??
        user.customer_key ??
        user.customUserId ??
        user.custom_user_id ??
        user.userGuid ??
        user.uid
      )) || '',
    ).trim();
  }

  function zoomDisplayName(user) {
    return String(
      (user && (
        user.userName ??
        user.user_name ??
        user.displayName ??
        user.display_name ??
        user.name
      )) || '',
    ).trim().replace(/\s+/g, ' ');
  }

  function roomId(room) {
    return String(
      (room && (
      room.boId ??
      room.boID ??
      room.boid ??
      room.bo_id ??
      room.roomId ??
      room.roomID ??
      room.room_id ??
      room.breakoutRoomId ??
      room.breakout_room_id ??
      room.id
      )) || '',
    ).trim();
  }

  function roomName(room) {
    return String((room && (
      room.name ??
      room.roomName ??
      room.room_name ??
      room.boName ??
      room.bo_name ??
      room.topic
    )) || '').trim();
  }

  function roomParticipants(room) {
    if (!room || typeof room !== 'object') return [];
    const candidates = [
      room.participants,
      room.attendees,
      room.users,
      room.userList,
      room.attendeeList,
      room.attendeesList,
      room.members,
      room.participantList,
      room.participantsList,
    ];
    for (const candidate of candidates) {
      if (Array.isArray(candidate)) return candidate;
    }
    return [];
  }

  function normalizeRooms(rawRooms) {
    if (!rawRooms) return [];
    if (Array.isArray(rawRooms)) return rawRooms;
    const candidates = [
      rawRooms.rooms,
      rawRooms.roomList,
      rawRooms.roomsList,
      rawRooms.boList,
      rawRooms.boRooms,
      rawRooms.boRoomList,
      rawRooms.breakoutRooms,
      rawRooms.breakoutRoomList,
      rawRooms.breakoutRoomsList,
      rawRooms.data,
      rawRooms.data && rawRooms.data.rooms,
      rawRooms.data && rawRooms.data.roomList,
      rawRooms.data && rawRooms.data.boList,
      rawRooms.data && rawRooms.data.breakoutRooms,
      rawRooms.data && rawRooms.data.breakoutRoomList,
      rawRooms.result,
      rawRooms.result && rawRooms.result.rooms,
      rawRooms.result && rawRooms.result.roomList,
      rawRooms.result && rawRooms.result.roomsList,
      rawRooms.result && rawRooms.result.boList,
      rawRooms.result && rawRooms.result.boRooms,
      rawRooms.result && rawRooms.result.boRoomList,
      rawRooms.result && rawRooms.result.breakoutRooms,
      rawRooms.result && rawRooms.result.breakoutRoomList,
      rawRooms.result && rawRooms.result.breakoutRoomsList,
      rawRooms.result && rawRooms.result.data,
      rawRooms.result && rawRooms.result.data && rawRooms.result.data.rooms,
      rawRooms.result && rawRooms.result.data && rawRooms.result.data.roomList,
      rawRooms.result && rawRooms.result.data && rawRooms.result.data.boList,
    ];
    for (const candidate of candidates) {
      if (Array.isArray(candidate)) return candidate;
    }
    return [];
  }

  function normalizeUnassigned(rawState) {
    if (!rawState) return [];
    const candidates = [
      rawState.unassigned,
      rawState.unassignedParticipants,
      rawState.unassignedUserList,
      rawState.mainSession,
      rawState.mainSessionUsers,
      rawState.attendees,
      rawState.attendeeList,
      rawState.attendeesList,
      rawState.participants,
      rawState.participantList,
      rawState.participantsList,
      rawState.userList,
      rawState.users,
      rawState.data,
      rawState.result,
      rawState.result && rawState.result.unassigned,
      rawState.result && rawState.result.unassignedParticipants,
      rawState.result && rawState.result.unassignedUserList,
      rawState.result && rawState.result.attendees,
      rawState.result && rawState.result.attendeeList,
      rawState.result && rawState.result.attendeesList,
      rawState.result && rawState.result.participants,
      rawState.result && rawState.result.participantList,
      rawState.result && rawState.result.participantsList,
      rawState.result && rawState.result.userList,
      rawState.result && rawState.result.users,
    ];
    for (const candidate of candidates) {
      if (Array.isArray(candidate)) return candidate;
    }
    return [];
  }

  function targetRoomsByShift(assignments) {
    const map = new Map();
    for (const room of assignments && Array.isArray(assignments.rooms) ? assignments.rooms : []) {
      const shiftId = String(room && (room.shiftId || room.shift_id) || '').trim();
      const name = String(room && room.name || '').trim();
      if (shiftId && name) map.set(shiftId, name);
    }
    return map;
  }

  function targetRoomByUid(assignments) {
    const shiftRooms = targetRoomsByShift(assignments);
    const map = new Map();
    for (const member of assignments && Array.isArray(assignments.members) ? assignments.members : []) {
      const uid = String(member && member.uid || '').trim();
      const shiftId = String(member && (member.shiftId || member.shift_id) || '').trim();
      const targetRoomName = shiftRooms.get(shiftId);
      if (uid && targetRoomName) map.set(uid, targetRoomName);
    }
    return map;
  }

  function targetRoomByDisplayName(assignments) {
    const shiftRooms = targetRoomsByShift(assignments);
    const candidates = new Map();
    for (const member of assignments && Array.isArray(assignments.members) ? assignments.members : []) {
      const shiftId = String(member && (member.shiftId || member.shift_id) || '').trim();
      const targetRoomName = shiftRooms.get(shiftId);
      const displayName = normalizeRoomName(member && (
        member.displayName ||
        member.display_name ||
        member.name
      ));
      if (!displayName || !targetRoomName) continue;
      if (!candidates.has(displayName)) candidates.set(displayName, new Set());
      candidates.get(displayName).add(targetRoomName);
    }
    const map = new Map();
    for (const [displayName, roomNames] of candidates.entries()) {
      if (roomNames.size === 1) map.set(displayName, Array.from(roomNames)[0]);
    }
    return map;
  }

  function whoNeedsToMoveWhere(assignments, zoomState) {
    const targetsByUid = targetRoomByUid(assignments);
    const targetsByDisplayName = targetRoomByDisplayName(assignments);
    if (targetsByUid.size === 0 && targetsByDisplayName.size === 0) return [];

    const rooms = normalizeRooms(zoomState && (zoomState.rooms || zoomState.breakoutRooms || zoomState));
    const roomsByName = new Map();
    const participants = [];

    for (const room of rooms) {
      const name = roomName(room);
      const normalized = normalizeRoomName(name);
      if (normalized) roomsByName.set(normalized, room);
      for (const participant of roomParticipants(room)) {
        participants.push({ participant, fromRoomName: name, inMainSession: false });
      }
    }

    for (const participant of normalizeUnassigned(zoomState)) {
      participants.push({ participant, fromRoomName: '', inMainSession: true });
    }

    const seen = new Set();
    const actions = [];
    for (const item of participants) {
      const user = item.participant;
      const uid = zoomCustomerKey(user);
      const userId = zoomUserId(user);
      if (userId === null) continue;
      const displayName = normalizeRoomName(zoomDisplayName(user));
      const participantKey = `${uid || displayName}:${String(userId)}`;
      if (seen.has(participantKey)) continue;
      seen.add(participantKey);

      const targetRoomName = targetsByUid.get(uid) || targetsByDisplayName.get(displayName);
      if (!targetRoomName) continue;

      const targetRoom = roomsByName.get(normalizeRoomName(targetRoomName));
      const targetRoomId = roomId(targetRoom);
      if (!targetRoom || !targetRoomId) continue;

      const fromRoomName = item.fromRoomName || '';
      if (!item.inMainSession && normalizeRoomName(fromRoomName) === normalizeRoomName(targetRoomName)) continue;

      actions.push({
        action: fromRoomName ? 'move' : 'assign',
        uid: uid || zoomDisplayName(user),
        userId,
        fromRoomName,
        targetRoomName,
        targetRoomId,
      });
    }

    return actions;
  }

  return {
    normalizeRoomName,
    normalizeRooms,
    normalizeUnassigned,
    roomId,
    roomName,
    roomParticipants,
    targetRoomByDisplayName,
    targetRoomByUid,
    whoNeedsToMoveWhere,
    zoomCustomerKey,
    zoomDisplayName,
    zoomUserId,
  };
});
