const admin = require('firebase-admin');

admin.firestore.FieldValue = {
  serverTimestamp: () => ({__type: 'serverTimestamp'}),
};

const {__test__} = require('../handlers/no_show');

describe('class reporting payload helpers', () => {
  test('no-show reports are enriched from teaching_shifts-shaped data', () => {
    const report = __test__.buildNoShowReportData(
      {
        shiftId: 'shift_123',
        roomName: 'room_123',
        reporterName: 'Teacher One',
        reporterRole: 'teacher',
        isTeacherNoShow: false,
        appSessionId: 'abc123',
        diagnostics: {
          canPlaybackAudio: false,
          remoteParticipantCount: 0,
        },
      },
      'uid_1',
      {
        collection: 'teaching_shifts',
        data: {
          shiftName: 'Quran Class',
          teacherId: 'teacher_1',
          teacherName: 'Teacher One',
          studentIds: ['student_1'],
          studentNames: ['Student One'],
        },
      }
    );

    expect(report.reportType).toBe('no_show');
    expect(report.shiftName).toBe('Quran Class');
    expect(report.reportedBy).toBe('uid_1');
    expect(report.shiftCollection).toBe('teaching_shifts');
    expect(report.teacherId).toBe('teacher_1');
    expect(report.studentIds).toEqual(['student_1']);
    expect(report.hasDiagnostics).toBe(true);
    expect(report.appSessionId).toBe('abc123');
  });

  test('audio issue reports keep LiveKit diagnostics and duplicate cleanly', () => {
    const report = __test__.buildClassTechnicalIssueReportData(
      {
        shiftId: 'shift_456',
        shiftName: 'Fallback Name',
        roomName: 'room_456',
        reportedBy: 'student_1',
        reporterName: 'Student One',
        reporterRole: 'student',
        issueType: 'cannot_hear_other',
        note: 'I can see the teacher but cannot hear them.',
        diagnostics: {
          appSessionId: 'session_1',
          canPlaybackAudio: false,
          audioPlaybackAllowedState: false,
          remoteParticipants: [
            {
              identity: 'teacher_1',
              audioPublications: [
                {
                  sid: 'track_1',
                  muted: false,
                  subscribed: true,
                  hasTrack: true,
                },
              ],
            },
          ],
        },
      },
      'student_1',
      {
        collection: 'teaching_shifts',
        data: {
          shift_name: 'Arabic Class',
          teacher_id: 'teacher_1',
          student_ids: ['student_1'],
        },
      }
    );

    expect(report.reportType).toBe('technical_issue');
    expect(report.issueCategory).toBe('audio');
    expect(report.shiftName).toBe('Fallback Name');
    expect(report.teacherId).toBe('teacher_1');
    expect(report.appSessionId).toBe('session_1');
    expect(report.diagnostics.remoteParticipants[0].audioPublications[0].sid)
      .toBe('track_1');
    expect(report.suspectedCauses).toContain('receiver_audio_playback_blocked');
    expect(report.diagnosticSeverity).toBe('high');
    expect(report.recommendedNextSteps.join(' '))
      .toContain('Enable audio');
  });

  test('audio issue reports flag mic enabled without published audio', () => {
    const summary = __test__.buildAudioDiagnosticSummary({
      canPlaybackAudio: true,
      audioPlaybackAllowedState: true,
      micEnabledInUi: true,
      localParticipant: {
        identity: 'student_1',
        connectionQuality: 'excellent',
        audioPublications: [],
      },
      remoteParticipants: [
        {
          identity: 'teacher_1',
          connectionQuality: 'good',
          audioPublications: [
            {
              sid: 'remote_audio',
              muted: false,
              subscribed: true,
              hasTrack: true,
              trackMuted: false,
            },
          ],
        },
      ],
    });

    expect(summary.suspectedCauses)
      .toContain('sender_mic_enabled_but_not_published');
    expect(summary.nextSteps.join(' '))
      .toContain('browser microphone permission');
    expect(summary.severity).toBe('high');
  });

  test('audio issue reports summarize WebRTC packet stats', () => {
    const summary = __test__.buildAudioDiagnosticSummary({
      canPlaybackAudio: true,
      audioPlaybackAllowedState: true,
      micEnabledInUi: true,
      localParticipant: {
        identity: 'student_1',
        connectionQuality: 'excellent',
        audioPublications: [
          {
            muted: false,
            subscribed: true,
            hasTrack: true,
            trackMuted: false,
            webRtcStats: {
              direction: 'outbound',
              bytesSent: 0,
              packetsSent: 0,
              audioSourceStats: {
                totalAudioEnergy: 0,
              },
            },
          },
        ],
      },
      remoteParticipants: [
        {
          identity: 'teacher_1',
          connectionQuality: 'good',
          audioPublications: [
            {
              sid: 'remote_audio',
              muted: false,
              subscribed: true,
              hasTrack: true,
              trackMuted: false,
              webRtcStats: {
                direction: 'inbound',
                bytesReceived: 0,
                packetsReceived: 0,
                packetsLost: 4,
                concealedSamples: 120,
              },
            },
          ],
        },
      ],
    });

    expect(summary.suspectedCauses)
      .toContain('sender_webrtc_not_sending_audio_packets');
    expect(summary.suspectedCauses)
      .toContain('sender_microphone_capturing_silence');
    expect(summary.suspectedCauses)
      .toContain('receiver_webrtc_not_receiving_audio_packets');
    expect(summary.suspectedCauses).toContain('receiver_audio_packet_loss');
    expect(summary.suspectedCauses).toContain('receiver_audio_concealment');
    expect(summary.severity).toBe('high');
  });

  test('technical issue reports categorize broad video class issues', () => {
    expect(__test__.getIssueCategory('camera_not_working')).toBe('video');
    expect(__test__.getIssueCategory('screen_share_not_working'))
      .toBe('screen_share');
    expect(__test__.getIssueCategory('whiteboard_not_syncing'))
      .toBe('whiteboard');
    expect(__test__.getIssueCategory('participant_missing')).toBe('room');
    expect(__test__.getIssueCategory('disconnected_or_reconnecting'))
      .toBe('connection');
    expect(__test__.getIssueCategory('recording_problem')).toBe('recording');

    const report = __test__.buildClassTechnicalIssueReportData(
      {
        shiftId: 'shift_789',
        roomName: 'room_789',
        reporterName: 'Teacher One',
        reporterRole: 'teacher',
        issueType: 'screen_share_not_working',
        issueTypes: [
          'screen_share_not_working',
          'cannot_hear_other',
          'whiteboard_not_syncing',
        ],
        diagnostics: {
          screenShareEnabledInUi: true,
          clientClassFindings: [
            'local_screen_share_enabled_but_no_active_track',
          ],
        },
      },
      'teacher_1',
      {
        collection: 'teaching_shifts',
        data: {
          shift_name: 'Screen Share Class',
          teacher_id: 'teacher_1',
        },
      }
    );

    expect(report.issueCategory).toBe('screen_share');
    expect(report.issueTypes).toEqual([
      'screen_share_not_working',
      'cannot_hear_other',
      'whiteboard_not_syncing',
    ]);
    expect(report.issueCategories).toEqual([
      'screen_share',
      'audio',
      'whiteboard',
    ]);
    expect(report.suspectedCauses)
      .toContain('local_screen_share_enabled_but_no_active_track');
    expect(report.diagnosticSeverity).toBe('high');
  });
});
